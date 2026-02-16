#!/usr/bin/env bash
set -euo pipefail

# Autonomous Agent Loop Harness
# Usage:
#   ./loop.sh [--agent claude|codex] [--max-iterations N] [--model MODEL] [--no-push] [--timeout MINUTES] [--heartbeat MINUTES]
#   LOOP_TIMEOUT_MINUTES=30 LOOP_HEARTBEAT_MINUTES=1 ./loop.sh
# Defaults:
#   --agent claude
#   --max-iterations 0 (unlimited)
#   DEFAULT_ITERATION_TIMEOUT_MINUTES=0 means unlimited (no timeout watchdog)
#   DEFAULT_HEARTBEAT_INTERVAL_MINUTES=1 controls progress heartbeat cadence

PROMPT_FILE="PROMPT.md"
LOG_DIR="agent_logs"

DEFAULT_ITERATION_TIMEOUT_MINUTES=0
DEFAULT_HEARTBEAT_INTERVAL_MINUTES=1

AGENT="claude"
MAX_ITERATIONS=0
MODEL=""
AUTO_PUSH=true
BACKOFF_BASE=5
BACKOFF_MAX=60
CONSECUTIVE_FAILURES=0
ITERATION_TIMEOUT_MINUTES="${LOOP_TIMEOUT_MINUTES:-$DEFAULT_ITERATION_TIMEOUT_MINUTES}"
HEARTBEAT_INTERVAL_MINUTES="${LOOP_HEARTBEAT_MINUTES:-$DEFAULT_HEARTBEAT_INTERVAL_MINUTES}"
ITERATION_TIMEOUT_SECONDS=0
HEARTBEAT_INTERVAL_SECONDS=0
CURRENT_AGENT_PID=""
HEARTBEAT_PID=""
TIMEOUT_GUARD_PID=""
CLAUDE_SUPPORTS_STREAM_JSON=false
CLAUDE_SUPPORTS_INCLUDE_PARTIAL_MESSAGES=false

print_usage() {
  cat <<'EOF'
Usage:
  ./loop.sh [options]

Options:
  --agent <claude|codex>   Agent CLI to run (default: claude)
  --max-iterations <N>     Number of iterations before exit (0 = unlimited)
  --model <MODEL>          Model passed through to the selected agent
  --no-push                Disable auto-push between successful iterations
  --timeout <MINUTES>      Per-iteration timeout (0 = unlimited)
  --heartbeat <MINUTES>    Heartbeat interval while agent is running (0 = disabled)
  -h, --help               Show this help text
EOF
}

is_uint() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

is_supported_agent() {
  case "$1" in
    claude|codex) return 0 ;;
    *) return 1 ;;
  esac
}

require_option_value() {
  local option="$1"
  local arg_count="$2"
  if [[ "$arg_count" -lt 2 ]]; then
    echo "Error: ${option} requires a value"
    exit 1
  fi
}

stop_pid() {
  local pid="${1:-}"
  if [[ -z "$pid" ]]; then
    return
  fi

  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
}

start_heartbeat() {
  local target_pid="$1"
  local iteration="$2"
  local iteration_started_at="$3"
  local log_file="$4"

  HEARTBEAT_PID=""
  if [[ "$HEARTBEAT_INTERVAL_SECONDS" -le 0 ]]; then
    return
  fi

  (
    while kill -0 "$target_pid" 2>/dev/null; do
      sleep "$HEARTBEAT_INTERVAL_SECONDS"
      if ! kill -0 "$target_pid" 2>/dev/null; then
        break
      fi

      local elapsed
      elapsed=$(( $(date +%s) - iteration_started_at ))
      local msg="Heartbeat: iteration ${iteration} still running (${elapsed}s elapsed)"
      echo "$msg" | tee -a "$log_file"
    done
  ) &
  HEARTBEAT_PID=$!
}

