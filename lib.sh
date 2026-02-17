#!/usr/bin/env bash
#
# Shared functions for export.sh and import.sh.
# Source this file inside main() so that $DRY_RUN and $AUTO_YES are visible.
#
# Usage:
#   source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
#   init_paths

# Detect the real home directory, handling Git Bash path mangling.
# Git Bash maps C:\Users\leole to /c/Users/leole but Claude encodes from
# the Windows path C:\Users\leole, so we need the native form.
detect_home() {
    case "$(uname -s)" in
        MINGW*|MSYS*|CYGWIN*)
            # Convert /c/Users/leole -> C:/Users/leole
            local drive="${HOME:1:1}"
            drive="$(echo "$drive" | tr '[:lower:]' '[:upper:]')"
            echo "${drive}:${HOME:2}"
            ;;
        *)
            echo "$HOME"
            ;;
    esac
}

# Encode a path the same way Claude does:
# Replace : / \ with -, then strip leading -
encode_path() {
    echo "$1" | sed 's/[:\\/]/-/g; s/^-//'
}

# Greedy filesystem-matching decoder.
# Takes an encoded project dir name like
#   C--Users-leole-Documents-code-disqt-discord-bot
# strips the encoded home prefix, then resolves hyphen-ambiguous segments
# by greedily matching the longest directory name on disk.
#
# Requires ENCODED_HOME and REAL_HOME to be set (via init_paths).
decode_project_dir() {
    local encoded="$1"

    # Strip encoded home prefix (+ trailing -)
    local remainder="${encoded#"${ENCODED_HOME}"}"
    remainder="${remainder#-}"

    if [[ -z "$remainder" ]]; then
        echo ""
        return
    fi

    # Split on -
    IFS='-' read -ra parts <<< "$remainder"
    local n=${#parts[@]}
    local resolved=""
    local base="$REAL_HOME"
    local i=0

    while (( i < n )); do
        local matched=false

        # Try longest possible match first (greedy)
        local j=$n
        while (( j > i )); do
            local candidate=""
            local k=$i
            while (( k < j )); do
                if [[ -z "$candidate" ]]; then
                    candidate="${parts[$k]}"
                else
                    candidate="${candidate}-${parts[$k]}"
                fi
                (( k++ ))
            done

            local test_path="$base/$candidate"
            if [[ -d "$test_path" || -f "$test_path" ]]; then
                if [[ -z "$resolved" ]]; then
                    resolved="$candidate"
                else
                    resolved="$resolved/$candidate"
                fi
                base="$test_path"
                i=$j
                matched=true
                break
            fi
            (( j-- ))
        done

        if ! $matched; then
            # No filesystem match; treat single segment as-is
            local seg="${parts[$i]}"
            if [[ -z "$resolved" ]]; then
                resolved="$seg"
            else
                resolved="$resolved/$seg"
            fi
            base="$base/$seg"
            (( i++ ))
        fi
    done

    echo "$resolved"
}

# Convert REAL_HOME (C:/Users/leole) back to unix path for filesystem ops
to_unix_path() {
    local p="$1"
    case "$(uname -s)" in
        MINGW*|MSYS*|CYGWIN*)
            local drive_letter="${p:0:1}"
            drive_letter="$(echo "$drive_letter" | tr '[:upper:]' '[:lower:]')"
            echo "/${drive_letter}${p:2}"
            ;;
        *)
            echo "$p"
            ;;
    esac
}

# Dry-run-aware copy (single file).
# References $DRY_RUN from the calling scope.
safe_cp() {
    local src="$1"
    local dst="$2"
    if $DRY_RUN; then
        echo "  [copy] $src -> $dst"
    else
        mkdir -p "$(dirname "$dst")"
        cp "$src" "$dst"
    fi
}

# Dry-run-aware recursive directory copy (contents of src_dir into dst_dir).
# In dry-run mode, walks recursively with find to show all files.
# References $DRY_RUN from the calling scope.
safe_cp_r() {
    local src_dir="$1"
    local dst_dir="$2"
    if $DRY_RUN; then
        # Walk recursively to show all files
        while IFS= read -r -d '' f; do
            local rel="${f#"$src_dir"/}"
            echo "  [copy] $f -> $dst_dir/$rel"
        done < <(find "$src_dir" -type f -print0)
    else
        mkdir -p "$dst_dir"
        cp -r "$src_dir"/. "$dst_dir/"
    fi
}

# Prompt for confirmation. Returns 0 if yes.
# If --yes flag is set (AUTO_YES=true), always returns 0.
# In dry-run mode, assumes yes for display purposes.
# References $AUTO_YES and $DRY_RUN from the calling scope.
confirm() {
    local msg="$1"
    if $AUTO_YES; then
        echo "  $msg [auto-yes]"
        return 0
    fi
    if $DRY_RUN; then
        # In dry-run mode, assume yes for display purposes
        return 0
    fi
    printf "  %s [y/N] " "$msg"
    local answer
    read -r answer
    case "$answer" in
        [yY]|[yY][eE][sS]) return 0 ;;
        *) return 1 ;;
    esac
}

# Initialize path globals: REAL_HOME, ENCODED_HOME, CLAUDE_DIR.
# Call this after sourcing lib.sh.
init_paths() {
    REAL_HOME="$(detect_home)"
    ENCODED_HOME="$(encode_path "$REAL_HOME")"
    CLAUDE_DIR="$HOME/.claude"
}
