# Bash completion for charizard
# Install: copy to /etc/bash_completion.d/charizard

_charizard_completions() {
    local cur prev words
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # Main commands
    local commands="apply update reload flush rollback show status watch version
        ban unban add allow deny hosts
        open close ports
        spamhaus f2b geo
        log top report doctor
        backup restore upgrade
        disk io timers
        telegram tg notify s3
        install dps dlogs dexec dstop dstart ddown drestart
        dns portainer"

    # Subcommands
    case "$prev" in
        charizard)
            COMPREPLY=($(compgen -W "$commands" -- "$cur"))
            return 0
            ;;
        spamhaus)
            COMPREPLY=($(compgen -W "update status" -- "$cur"))
            return 0
            ;;
        f2b)
            COMPREPLY=($(compgen -W "status ban unban" -- "$cur"))
            return 0
            ;;
        geo)
            COMPREPLY=($(compgen -W "lookup top stats" -- "$cur"))
            return 0
            ;;
        disk)
            COMPREPLY=($(compgen -W "find clean" -- "$cur"))
            return 0
            ;;
        io)
            COMPREPLY=($(compgen -W "top watch" -- "$cur"))
            return 0
            ;;
        timers)
            COMPREPLY=($(compgen -W "all next" -- "$cur"))
            return 0
            ;;
        telegram|tg)
            COMPREPLY=($(compgen -W "status test report enable disable" -- "$cur"))
            return 0
            ;;
        notify)
            COMPREPLY=($(compgen -W "status check enable disable reset" -- "$cur"))
            return 0
            ;;
        s3)
            COMPREPLY=($(compgen -W "status test backup list restore enable disable folders addf rmf" -- "$cur"))
            return 0
            ;;
        install)
            COMPREPLY=($(compgen -W "docker portainer dns" -- "$cur"))
            return 0
            ;;
        portainer)
            COMPREPLY=($(compgen -W "status start stop restart logs" -- "$cur"))
            return 0
            ;;
        dns)
            COMPREPLY=($(compgen -W "status start stop restart logs add remove hosts flush test" -- "$cur"))
            return 0
            ;;
        upgrade)
            COMPREPLY=($(compgen -W "force" -- "$cur"))
            return 0
            ;;
        dstop|dstart|drestart)
            # Complete with running container names + "all"
            if command -v docker &>/dev/null; then
                local containers=$(docker ps --format '{{.Names}}' 2>/dev/null)
                COMPREPLY=($(compgen -W "all $containers" -- "$cur"))
            else
                COMPREPLY=($(compgen -W "all" -- "$cur"))
            fi
            return 0
            ;;
        dlogs|dexec)
            # Complete with running container names
            if command -v docker &>/dev/null; then
                local containers=$(docker ps --format '{{.Names}}' 2>/dev/null)
                COMPREPLY=($(compgen -W "$containers" -- "$cur"))
            fi
            return 0
            ;;
    esac

    # Default: show main commands
    COMPREPLY=($(compgen -W "$commands" -- "$cur"))
}

complete -F _charizard_completions charizard