start_timeout_guard() {
  local target_pid="$1"
  local log_file="$2"
  local timeout_flag_file="$3"

  TIMEOUT_GUARD_PID=""
  if [[ "$ITERATION_TIMEOUT_SECONDS" -le 0 ]]; then
    return
  fi

  (
    sleep "$ITERATION_TIMEOUT_SECONDS"
    if ! kill -0 "$target_pid" 2>/dev/null; then
      exit 0
    fi

    local msg="Timeout: iteration exceeded ${ITERATION_TIMEOUT_MINUTES}m (${ITERATION_TIMEOUT_SECONDS}s); sending SIGTERM to ${AGENT} process ${target_pid}"
    echo "$msg" | tee -a "$log_file"
    echo "1" > "$timeout_flag_file"
    kill "$target_pid" 2>/dev/null || true

    sleep 5
    if kill -0 "$target_pid" 2>/dev/null; then
      local force_msg="Timeout: ${AGENT} process ${target_pid} still running; sending SIGKILL"
      echo "$force_msg" | tee -a "$log_file"
      kill -9 "$target_pid" 2>/dev/null || true
    fi
  ) &
  TIMEOUT_GUARD_PID=$!
}

detect_agent_capabilities() {
  if [[ "$AGENT" != "claude" ]]; then
    return
  fi

  local help_output
  help_output="$(claude --help 2>&1 || true)"

  if [[ "$help_output" == *"--output-format"* ]]; then
    CLAUDE_SUPPORTS_STREAM_JSON=true
  fi

  if [[ "$help_output" == *"--include-partial-messages"* ]]; then
    CLAUDE_SUPPORTS_INCLUDE_PARTIAL_MESSAGES=true
  fi
}

should_stop_for_completion() {
  local log_file="$1"
  grep -Eq '^[[:space:]]*<promise>COMPLETE</promise>[[:space:]]*$' "$log_file"
}

run_agent_iteration() {
  local log_file="$1"
  local timeout_flag_file="$2"
  local iteration="$3"
  local iteration_started_at="$4"
  local exit_code=0
  local codex_last_message_file=""

  exec 3> >(tee "$log_file")
  exec 4> >(tee -a "$log_file" >&2)

  case "$AGENT" in
    claude)
      local -a claude_args
      claude_args=(-p "$(cat "$PROMPT_FILE")" --dangerously-skip-permissions)

      if [[ -n "$MODEL" ]]; then
        claude_args+=(--model "$MODEL")
      fi

      if [[ "$CLAUDE_SUPPORTS_STREAM_JSON" == true ]]; then
        claude_args+=(--output-format stream-json --verbose)
        if [[ "$CLAUDE_SUPPORTS_INCLUDE_PARTIAL_MESSAGES" == true ]]; then
          claude_args+=(--include-partial-messages)
        fi
      else
        claude_args+=(--verbose)
      fi

      claude "${claude_args[@]}" 1>&3 2>&4 &
      ;;
    codex)
      codex_last_message_file="$LOG_DIR/.codex_last_message_iter${iteration}_$$.txt"
      rm -f "$codex_last_message_file"

      local -a codex_args
      codex_args=(exec --dangerously-bypass-approvals-and-sandbox -C "$PWD" --output-last-message "$codex_last_message_file")

      if [[ -n "$MODEL" ]]; then
        codex_args+=(--model "$MODEL")
      fi

      codex "${codex_args[@]}" - < "$PROMPT_FILE" 1>&3 2>&4 &
      ;;
    *)
      echo "Error: unsupported agent '$AGENT'" >&2
      exec 3>&-
      exec 4>&-
      return 1
      ;;
  esac

  CURRENT_AGENT_PID=$!

  start_heartbeat "$CURRENT_AGENT_PID" "$iteration" "$iteration_started_at" "$log_file"
  start_timeout_guard "$CURRENT_AGENT_PID" "$log_file" "$timeout_flag_file"

  wait "$CURRENT_AGENT_PID" || exit_code=$?

  stop_pid "$HEARTBEAT_PID"
  HEARTBEAT_PID=""
  stop_pid "$TIMEOUT_GUARD_PID"
  TIMEOUT_GUARD_PID=""
  CURRENT_AGENT_PID=""

  if [[ "$AGENT" == "codex" ]]; then
    if [[ -s "$codex_last_message_file" ]]; then
      printf '\n' 1>&3
      cat "$codex_last_message_file" 1>&3
      printf '\n' 1>&3
    fi
    rm -f "$codex_last_message_file"
  fi

  exec 3>&-
  exec 4>&-

  return "$exit_code"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent)
      require_option_value "--agent" "$#"
      AGENT="$2"
      shift 2
      ;;
    --max-iterations)
      require_option_value "--max-iterations" "$#"
      MAX_ITERATIONS="$2"
      shift 2
      ;;
    --model)
      require_option_value "--model" "$#"
      MODEL="$2"
      shift 2
      ;;
    --no-push) AUTO_PUSH=false; shift ;;
    --timeout)
      require_option_value "--timeout" "$#"
      ITERATION_TIMEOUT_MINUTES="$2"
      shift 2
      ;;
    --heartbeat)
      require_option_value "--heartbeat" "$#"
      HEARTBEAT_INTERVAL_MINUTES="$2"
      shift 2
      ;;
    -h|--help) print_usage; exit 0 ;;
    *) echo "Unknown argument: $1"; print_usage; exit 1 ;;
  esac
