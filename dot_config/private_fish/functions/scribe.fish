function scribe --description 'Save and recall shell commands'
    set -l file "$XDG_DATA_HOME/scribe/commands"

    if not set -q XDG_DATA_HOME
        set file "$HOME/.local/share/scribe/commands.fish"
    end

    switch "$argv[1]"
        case '' search copy
            if not command -sq fzf
                echo "scribe: fzf is required" >&2
                return 1
            end

            if not test -f "$file"
                return 0
            end

            set -l query (commandline)

            set -l result (
                command fzf \
                    --height 30% \
                    --reverse \
                    --scheme history \
                    --no-multi \
                    --query "$query" \
                    < "$file"
            )

            if test $status -eq 0 -a -n "$result"
                if test "$argv[1]" = copy
                    echo -n (string collect -- $result) | wl-copy
                else
                    commandline --append -- (string collect -- $result)
                    commandline --cursor (string length (commandline))
                    commandline --function repaint
                end
            end

        case edit
            mkdir -p (path dirname "$file")
            touch "$file"

            $EDITOR "$file"

        case record
            if not command -sq fzf
                echo "scribe: fzf is required" >&2
                return 1
            end

            mkdir -p (path dirname "$file")
            touch "$file"

            set -l tmp (mktemp -t scribe.XXXXXX)
            or return 1

            # Use NUL-delimited history so multiline fish history entries
            # survive the trip through fzf.
            history -z --color always |
                command fzf \
                    --reverse \
                    --multi \
                    --ansi \
                    --scheme history \
                    --read0 \
                    --print0 |
                string split0 > "$tmp"

            if test $pipestatus[2] -ne 0
                rm -f "$tmp"
                return 0
            end

            $EDITOR "$tmp"

            # One command per line. Empty/whitespace-only lines are discarded.
            string match -rv '^[[:space:]]*$' < "$tmp" >> "$file"

            rm -f "$tmp"

        case prev
            # The command invoking `scribe prev` is not yet in fish history,
            # so the newest history entry is the previous command.
            set -l previous (history | head -n 1)

            if test -n "$previous"
                mkdir -p (path dirname "$file")
                printf '%s\n' "$previous" >> "$file"
            end

        case '' -h --help help
            echo 'usage: scribe <command>'
            echo
            echo 'commands:'
            echo '  search   search saved commands with fzf'
            echo '  edit     edit the saved command file'
            echo '  record   select commands from fish history and save them'
            echo '  prev     save the previous command'

        case '*'
            echo "scribe: unknown command '$argv[1]'" >&2
            echo "Try 'scribe --help'." >&2
            return 1
    end
end
