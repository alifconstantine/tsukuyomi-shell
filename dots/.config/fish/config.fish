# Commands to run in interactive sessions can go here
if status is-interactive
    # No greeting
    set fish_greeting

    # Use starship
    function starship_transient_prompt_func
        starship module character
    end
    if test "$TERM" != "linux"
        starship init fish | source
        enable_transience
    end
    
    # Colors
    if test -f ~/.local/state/quickshell/user/generated/terminal/sequences.txt
        cat ~/.local/state/quickshell/user/generated/terminal/sequences.txt
    end

    # Fish 4.x global syntax colors (avoids legacy universal-var upgrade warnings)
    set -g fish_color_normal normal
    set -g fish_color_command blue
    set -g fish_color_param cyan
    set -g fish_color_quote yellow
    set -g fish_color_redirection cyan --bold
    set -g fish_color_end green
    set -g fish_color_error brred
    set -g fish_color_comment red
    set -g fish_color_operator brcyan
    set -g fish_color_escape brcyan
    set -g fish_color_autosuggestion 555 brblack

    # Run Tsukuyomi fastfetch on interactive terminal open
    if test -t 1; and test "$TERM" != "linux"; and not set -q NVIM
        if type -q tsukuyomi-fetch
            tsukuyomi-fetch
        else if type -q fastfetch
            fastfetch
        end
    end

    if type -q tsukuyomi-fetch
        function fastfetch --wraps fastfetch --description 'Run Tsukuyomi fastfetch'
            if test (count $argv) -eq 0
                tsukuyomi-fetch
            else
                command fastfetch $argv
            end
        end
    end

    # Aliases
    # kitty doesn't clear properly so we need to do this weird printing
    alias clear "printf '\033[2J\033[3J\033[1;1H'"
    alias celar "printf '\033[2J\033[3J\033[1;1H'"
    alias claer "printf '\033[2J\033[3J\033[1;1H'"
    alias pamcan pacman
    alias q 'qs -c ii'
    if test "$TERM" != "linux"
        alias ls 'eza --icons=auto'
    end
    if test "$TERM" = "xterm-kitty"
        alias ssh 'kitten ssh'
    end
end