done

if ! is_supported_agent "$AGENT"; then
  echo "Error: --agent must be one of: claude, codex"; exit 1
fi
if ! is_uint "$MAX_ITERATIONS"; then
  echo "Error: --max-iterations must be a non-negative integer"; exit 1
fi
if ! is_uint "$ITERATION_TIMEOUT_MINUTES"; then
  echo "Error: --timeout must be a non-negative integer (minutes)"; exit 1
fi
if ! is_uint "$HEARTBEAT_INTERVAL_MINUTES"; then
  echo "Error: --heartbeat must be a non-negative integer (minutes)"; exit 1
fi

ITERATION_TIMEOUT_SECONDS=$(( ITERATION_TIMEOUT_MINUTES * 60 ))
HEARTBEAT_INTERVAL_SECONDS=$(( HEARTBEAT_INTERVAL_MINUTES * 60 ))

# --- Prereq checks ---
if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "Error: $PROMPT_FILE not found"; exit 1
fi
if [[ ! -s "$PROMPT_FILE" ]]; then
  echo "Error: $PROMPT_FILE is empty"; exit 1
fi
if ! command -v "$AGENT" &>/dev/null; then
  echo "Error: $AGENT not found in PATH"; exit 1
fi
detect_agent_capabilities
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  echo "Error: not inside a git repository"; exit 1
fi

mkdir -p "$LOG_DIR"
ITERATION=0
CURRENT_BRANCH=$(git branch --show-current)
if [[ -z "$CURRENT_BRANCH" ]]; then
  echo "Error: detached HEAD -- checkout a branch first"; exit 1
fi
START_TIME=$(date +%s)

# --- Signal handling ---
cleanup() {
  stop_pid "$TIMEOUT_GUARD_PID"
  TIMEOUT_GUARD_PID=""
  stop_pid "$HEARTBEAT_PID"
  HEARTBEAT_PID=""
  stop_pid "$CURRENT_AGENT_PID"
  CURRENT_AGENT_PID=""

  echo ""
  echo "Loop interrupted after $ITERATION iterations"
  echo "Duration: $(( $(date +%s) - START_TIME )) seconds"
  echo "Branch: $CURRENT_BRANCH"
  echo "Logs: $LOG_DIR/"
  exit 0
}
trap cleanup SIGINT SIGTERM SIGHUP

# --- Auto-push safety ---
try_push() {
  if [[ "$AUTO_PUSH" != true ]]; then return; fi
  if ! git remote get-url origin &>/dev/null; then return; fi
  local ahead
  ahead=$(git rev-list --count "origin/$CURRENT_BRANCH..$CURRENT_BRANCH" 2>/dev/null || echo "0")
  if [[ "$ahead" == "0" ]]; then return; fi
  git push origin "$CURRENT_BRANCH" 2>/dev/null || {
    echo "Push failed. Will retry next iteration."
  }
}

