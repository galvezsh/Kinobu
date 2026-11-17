# Managed by @APP_NAME@: changes inside this block are overwritten

# Environment
export JAVA_HOME=@JAVA_DIR@
for dir in "$HOME/.local/bin" "$JAVA_HOME/bin"; do
    case ":$PATH:" in *":$dir:"*) ;; *) [[ -d $dir ]] && PATH="$dir:$PATH" ;; esac
done
unset dir
export PATH

# Oh My Bash (interactive shells only)
export OSH="$HOME/.oh-my-bash"
OSH_THEME="@OMB_THEME@"
plugins=(@OMB_PLUGINS@)
completions=(@OMB_COMPLETIONS@)
aliases=(@OMB_ALIASES@)
if [[ $- == *i* && -f $OSH/oh-my-bash.sh ]]; then
    source "$OSH/oh-my-bash.sh"
fi

# Aliases
@ALIAS_LINES@
# ff: fastfetch in the desktop accent colour (follows Settings > Appearance): the centre of the
# rings, the name and the keys take it, and the rings carry a faint tint of it
ff() {
    local colour r g b
    case $(gsettings get org.gnome.desktop.interface accent-color 2>/dev/null) in
        *blue*)   colour='98;160;234' ;;  *teal*)   colour='51;199;222' ;;
        *green*)  colour='87;227;137' ;;  *orange*) colour='255;163;72' ;;
        *red*)    colour='246;97;81' ;;   *pink*)   colour='240;130;180' ;;
        *purple*) colour='192;97;203' ;;  *slate*)  colour='153;170;190' ;;
        *brown*)  colour='181;131;90' ;;  *)        colour='201;165;74' ;;
    esac
    IFS=';' read -r r g b <<<"$colour"
    KINOBU_ACCENT="38;2;$colour" command fastfetch \
        --logo-color-1 "38;2;$(((238 * 88 + r * 12) / 100));$(((238 * 88 + g * 12) / 100));$(((238 * 88 + b * 12) / 100))" \
        --logo-color-2 "38;2;$(((165 * 88 + r * 12) / 100));$(((165 * 88 + g * 12) / 100));$(((165 * 88 + b * 12) / 100))" \
        --logo-color-3 "38;2;$colour" --color-keys "38;2;$colour" "$@"
}

# System info once per Ptyxis window or tab (not in subshells or in IDE terminals started from it)
if [[ $- == *i* && -n ${PTYXIS_VERSION:-} && -z ${KINOBU_FETCHED:-} && ${TERM_PROGRAM:-} != vscode && ${TERMINAL_EMULATOR:-} != JetBrains-JediTerm ]]; then
    export KINOBU_FETCHED=1
    if command -v fastfetch &>/dev/null; then ff; fi
fi
