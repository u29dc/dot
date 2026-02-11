#!/usr/bin/env bash
# Sandbox VM management via Tart

sandbox() {
    local RED='\x1b[31m'
    local BLUE='\x1b[34m'
    local YELLOW='\x1b[33m'
    local DIM='\x1b[2m'
    local RESET='\x1b[0m'

    local BASE_IMAGE="sandbox-dev"
    local SANDBOX_KEY="$HOME/Git/dot/vm/sandbox_key"
    local VM_NAME=""
    local TARGET_PATH=""
    local EXEC_CMD=""
    local READ_ONLY=false
    local READ_ONLY_WITH_GIT=false
    local ACTION="start"
    local DOCTOR_FAIL=0

    _doctor_check() {
        local name="$1"
        shift
        if "$@" >/dev/null 2>&1; then
            echo -e "${BLUE}[OK]${RESET} ${name}"
        else
            echo -e "${RED}[FAIL]${RESET} ${name}"
            DOCTOR_FAIL=1
        fi
    }

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -s)
                ACTION="stop"
                shift
                ;;
            -d)
                ACTION="delete"
                shift
                ;;
            -r)
                ACTION="reset"
                shift
                ;;
            -n)
                if [ -z "${2:-}" ]; then
                    echo -e "${RED}[ERROR] -n requires a name${RESET}"
                    return 1
                fi
                VM_NAME="$2"
                shift 2
                ;;
            -e)
                if [ -z "${2:-}" ]; then
                    echo -e "${RED}[ERROR] -e requires a command${RESET}"
                    return 1
                fi
                EXEC_CMD="$2"
                shift 2
                ;;
            --ro)
                READ_ONLY=true
                shift
                ;;
            --ro-git)
                READ_ONLY=true
                READ_ONLY_WITH_GIT=true
                shift
                ;;
            --doctor)
                ACTION="doctor"
                shift
                ;;
            -h | --help)
                echo "Usage: sandbox [path] [options]"
                echo ""
                echo "Options:"
                echo "  -s              Stop running sandbox VM"
                echo "  -d              Stop and delete ephemeral clone"
                echo "  -r              Reset (delete + fresh clone + start)"
                echo "  -n NAME         Use custom VM name (for concurrent runs)"
                echo "  -e CMD          Run command then auto-cleanup"
                echo "  --ro            Read-only mount (rsync to VM-local)"
                echo "  --ro-git        Read-only mount + include .git in VM-local rsync (slower)"
                echo "  --doctor        Run host + VM health checks"
                echo "  -h, --help      Show this help"
                return 0
                ;;
            *)
                if [ -z "$TARGET_PATH" ]; then
                    TARGET_PATH="$1"
                fi
                shift
                ;;
        esac
    done

    # Resolve target path (needed by all actions for VM_NAME derivation)
    if [ -z "$TARGET_PATH" ]; then
        TARGET_PATH="$(pwd)"
    elif [ "$TARGET_PATH" = "." ]; then
        TARGET_PATH="$(pwd)"
    else
        if ! TARGET_PATH="$(cd "$TARGET_PATH" 2>/dev/null && pwd)"; then
            echo -e "${RED}[ERROR] Path not found: $TARGET_PATH${RESET}"
            return 1
        fi
    fi

    # Auto-derive VM name from path hash if not specified
    if [ -z "$VM_NAME" ]; then
        local PATH_HASH
        PATH_HASH=$(echo -n "$TARGET_PATH" | shasum -a 256 | cut -c1-8)
        VM_NAME="sandbox-${PATH_HASH}"
    fi

    # Handle doctor action
    if [ "$ACTION" = "doctor" ]; then
        echo -e "${BLUE}Running sandbox doctor...${RESET}"
        _doctor_check "tart installed" command -v tart
        _doctor_check "ssh installed" command -v ssh
        _doctor_check "gh installed" command -v gh
        _doctor_check "base image exists (${BASE_IMAGE})" sh -c "tart list 2>/dev/null | grep -qw '${BASE_IMAGE}'"
        _doctor_check "sandbox key exists (${SANDBOX_KEY})" test -f "$SANDBOX_KEY"
        _doctor_check "sandbox key permissions are 600" sh -c "[ \"\$(stat -f '%Lp' '${SANDBOX_KEY}' 2>/dev/null)\" = '600' ]"

        if [ "$DOCTOR_FAIL" -ne 0 ]; then
            echo -e "${RED}Sandbox doctor failed on host checks.${RESET}"
            return 1
        fi

        echo -e "${BLUE}Running in-VM smoke test...${RESET}"
        local VM_CHECK_CMD
        # shellcheck disable=SC2016
        VM_CHECK_CMD='set -euo pipefail;
            export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH";
            gh auth status >/dev/null;
            [ "$(git config --global --get commit.gpgsign)" = "true" ];
            [ "$(git config --global --get gpg.format)" = "ssh" ];
            KEY="$(git config --global --get user.signingkey)";
            [ "$KEY" = "~/.ssh/id_ed25519_signing_agent.pub" ] || [ "$KEY" = "$HOME/.ssh/id_ed25519_signing_agent.pub" ];
            [ -f "$HOME/.ssh/id_ed25519_signing_agent.pub" ];
            SSH_OUT="$(ssh -T git@github.com 2>&1 || true)";
            echo "$SSH_OUT" | grep -qi "successfully authenticated"'

        if sandbox "$TARGET_PATH" -e "$VM_CHECK_CMD"; then
            echo -e "${BLUE}Sandbox doctor passed.${RESET}"
            return 0
        fi

        echo -e "${RED}Sandbox doctor failed in VM smoke test.${RESET}"
        return 1
    fi

    # Handle stop action
    if [ "$ACTION" = "stop" ]; then
        echo -e "${BLUE}Stopping ${VM_NAME}...${RESET}"
        tart stop "$VM_NAME" 2>/dev/null || true
        echo -e "${BLUE}Stopped.${RESET}"
        return 0
    fi

    # Handle delete action
    if [ "$ACTION" = "delete" ]; then
        echo -e "${BLUE}Stopping ${VM_NAME}...${RESET}"
        tart stop "$VM_NAME" 2>/dev/null || true
        echo -e "${BLUE}Deleting ${VM_NAME}...${RESET}"
        tart delete "$VM_NAME" 2>/dev/null || true
        echo -e "${BLUE}Deleted.${RESET}"
        return 0
    fi

    # Handle reset action
    if [ "$ACTION" = "reset" ]; then
        echo -e "${BLUE}Resetting ${VM_NAME}...${RESET}"
        tart stop "$VM_NAME" 2>/dev/null || true
        tart delete "$VM_NAME" 2>/dev/null || true
        ACTION="start"
    fi

    # SSH key and options
    local -a SSH_OPTS=(
        -o StrictHostKeyChecking=no
        -o UserKnownHostsFile=/dev/null
        -o LogLevel=ERROR
        -o ControlMaster=no
        -o ControlPath=none
        -o ControlPersist=no
        -o ServerAliveInterval=30
        -o ServerAliveCountMax=6
        -o TCPKeepAlive=yes
        -i "$SANDBOX_KEY"
    )

    # Verify sandbox SSH key exists
    if [ ! -f "$SANDBOX_KEY" ]; then
        echo -e "${RED}[ERROR] Sandbox SSH key not found at ${SANDBOX_KEY}${RESET}"
        echo -e "${DIM}Re-provision base image or run vm-setup.sh to generate it${RESET}"
        return 1
    fi

    # Verify base image exists
    if ! tart list 2>/dev/null | grep -qw "$BASE_IMAGE"; then
        echo -e "${RED}[ERROR] Base image '${BASE_IMAGE}' not found.${RESET}"
        echo -e "${DIM}Create it with: tart clone ghcr.io/cirruslabs/macos-tahoe-base:latest ${BASE_IMAGE}${RESET}"
        return 1
    fi

    # Clean up existing VM if present
    if tart list 2>/dev/null | grep -qw "$VM_NAME"; then
        echo -e "${YELLOW}Existing ${VM_NAME} found, cleaning up...${RESET}"
        tart stop "$VM_NAME" 2>/dev/null || true
        tart delete "$VM_NAME" 2>/dev/null || true
    fi

    # Clone base image (instant APFS clone)
    echo -e "${BLUE}Cloning ${BASE_IMAGE} -> ${VM_NAME}...${RESET}"
    tart clone "$BASE_IMAGE" "$VM_NAME"

    # Build mount argument
    local MOUNT_ARG="workspace:${TARGET_PATH}"
    if [ "$READ_ONLY" = true ]; then
        MOUNT_ARG="${MOUNT_ARG}:ro"
    fi

    # Start VM headless in background
    echo -e "${BLUE}Starting ${VM_NAME} (headless)...${RESET}"
    tart run "$VM_NAME" --no-graphics --dir="$MOUNT_ARG" &
    local VM_PID=$!

    # Cleanup function
    _sandbox_cleanup() {
        echo ""
        echo -e "${BLUE}Cleaning up ${VM_NAME}...${RESET}"
        # Remove artifact symlinks written to host via VirtioFS
        for dir in node_modules .next .svelte-kit .venv; do
            local p="$TARGET_PATH/$dir"
            if [ -L "$p" ] && [[ "$(readlink "$p")" == /Users/admin/local/* ]]; then
                rm "$p"
            fi
        done
        tart stop "$VM_NAME" 2>/dev/null || true
        tart delete "$VM_NAME" 2>/dev/null || true
        # Kill background tart process if still running
        kill "$VM_PID" 2>/dev/null || true
        wait "$VM_PID" 2>/dev/null || true
    }
    trap _sandbox_cleanup INT TERM HUP

    # Wait for VM to become reachable
    echo -e "${DIM}Waiting for VM to boot...${RESET}"
    local MAX_WAIT=120
    local ELAPSED=0
    local VM_IP=""
    while [ "$ELAPSED" -lt "$MAX_WAIT" ]; do
        # Early exit if tart process died
        if ! kill -0 "$VM_PID" 2>/dev/null; then
            echo -e "${RED}[ERROR] VM process exited unexpectedly${RESET}"
            break
        fi
        VM_IP=$(tart ip "$VM_NAME" 2>/dev/null || true)
        if [ -n "$VM_IP" ]; then
            # Test SSH connectivity
            if ssh "${SSH_OPTS[@]}" -o ConnectTimeout=2 -o BatchMode=yes "admin@${VM_IP}" "true" 2>/dev/null; then
                break
            fi
        fi
        sleep 2
        ELAPSED=$((ELAPSED + 2))
    done

    if [ -z "$VM_IP" ] || [ "$ELAPSED" -ge "$MAX_WAIT" ]; then
        echo -e "${RED}[ERROR] VM failed to become reachable within ${MAX_WAIT}s${RESET}"
        _sandbox_cleanup
        trap - INT TERM HUP
        unset -f _sandbox_cleanup
        return 1
    fi

    echo -e "${BLUE}VM ready at ${VM_IP}${RESET}"

    # Compute project hash for artifact directory namespacing
    local PROJECT_HASH
    PROJECT_HASH=$(echo -n "$TARGET_PATH" | shasum -a 256 | cut -c1-12)

    # Create artifact directory symlinks via SSH (skip in --ro mode)
    if [ "$READ_ONLY" = false ]; then
        ssh "${SSH_OPTS[@]}" "admin@${VM_IP}" bash -s -- "$PROJECT_HASH" <<'REMOTE_SETUP'
            PROJECT_HASH="$1"

            # Ensure workspace symlink exists
            if [ ! -e "$HOME/workspace" ]; then
                ln -s "/Volumes/My Shared Files/workspace" "$HOME/workspace"
            fi

            # Clean stale symlinks from previous crashes
            for dir in node_modules .next .svelte-kit .venv; do
                workspace_path="$HOME/workspace/${dir}"
                if [ -L "$workspace_path" ] && [ ! -e "$workspace_path" ]; then
                    rm "$workspace_path"
                fi
            done

            # Create local artifact directories
            LOCAL_DIR="$HOME/local/${PROJECT_HASH}"
            mkdir -p "$LOCAL_DIR"

            # Symlink heavy artifact dirs to VM-local disk (skip if real dir exists)
            for dir in node_modules .next .svelte-kit .venv; do
                local_target="${LOCAL_DIR}/${dir}"
                workspace_path="$HOME/workspace/${dir}"
                if [ ! -e "$workspace_path" ]; then
                    mkdir -p "$local_target"
                    ln -s "$local_target" "$workspace_path"
                fi
            done
REMOTE_SETUP
    fi

    # Read-only mode: rsync project to VM-local
    if [ "$READ_ONLY" = true ]; then
        echo -e "${BLUE}Syncing project to VM-local storage...${RESET}"
        if [ "$READ_ONLY_WITH_GIT" = true ]; then
            ssh "${SSH_OPTS[@]}" "admin@${VM_IP}" bash <<'REMOTE_RO_WITH_GIT'
                mkdir -p "$HOME/local/workspace"
                rsync -a --exclude='node_modules' --exclude='.next' --exclude='.svelte-kit' --exclude='.venv' --exclude='target' "$HOME/workspace/" "$HOME/local/workspace/"
REMOTE_RO_WITH_GIT
        else
            ssh "${SSH_OPTS[@]}" "admin@${VM_IP}" bash <<'REMOTE_RO'
                mkdir -p "$HOME/local/workspace"
                rsync -a --exclude='.git' --exclude='node_modules' --exclude='.next' --exclude='.svelte-kit' --exclude='.venv' --exclude='target' "$HOME/workspace/" "$HOME/local/workspace/"
REMOTE_RO
        fi
    fi

    # Determine working directory inside VM
    local WORK_DIR="\$HOME/workspace"
    if [ "$READ_ONLY" = true ]; then
        WORK_DIR="\$HOME/local/workspace"
    fi

    if [ -n "$EXEC_CMD" ]; then
        # Exec mode: run command, propagate exit code, auto-cleanup
        echo -e "${BLUE}Running: ${EXEC_CMD}${RESET}"
        local EXIT_CODE=0
        # WORK_DIR contains escaped $HOME, intentional client-side expansion
        # shellcheck disable=SC2029
        ssh "${SSH_OPTS[@]}" "admin@${VM_IP}" "cd ${WORK_DIR} && ${EXEC_CMD}" || EXIT_CODE=$?
        _sandbox_cleanup
        trap - INT TERM HUP
        unset -f _sandbox_cleanup
        return "$EXIT_CODE"
    else
        # Interactive mode: SSH into VM
        echo -e "${BLUE}Connecting to sandbox...${RESET}"
        echo -e "${DIM}Type 'exit' to disconnect. VM will be cleaned up automatically.${RESET}"
        echo ""
        local SSH_EXIT_CODE=0
        ssh "${SSH_OPTS[@]}" -t "admin@${VM_IP}" "cd ${WORK_DIR} && exec zsh -l" || SSH_EXIT_CODE=$?
        if [ "$SSH_EXIT_CODE" -ne 0 ]; then
            echo -e "${YELLOW}[WARN] SSH session ended unexpectedly (exit ${SSH_EXIT_CODE}).${RESET}"
        fi
        _sandbox_cleanup
        trap - INT TERM HUP
        unset -f _sandbox_cleanup
        return "$SSH_EXIT_CODE"
    fi
}