MAX_ITERATIONS_LABEL="$MAX_ITERATIONS"
if [[ "$MAX_ITERATIONS" -eq 0 ]]; then
  MAX_ITERATIONS_LABEL="unlimited"
fi

TIMEOUT_LABEL="${ITERATION_TIMEOUT_MINUTES}m"
if [[ "$ITERATION_TIMEOUT_MINUTES" -eq 0 ]]; then
  TIMEOUT_LABEL="unlimited"
fi

HEARTBEAT_LABEL="${HEARTBEAT_INTERVAL_MINUTES}m"
if [[ "$HEARTBEAT_INTERVAL_MINUTES" -eq 0 ]]; then
  HEARTBEAT_LABEL="disabled"
fi

echo "=========================================="
echo " Agent Loop Starting"
echo " Agent: $AGENT"
echo " Branch: $CURRENT_BRANCH"
echo " Model: ${MODEL:-default}"
echo " Max iterations: $MAX_ITERATIONS_LABEL"
echo " Auto-push: $AUTO_PUSH"
echo " Iteration timeout: $TIMEOUT_LABEL"
echo " Heartbeat interval: $HEARTBEAT_LABEL"
echo "=========================================="

# --- Main loop ---
while true; do
  if [[ $MAX_ITERATIONS -gt 0 ]] && [[ $ITERATION -ge $MAX_ITERATIONS ]]; then
    echo "Reached max iterations: $MAX_ITERATIONS"
    break
  fi

  ITERATION=$((ITERATION + 1))
  TIMESTAMP=$(date +%Y%m%d_%H%M%S)
  COMMIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "no-commit")
  LOG_FILE="$LOG_DIR/agent_${TIMESTAMP}_iter${ITERATION}_${COMMIT_HASH}.log"
  TIMEOUT_FLAG_FILE="$LOG_DIR/.timeout_${TIMESTAMP}_iter${ITERATION}.flag"
  rm -f "$TIMEOUT_FLAG_FILE"

  echo ""
  echo "================ ITERATION $ITERATION ================"
  echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "Log: $LOG_FILE"

  ITER_START=$(date +%s)
  set +e
  run_agent_iteration "$LOG_FILE" "$TIMEOUT_FLAG_FILE" "$ITERATION" "$ITER_START"
  EXIT_CODE=$?
  set -e

  TIMED_OUT=false
  if [[ -f "$TIMEOUT_FLAG_FILE" ]]; then
    TIMED_OUT=true
    rm -f "$TIMEOUT_FLAG_FILE"
  fi

  ITER_DURATION=$(( $(date +%s) - ITER_START ))
  echo "Duration: ${ITER_DURATION}s | Exit: $EXIT_CODE" >> "$LOG_FILE"
  if [[ "$TIMED_OUT" == true ]]; then
    echo "Timed out: true" >> "$LOG_FILE"
  fi

  # Check for completion.
  # Match only a standalone completion line so prompt text and quoted mentions
  # do not terminate the loop early.
  if should_stop_for_completion "$LOG_FILE"; then
    echo ""
    echo "=========================================="
    echo " ALL STORIES COMPLETE"
    echo " Iterations: $ITERATION"
    echo " Total duration: $(( $(date +%s) - START_TIME ))s"
    echo "=========================================="
    try_push
    break
  fi

  # Handle failures with backoff
  if [[ $EXIT_CODE -ne 0 ]]; then
    if [[ "$TIMED_OUT" == true ]]; then
      echo "Iteration timed out after ${ITERATION_TIMEOUT_MINUTES}m."
    fi
    CONSECUTIVE_FAILURES=$((CONSECUTIVE_FAILURES + 1))
    BACKOFF=$(( BACKOFF_BASE * (2 ** (CONSECUTIVE_FAILURES - 1)) ))
    if [[ $BACKOFF -gt $BACKOFF_MAX ]]; then
      BACKOFF=$BACKOFF_MAX
    fi
    echo "Iteration failed (exit $EXIT_CODE). Backoff: ${BACKOFF}s (failure #$CONSECUTIVE_FAILURES)"
    sleep "$BACKOFF"
  else
    CONSECUTIVE_FAILURES=0
    try_push
  fi
done
