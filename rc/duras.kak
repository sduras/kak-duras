# rc/duras.kak — Kakoune integration for duras
# Maintainer: Sergiy Duras
# SPDX-License-Identifier: ISC
# Repository: https://codeberg.org/duras/kak-duras

# ─── open ─────────────────────────────────────────────────────────────────────

define-command duras-open -params ..1 \
    -docstring 'duras-open [date]: open note in current session
date: YYYY-MM-DD or integer offset (0 = today, -1 = yesterday)
Omit to open today. New notes are initialised by duras before opening.' %{
    evaluate-commands %sh{
        if [ -n "$1" ]; then
            path=$(duras path "$1" 2>&1)
        else
            path=$(duras path 2>&1)
        fi
        if [ $? -ne 0 ] || [ -z "$path" ]; then
            printf "fail 'duras: path failed'\n"
            exit 1
        fi
        if [ ! -f "$path" ]; then
            if [ -n "$1" ]; then
                EDITOR=echo duras open "$1" >/dev/null 2>&1
            else
                EDITOR=echo duras open >/dev/null 2>&1
            fi
            if [ $? -ne 0 ]; then
                printf "fail 'duras: failed to initialise note'\n"
                exit 1
            fi
        fi
        # %{} is safe for any duras path: Unix filenames cannot contain { or }
        printf 'edit %%{%s}\n' "$path"
    }
}


# ─── append ───────────────────────────────────────────────────────────────────

define-command duras-append \
    -docstring 'duras-append: append current selection to today''s note' %{
    evaluate-commands %sh{
        printf '%s' "$kak_selection" | duras append -
        [ $? -ne 0 ] && printf "fail 'duras: append failed'\n"
    }
}

define-command duras-append-buffer \
    -docstring 'duras-append-buffer: append entire buffer to today''s note' %{
    evaluate-commands -draft %{
        execute-keys '%'
        evaluate-commands %sh{
            printf '%s' "$kak_selection" | duras append -
            [ $? -ne 0 ] && printf "fail 'duras: append failed'\n"
        }
    }
}

define-command duras-append-text -params 1.. \
    -docstring 'duras-append-text <text>: append literal text to today''s note
Multiple words are joined. No quoting needed.' %{
    evaluate-commands %sh{
        printf '%s' "$*" | duras append -
        [ $? -ne 0 ] && printf "fail 'duras: append failed'\n"
    }
}

define-command duras-append-clipboard \
    -docstring 'duras-append-clipboard: append system clipboard to today''s note' %{
    evaluate-commands %sh{
        if command -v pbpaste >/dev/null 2>&1; then
            text=$(pbpaste 2>/dev/null)
            [ $? -eq 0 ] && { printf '%s' "$text" | duras append - && exit 0; }
        fi
        if command -v xclip >/dev/null 2>&1; then
            text=$(xclip -selection clipboard -o 2>/dev/null)
            [ $? -eq 0 ] && { printf '%s' "$text" | duras append - && exit 0; }
        fi
        if command -v xsel >/dev/null 2>&1; then
            text=$(xsel --clipboard --output 2>/dev/null)
            [ $? -eq 0 ] && { printf '%s' "$text" | duras append - && exit 0; }
        fi
        printf "fail 'duras: clipboard empty or no clipboard tool found'\n"
    }
}


# ─── search ───────────────────────────────────────────────────────────────────

define-command -hidden duras-search-open %{
    evaluate-commands %sh{
        date=$(printf '%s' "$kak_selection" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)
        if [ -n "$date" ]; then
            printf 'delete-buffer *duras-search*\n'
            printf 'duras-open %s\n' "$date"
        fi
    }
}

define-command duras-search -params 1.. \
    -docstring 'duras-search <keyword>: search notes; press <ret> on a result to open it
Search is literal and case-sensitive. For -i, use duras search -i from shell.' %{
    evaluate-commands %sh{
        out=$(duras search "$*" 2>/dev/null)
        if [ -z "$out" ]; then
            printf "echo -markup '{Information}No results'\n"
            exit 0
        fi
        tmp=$(mktemp)
        printf '%s\n' "$out" > "$tmp"
        # try: suppress error if *duras-search* buffer does not exist
        printf 'try %%{ delete-buffer *duras-search* }\n'
        printf 'edit -scratch *duras-search*\n'
        # %% → % in printf output; kak sees: execute-keys "%|cat /tmp/...<ret>gg"
        # % selects all; |cmd pipes selection through cmd replacing with output; gg to top
        printf 'execute-keys "%%%%|cat %s<ret>gg"\n' "$tmp"
        # <a-x> extends to full line so kak_selection holds the whole result line
        printf 'map buffer normal <ret> "<a-x>: duras-search-open<ret>"\n'
        printf 'evaluate-commands %%%%sh{ rm -f %s }\n' "$tmp"
    }
}


# ─── clipboard ────────────────────────────────────────────────────────────────

