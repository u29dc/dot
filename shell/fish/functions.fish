# Fish function parity layer for the Zsh setup.

function starship_theme
    set -l style (defaults read -g AppleInterfaceStyle 2>/dev/null)
    if test "$style" = Dark
        set -gx STARSHIP_CONFIG "$HOME/.config/starship/starship-dark.toml"
    else
        set -gx STARSHIP_CONFIG "$HOME/.config/starship/starship-light.toml"
    end
end

function b --wraps bun
    command bun run $argv
end

function context --wraps bunx
    command bunx contextcalc@latest --bars --depth 3 --min-tokens 1000 --sort name --output tree $argv
end

function cls
    clear
    starship_theme
    exec fish
end

function cat --wraps bat
    command bat --paging=never $argv
end

function find --wraps fd
    command fd $argv
end

function eza --wraps eza
    set -l args $argv
    if contains -- --tree $args; or contains -- -T $args
        command eza --icons --git-ignore -I "$EZA_DEFAULT_IGNORE" $argv
    else
        command eza --icons $argv
    end
end

function ls --wraps eza
    eza --icons -I (printf 'Icon\r') $argv
end

function ll --wraps eza
    eza --icons -la $argv
end

function lt --wraps eza
    eza --icons --tree $argv
end

function tree --wraps eza
    eza --icons -T $argv
end

function treed --wraps eza
    eza --icons -T --only-dirs $argv
end

function htop --wraps btm
    command btm $argv
end

function top --wraps btm
    command btm $argv
end

function scc --wraps scc
    command scc --no-cocomo $argv
end

function python --wraps uv
    command uv run python $argv
end

function python3 --wraps uv
    command uv run python3 $argv
end

function virtualenv --wraps uv
    command uv venv $argv
end

function pip --wraps uv
    command uv pip $argv
end

function pip3 --wraps uv
    command uv pip $argv
end

function zed --wraps zed
    if test (count $argv) -eq 0
        command zed .
    else
        command zed $argv
    end
end

function _dot_cd_required
    set -l label $argv[1]
    set -l path $argv[2]

    if test -z "$path"
        echo "$label is not configured in setup.env" >&2
        return 1
    end

    cd "$path"
end

function gdrive
    _dot_cd_required DOT_GDRIVE_HOME "$DOT_GDRIVE_HOME"
end

function dropbox
    _dot_cd_required DOT_DROPBOX_HOME "$DOT_DROPBOX_HOME"
end

function dd
    dropbox $argv
end

function oo
    _dot_cd_required DOT_VAULT_HOME "$DOT_VAULT_HOME"
end

function vault
    oo $argv
end

function obsidian
    if test (count $argv) -gt 0
        command open -a Obsidian $argv
    else if test -n "$DOT_VAULT_HOME"
        command open -a Obsidian "$DOT_VAULT_HOME"
    else
        command open -a Obsidian
    end
end

function _local_biome_info
    set -l repo_root $argv[1]
    pushd "$repo_root" >/dev/null
    or return 1

    command bun --no-install --eval '
        import path from "node:path";
        import { createRequire } from "node:module";

        const require = createRequire(process.cwd() + "/noop.js");

        try {
            const pkgPath = require.resolve("@biomejs/biome/package.json");
            const pkg = require(pkgPath);
            const binRel = typeof pkg.bin === "string" ? pkg.bin : pkg.bin?.biome;

            if (!pkg.version || !binRel) {
                process.exit(1);
            }

            console.log(`${pkg.version}\t${path.resolve(path.dirname(pkgPath), binRel)}`);
        } catch {
            process.exit(1);
        }
    '
    set -l command_status $status
    popd >/dev/null
    return $command_status
end

function bup
    set -l repo_root ""
    set -l biome_info ""
    set -l biome_before ""
    set -l biome_after ""
    set -l biome_bin ""

    if command git rev-parse --is-inside-work-tree >/dev/null 2>&1
        set repo_root (command git rev-parse --show-toplevel 2>/dev/null)
    end

    if test -z "$repo_root"
        set repo_root "$PWD"
    end

    if test -f "$repo_root/biome.json"; or test -f "$repo_root/biome.jsonc"
        set biome_info (_local_biome_info "$repo_root" 2>/dev/null)
        if test -n "$biome_info"
            set -l biome_fields (string split \t -- "$biome_info")
            set biome_before "$biome_fields[1]"
            set biome_bin "$biome_fields[2]"
        end
    end

    command bun update --latest
    or return $status

    if test -n "$biome_before"
        set biome_info (_local_biome_info "$repo_root" 2>/dev/null)
        if test -n "$biome_info"
            set -l biome_fields (string split \t -- "$biome_info")
            set biome_after "$biome_fields[1]"
            set biome_bin "$biome_fields[2]"
        end
    end

    if test -n "$biome_before"; and test -n "$biome_after"; and test "$biome_before" != "$biome_after"; and test -x "$biome_bin"
        command "$biome_bin" migrate --write
    end
end
