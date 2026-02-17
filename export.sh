#!/usr/bin/env bash
set -euo pipefail

main() {
    local SCRIPT_DIR
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local DRY_RUN=false

    if [[ "${1:-}" == "--dry-run" ]]; then
        DRY_RUN=true
        echo "[dry-run] No files will be copied."
        echo
    fi

    # -------------------------------------------------------------------------
    # Helpers
    # -------------------------------------------------------------------------

    # Detect the real home directory, handling Git Bash path mangling.
    # Git Bash maps C:\Users\leole to /c/Users/leole but Claude encodes from
    # the Windows path C:\Users\leole, so we need the native form.
    detect_home() {
        case "$(uname -s)" in
            MINGW*|MSYS*|CYGWIN*)
                # Convert /c/Users/leole -> C:/Users/leole
                local drive="${HOME:1:1}"               # 'c'
                drive="$(echo "$drive" | tr '[:lower:]' '[:upper:]')" # 'C'
                echo "${drive}:${HOME:2}"               # C:/Users/leole
                ;;
            *)
                echo "$HOME"
                ;;
        esac
    }

    local REAL_HOME
    REAL_HOME="$(detect_home)"

    local CLAUDE_DIR="$HOME/.claude"

    # Encode a path the same way Claude does:
    # Replace : / \ with -, then strip leading -
    encode_path() {
        local p="$1"
        p="${p//://- }"  # dummy -- sed below does the real work
        echo "$1" | sed 's/[:\\/]/-/g; s/^-//'
    }

    local ENCODED_HOME
    ENCODED_HOME="$(encode_path "$REAL_HOME")"

    # Greedy filesystem-matching decoder.
    # Takes an encoded project dir name like
    #   C--Users-leole-Documents-code-disqt-discord-bot
    # strips the encoded home prefix, then resolves hyphen-ambiguous segments
    # by greedily matching the longest directory name on disk.
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

    # Dry-run-aware copy (single file)
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

    # Dry-run-aware recursive copy (directory contents via glob)
    safe_cp_r() {
        local src_dir="$1"
        local dst_dir="$2"
        local pattern="${3:-*}"

        if $DRY_RUN; then
            for f in "$src_dir"/$pattern; do
                [[ -e "$f" ]] || continue
                echo "  [copy] $f -> $dst_dir/$(basename "$f")"
            done
        else
            mkdir -p "$dst_dir"
            for f in "$src_dir"/$pattern; do
                [[ -e "$f" ]] || continue
                cp "$f" "$dst_dir/$(basename "$f")"
            done
        fi
    }

    # -------------------------------------------------------------------------
    # Clean previous export
    # -------------------------------------------------------------------------
    if ! $DRY_RUN; then
        rm -rf "$SCRIPT_DIR/global" "$SCRIPT_DIR/projects" "$SCRIPT_DIR/plugins.json"
    fi

    # -------------------------------------------------------------------------
    # Counters
    # -------------------------------------------------------------------------
    local global_count=0
    local plugin_count=0
    local project_count=0
    local file_count=0

    # -------------------------------------------------------------------------
    # Global config
    # -------------------------------------------------------------------------
    echo "=== Global config ==="

    local global_dst="$SCRIPT_DIR/global"

    # CLAUDE.md
    if [[ -f "$CLAUDE_DIR/CLAUDE.md" ]]; then
        safe_cp "$CLAUDE_DIR/CLAUDE.md" "$global_dst/CLAUDE.md"
        (( global_count++ )) || true
        (( file_count++ )) || true
    fi

    # settings.json
    if [[ -f "$CLAUDE_DIR/settings.json" ]]; then
        safe_cp "$CLAUDE_DIR/settings.json" "$global_dst/settings.json"
        (( global_count++ )) || true
        (( file_count++ )) || true
    fi

    # superpowers-bootstrap.sh
    if [[ -f "$CLAUDE_DIR/superpowers-bootstrap.sh" ]]; then
        safe_cp "$CLAUDE_DIR/superpowers-bootstrap.sh" "$global_dst/superpowers-bootstrap.sh"
        if ! $DRY_RUN; then
            chmod +x "$global_dst/superpowers-bootstrap.sh"
        fi
        (( global_count++ )) || true
        (( file_count++ )) || true
    fi

    # commands/*.md
    if [[ -d "$CLAUDE_DIR/commands" ]]; then
        local cmd_found=false
        for f in "$CLAUDE_DIR/commands"/*.md; do
            [[ -e "$f" ]] || continue
            cmd_found=true
            safe_cp "$f" "$global_dst/commands/$(basename "$f")"
            (( global_count++ )) || true
            (( file_count++ )) || true
        done
        if ! $cmd_found; then
            echo "  (no command files found)"
        fi
    fi

    echo "  $global_count global files"
    echo

    # -------------------------------------------------------------------------
    # Plugins
    # -------------------------------------------------------------------------
    echo "=== Plugins ==="

    local plugins_src="$CLAUDE_DIR/plugins/installed_plugins.json"
    if [[ -f "$plugins_src" ]]; then
        if command -v jq &>/dev/null; then
            if $DRY_RUN; then
                echo "  [extract] $plugins_src -> $SCRIPT_DIR/plugins.json (name, version, scope via jq)"
            else
                jq '
                    .plugins | to_entries | map({
                        name: .key,
                        entries: (.value | map({scope, version}))
                    })
                ' "$plugins_src" > "$SCRIPT_DIR/plugins.json"
            fi
        else
            if $DRY_RUN; then
                echo "  [copy] $plugins_src -> $SCRIPT_DIR/plugins.json (raw, jq not available)"
            else
                cp "$plugins_src" "$SCRIPT_DIR/plugins.json"
            fi
        fi
        plugin_count=1
        (( file_count++ )) || true
        echo "  plugins.json exported"
    else
        echo "  (no installed_plugins.json found)"
    fi
    echo

    # -------------------------------------------------------------------------
    # Per-project config
    # -------------------------------------------------------------------------
    echo "=== Projects ==="

    local projects_src="$CLAUDE_DIR/projects"
    if [[ ! -d "$projects_src" ]]; then
        echo "  (no projects directory)"
    else
        for proj_dir in "$projects_src"/*/; do
            [[ -d "$proj_dir" ]] || continue
            local encoded_name
            encoded_name="$(basename "$proj_dir")"

            # Only process if it has CLAUDE.md or a non-empty memory/
            local has_global_claude=false
            local has_memory=false
            [[ -f "$proj_dir/CLAUDE.md" ]] && has_global_claude=true
            [[ -f "$proj_dir/memory/MEMORY.md" ]] && has_memory=true

            if ! $has_global_claude && ! $has_memory; then
                continue
            fi

            # Decode to relative-from-home path
            local rel_path
            rel_path="$(decode_project_dir "$encoded_name")"

            if [[ -z "$rel_path" ]]; then
                # This is the home directory itself -- use "_home" as key
                rel_path="_home"
            fi

            echo "  --- $rel_path (from $encoded_name)"

            local proj_dst="$SCRIPT_DIR/projects/$rel_path"

            # _global/ files (from ~/.claude/projects/<encoded>/)
            if $has_global_claude; then
                safe_cp "$proj_dir/CLAUDE.md" "$proj_dst/_global/CLAUDE.md"
                (( file_count++ )) || true
            fi
            if $has_memory; then
                safe_cp "$proj_dir/memory/MEMORY.md" "$proj_dst/_global/memory/MEMORY.md"
                (( file_count++ )) || true
            fi

            # Check if the actual project directory exists on the filesystem
            local actual_dir
            if [[ "$rel_path" == "_home" ]]; then
                actual_dir="$REAL_HOME"
            else
                actual_dir="$REAL_HOME/$rel_path"
            fi
            # On Git Bash, convert REAL_HOME (C:/Users/...) back to unix path
            case "$(uname -s)" in
                MINGW*|MSYS*|CYGWIN*)
                    local drive_letter="${actual_dir:0:1}"
                    drive_letter="$(echo "$drive_letter" | tr '[:upper:]' '[:lower:]')"
                    actual_dir="/${drive_letter}${actual_dir:2}"
                    ;;
            esac

            if [[ -d "$actual_dir" ]]; then
                # Root CLAUDE.md
                if [[ -f "$actual_dir/CLAUDE.md" ]]; then
                    safe_cp "$actual_dir/CLAUDE.md" "$proj_dst/CLAUDE.md"
                    (( file_count++ )) || true
                fi

                # _local/ from <project>/.claude/
                local local_claude_dir="$actual_dir/.claude"
                if [[ -d "$local_claude_dir" ]]; then
                    # settings.json
                    if [[ -f "$local_claude_dir/settings.json" ]]; then
                        safe_cp "$local_claude_dir/settings.json" "$proj_dst/_local/settings.json"
                        (( file_count++ )) || true
                    fi
                    # settings.local.json
                    if [[ -f "$local_claude_dir/settings.local.json" ]]; then
                        safe_cp "$local_claude_dir/settings.local.json" "$proj_dst/_local/settings.local.json"
                        (( file_count++ )) || true
                    fi
                    # CLAUDE.md (in .claude/)
                    if [[ -f "$local_claude_dir/CLAUDE.md" ]]; then
                        safe_cp "$local_claude_dir/CLAUDE.md" "$proj_dst/_local/CLAUDE.md"
                        (( file_count++ )) || true
                    fi
                    # commands/*.md
                    if [[ -d "$local_claude_dir/commands" ]]; then
                        for f in "$local_claude_dir/commands"/*.md; do
                            [[ -e "$f" ]] || continue
                            safe_cp "$f" "$proj_dst/_local/commands/$(basename "$f")"
                            (( file_count++ )) || true
                        done
                    fi
                fi
            else
                echo "    (project dir not found on filesystem: $actual_dir)"
            fi

            (( project_count++ )) || true
        done
    fi

    echo
    echo "=== Summary ==="
    echo "  Global files: $global_count"
    echo "  Plugins:      $plugin_count"
    echo "  Projects:     $project_count"
    echo "  Total files:  $file_count"
    if $DRY_RUN; then
        echo
        echo "  (dry run -- nothing was written)"
    else
        echo
        echo "  Exported to: $SCRIPT_DIR"
    fi
}

main "$@"