define-command duras-clip-yank \
    -docstring 'duras-clip-yank: copy buffer to system clipboard' %{
    evaluate-commands -draft %{
        execute-keys '%'
        evaluate-commands %sh{
            text="$kak_selection"
            if command -v pbcopy >/dev/null 2>&1; then
                printf '%s' "$text" | pbcopy && exit 0
            fi
            if command -v xclip >/dev/null 2>&1; then
                printf '%s' "$text" | xclip -selection clipboard && exit 0
            fi
            if command -v xsel >/dev/null 2>&1; then
                printf '%s' "$text" | xsel --clipboard --input && exit 0
            fi
            printf "fail 'duras: no clipboard tool found'\n"
        }
    }
}

define-command duras-clip-paste \
    -docstring 'duras-clip-paste: paste system clipboard below cursor' %{
    evaluate-commands %sh{
        if command -v pbpaste >/dev/null 2>&1; then
            text=$(pbpaste 2>/dev/null); [ $? -eq 0 ] || text=''
        elif command -v xclip >/dev/null 2>&1; then
            text=$(xclip -selection clipboard -o 2>/dev/null); [ $? -eq 0 ] || text=''
        elif command -v xsel >/dev/null 2>&1; then
            text=$(xsel --clipboard --output 2>/dev/null); [ $? -eq 0 ] || text=''
        else
            printf "fail 'duras: no clipboard tool found'\n"
            exit 1
        fi
        if [ -z "$text" ]; then
            printf "fail 'duras: clipboard is empty'\n"
            exit 1
        fi
        # Load into kak default register; open line below; insert from register
        escaped=$(printf '%s' "$text" | sed "s/'/''/g")
        printf "set-register '\"' '%s'\n" "$escaped"
        printf "execute-keys 'o<c-r>\"<esc>'\n"
    }
}

define-command duras-copy-path \
    -docstring 'duras-copy-path: copy today''s note path to system clipboard' %{
    evaluate-commands %sh{
        path=$(duras path 2>/dev/null)
        if [ $? -ne 0 ] || [ -z "$path" ]; then
            printf "fail 'duras: path failed'\n"
            exit 1
        fi
        if command -v pbcopy >/dev/null 2>&1; then
            printf '%s' "$path" | pbcopy && printf "echo -markup '{Information}path copied'\n" && exit 0
        fi
        if command -v xclip >/dev/null 2>&1; then
            printf '%s' "$path" | xclip -selection clipboard && printf "echo -markup '{Information}path copied'\n" && exit 0
        fi
        if command -v xsel >/dev/null 2>&1; then
            printf '%s' "$path" | xsel --clipboard --input && printf "echo -markup '{Information}path copied'\n" && exit 0
        fi
        printf "fail 'duras: no clipboard tool found'\n"
    }
}


# ─── utilities ────────────────────────────────────────────────────────────────

define-command duras-stats \
    -docstring 'duras-stats: show note counts, size, date range, and streak' %{
    evaluate-commands %sh{
        out=$(duras stats 2>&1)
        if [ $? -ne 0 ]; then
            printf "fail 'duras: stats failed'\n"
            exit 1
        fi
        escaped=$(printf '%s' "$out" | sed "s/'/''/g")
        printf "info '%s'\n" "$escaped"
    }
}

define-command duras-path \
    -docstring 'duras-path: print today''s note path to status bar' %{
    evaluate-commands %sh{
        path=$(duras path 2>/dev/null)
        if [ $? -ne 0 ] || [ -z "$path" ]; then
            printf "fail 'duras: path failed'\n"
        else
            printf 'echo %%{%s}\n' "$path"
        fi
    }
}

define-command duras-tags -params ..1 \
    -docstring 'duras-tags [tag]: list all tags, or notes containing tag
Pass bare tag name without #.' %{
    evaluate-commands %sh{
        if [ -n "$1" ]; then
            out=$(duras tags "$1" 2>&1)
        else
            out=$(duras tags 2>&1)
        fi
        if [ $? -ne 0 ] || [ -z "$out" ]; then
            printf "echo -markup '{Information}No tags'\n"
            exit 0
        fi
        tmp=$(mktemp)
        printf '%s\n' "$out" > "$tmp"
        printf 'try %%{ delete-buffer *duras-tags* }\n'
        printf 'edit -scratch *duras-tags*\n'
        printf 'execute-keys "%%%%|cat %s<ret>gg"\n' "$tmp"
        printf 'evaluate-commands %%%%sh{ rm -f %s }\n' "$tmp"
    }
}


# ─── mappings (optional) ──────────────────────────────────────────────────────

map global normal <leader>do ': duras-open<ret>'          -docstring 'duras: open today'
map global normal <leader>da ': duras-append-buffer<ret>' -docstring 'duras: append buffer'
map global normal <leader>dA ': duras-append<ret>'        -docstring 'duras: append selection'
map global normal <leader>dc ': duras-append-clipboard<ret>' -docstring 'duras: append clipboard'
map global normal <leader>ds ': duras-search '            -docstring 'duras: search'
map global normal <leader>dp ': duras-path<ret>'          -docstring 'duras: show path'
