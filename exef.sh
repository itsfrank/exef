# search for exe name recursively, if one founf exec, if many fzf then exec
# usage: exef [--load] [--save] <name> <path>
exef() {
    local positional_args=()
    local forward_args=()
    local arg_load=false
    local arg_save=false
    local arg_dryrun=false

    # arg parse
    local forwarding=false
    while (( $# > 0 )); do
        if [[  "$1" == "--"  ]]; then
            forwarding=true # Enable forwarding
            shift # Skip the '--' itself
            continue
        fi

        if [ "$forwarding" = true ]; then
            # Append to forward_args if forwarding is enabled
            forward_args+=("$1")
        else
            # Process script arguments
            case $1 in
                --help)
                    echo "Usage: exef [--load] [--save] [--dryrun] <pattern> [<path>] [--] <forward args ...>"
                    return 0
                    ;;
                --load)
                    arg_load=true
                    ;;
                --save)
                    arg_save=true
                    ;;
                --dryrun)
                    arg_dryrun=true
                    ;;
                *)
                    # append positional args
                    positional_args+=("$1")
                    ;;
            esac
        fi
        shift # Move to the next argument
    done

    if [[ ${#positional_args[@]} -eq 0 ]]; then
        echo "Error: No pattern provided."
        echo "Usage: $0 [--load] [--save] <pattern> [<path>]"
        return 1
    fi

    local cache_file="$HOME/.config/exef/cache.json"

    # If cache_file doesn't exist or is not valid JSON, create it with an empty JSON object
    if [[ $arg_load == true || $arg_save == true ]]; then
        if [[ ! -f "$cache_file" ]] || ! jq empty "$cache_file" 2>/dev/null; then
            echo "exef cache file missing, initializing empty cache at: $cache_file"
            # Ensure the directory exists
            mkdir -p "$(dirname "$cache_file")"
            echo "{}" > "$cache_file"
        fi
    fi

    local exe_name="${positional_args[1]}"
    local target_path="${positional_args[2]:-$(pwd)}"
    local execution_dir="$PWD"

    # Check if the provided path is a directory
    if [[ ! -d "$target_path" ]]; then
        echo "Error: $target_path is not a directory"
        return 1
    fi

    local selected_exe=0
    # TODO: handle case where the target path is an absolute directory
    local cache_key="$execution_dir :: $target_path :: $exe_name"
    local cache_hit=false

    # if load, check cache for exe
    if [[ $arg_load == true ]]; then

        # look for key in cache
        value=$(jq --exit-status --raw-output --arg key "$cache_key" '
            if has($key) then .[$key] else empty end
        ' "$cache_file")

        if [[ -n "$value" ]]; then
            selected_exe=$value
            cache_hit=true
        fi
    fi

    # no load, or no cache hit
    if [[ $selected_exe == 0 ]]; then
        exe_list="$(fd -t x "$exe_name" "$target_path")"
        exe_count=$(echo "$exe_list" | wc -l)

        selected_exe="$exe_list"

        if [ "$exe_count" -lt "1" ]; then
            echo "no executables matching name '$exe_name' found"
            return 1
        fi

        if [ "$exe_count" -gt "1" ]; then
            selected_exe=$(echo "$exe_list" | fzf)
        fi
    fi


    if [[ ! -x "$selected_exe" ]]; then
        echo "File is not executable: '$selected_exe'"
        return 1
    fi

    if [[ $arg_save == true && $cache_hit == false ]]; then
        # Add the key-value pair to the JSON file
        jq --arg key "$cache_key" --arg value "$selected_exe" \
            '.[$key] = $value' "$cache_file" > "$cache_file.tmp"
        mv -f "$cache_file.tmp" "$cache_file"
    fi


    if [[ $arg_dryrun == true ]]; then
        local exe_command="$selected_exe ${forward_args[@]}"
        echo "$exe_command"
        return 0
    else
        $selected_exe ${forward_args[@]}
    fi
}
