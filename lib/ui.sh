# shellcheck shell=bash
# Terminal output: colours, the Kinobu banner, status lines and the checklist.

# Sets the colours: the theme's accent for the terminal's mode when the theme engine wrote it
# (as fastfetch does), else GNOME's; the rings carry a faint tint of it.
ui_init() {
    C_ACCENT="" C_RING1="" C_RING2="" C_OK="" C_WARN="" C_ERR="" C_DIM="" C_BOLD="" C_RESET=""
    if [[ ! -t 1 || -n ${NO_COLOR:-} ]]; then return 0; fi
    local accent="" ring1="" ring2="" mode=light r g b
    if [[ $(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null || true) == *dark* ]]; then mode=dark; fi
    read -r accent ring1 ring2 2>/dev/null <"$HOME/.local/state/kinobu/terminal-$mode" || true
    if [[ -z $ring2 ]]; then
        accent=$(ui_accent)
        IFS=';' read -r r g b <<<"$accent"
        ring1="$(( (238 * 88 + r * 12) / 100 ));$(( (238 * 88 + g * 12) / 100 ));$(( (238 * 88 + b * 12) / 100 ))"
        ring2="$(( (165 * 88 + r * 12) / 100 ));$(( (165 * 88 + g * 12) / 100 ));$(( (165 * 88 + b * 12) / 100 ))"
    fi
    C_ACCENT=$'\e[38;2;'"$accent"m C_RING1=$'\e[38;2;'"$ring1"m C_RING2=$'\e[38;2;'"$ring2"m
    C_OK=$'\e[38;2;87;227;137m' C_WARN=$'\e[38;2;248;196;92m' C_ERR=$'\e[38;2;246;97;81m'
    C_DIM=$'\e[90m' C_BOLD=$'\e[1m' C_RESET=$'\e[0m'
}

# Prints the GNOME accent colour as "r;g;b" (Kinobu gold when it cannot be read).
ui_accent() {
    case $(gsettings get org.gnome.desktop.interface accent-color 2>/dev/null || true) in
        *blue*)   echo '98;160;234' ;;  *teal*)   echo '51;199;222' ;;
        *green*)  echo '87;227;137' ;;  *orange*) echo '255;163;72' ;;
        *red*)    echo '246;97;81' ;;   *pink*)   echo '240;130;180' ;;
        *purple*) echo '192;97;203' ;;  *slate*)  echo '153;170;190' ;;
        *brown*)  echo '181;131;90' ;;  *)        echo '201;165;74' ;;
    esac
}

# Sets UI_ROWS and UI_COLS to the size of the terminal (24 x 80 when it cannot be read).
ui_size() {
    local size
    size=$(stty size 2>/dev/null </dev/tty || true)
    UI_ROWS=${size% *} UI_COLS=${size#* }
    if ! [[ $UI_ROWS =~ ^[0-9]+$ ]] || ((UI_ROWS < 10)); then UI_ROWS=24; fi
    if ! [[ $UI_COLS =~ ^[0-9]+$ ]] || ((UI_COLS < 40)); then UI_COLS=80; fi
}

# Prints the KINOBU wordmark (its O is the rings), then the version and a random tagline.
# A terminal too narrow for it gets plain text.
ui_banner() {
    local -a word=()
    local line plain tagline="" wide=0 caption
    local dir=$ROOT_DIR/files/branding
    if [[ -r $dir/wordmark.txt ]]; then mapfile -t word <"$dir/wordmark.txt"; fi
    if [[ -r $dir/taglines.txt ]]; then tagline=$(shuf -n 1 "$dir/taglines.txt"); fi
    for line in "${word[@]}"; do
        plain=${line//\$[123]/}
        if ((${#plain} > wide)); then wide=${#plain}; fi
    done
    caption="${C_ACCENT}v${APP_VERSION}${C_RESET} ${C_DIM}· ${tagline}${C_RESET}"
    ui_size
    echo
    if ((${#word[@]} == 0 || UI_COLS < wide + 4)); then
        printf '  %s%s%s%s %s\n\n' "$C_BOLD" "$C_ACCENT" "$APP_NAME" "$C_RESET" "$caption"
        return 0
    fi
    for line in "${word[@]}"; do
        line=${line//\$1/$C_RING1}; line=${line//\$2/$C_RING2}; line=${line//\$3/$C_ACCENT}
        printf '  %s%s\n' "$line" "$C_RESET"
    done
    printf '\n  %s\n\n' "$caption"
}

# Status lines: a title, then one line per item (label, optional detail).
ui_section() { printf '\n  %s%s%s\n' "$C_BOLD" "$1" "$C_RESET"; }
ui_line()    { printf '   %s%s%s %-34s %s%s%s\n' "$1" "$2" "$C_RESET" "$3" "$C_DIM" "${4:-}" "$C_RESET"; }
ui_ok()      { ui_line "$C_OK" "✔" "$@"; }
ui_fail()    { ui_line "$C_ERR" "✖" "$@"; }
ui_warn()    { ui_line "$C_WARN" "!" "$@"; }
ui_fact()    { ui_line "$C_ACCENT" "●" "$@"; }
ui_note()    { printf '  %s%s%s\n' "$C_DIM" "$*" "$C_RESET"; }
die()        { printf '%s%s✖ %s%s\n' "$C_ERR" "$C_BOLD" "$*" "$C_RESET" >&2; exit 1; }

# True when there is a terminal to ask questions on.
has_tty() { { : </dev/tty; } 2>/dev/null; }

# ui_checklist TITLE TEXT STEP ITEM...
# A full-screen list to tick with the keyboard. An ITEM is "id|label|description|on/off", or
# "-|Section" for a heading. STEP is "2/4" inside a series of lists (progress dots, B goes back)
# or empty. The chosen ids end up in UI_PICKED. Returns 0 confirmed, 1 quit, 2 back.
# shellcheck disable=SC2034  # UI_FULLSCREEN is read by cleanup (kinobu.sh)
ui_checklist() {
    local title=$1 text=$2 step=$3; shift 3
    local -a kind=() ids=() labels=() descs=() sel=() wrapped=()
    local -A on=()
    local item id label desc state i n pos=0 cur top=0 room wide=0 key rest all dots="" keys mark box now=0 total=0 result=0
    for item in "$@"; do
        IFS='|' read -r id label desc state <<<"$item"
        if [[ $id == - ]]; then
            kind+=(h); ids+=(""); labels+=("$label"); descs+=("")
            continue
        fi
        sel+=("${#kind[@]}")
        kind+=(i); ids+=("$id"); labels+=("$label"); descs+=("$desc")
        if [[ $state == on ]]; then on[$id]=1; fi
        if ((${#label} > wide)); then wide=${#label}; fi
    done
    n=${#kind[@]}
    UI_PICKED=()
    if ((${#sel[@]} == 0)); then return 0; fi
    keys="↑ ↓ move · Space select · A all or none · Enter confirm · Q quit"
    if [[ -n $step ]]; then
        now=${step%/*} total=${step#*/}
        for ((i = 1; i <= total; i++)); do
            if ((i <= now)); then dots+="${C_ACCENT}●${C_RESET} "; else dots+="${C_DIM}○${C_RESET} "; fi
        done
        keys="↑ ↓ move · Space select · A all or none · Enter next"
        if ((now == total)); then keys="↑ ↓ move · Space select · A all or none · Enter finish"; fi
        if ((now > 1)); then keys+=" · B back"; fi
        keys+=" · Q quit"
    fi
    UI_FULLSCREEN=true
    printf '\e[?1049h\e[?25l'
    while true; do
        ui_size
        mapfile -t wrapped < <(fold -s -w $((UI_COLS - 4)) <<<"$text")
        room=$((UI_ROWS - 7 - ${#wrapped[@]}))
        if ((room < 3)); then room=3; fi
        cur=${sel[pos]}
        if ((n <= room)); then
            top=0
        else
            if ((cur <= top)); then top=$((cur > 0 ? cur - 1 : 0)); fi
            if ((cur >= top + room)); then top=$((cur - room + 1)); fi
        fi
        printf '\e[H\e[2J\n  %s%s%s%s   %s\n' "$C_BOLD" "$C_ACCENT" "$title" "$C_RESET" "$dots"
        for item in "${wrapped[@]}"; do printf '  %s%s%s\n' "$C_DIM" "$item" "$C_RESET"; done
        echo
        for ((i = top; i < n && i < top + room; i++)); do
            if [[ ${kind[i]} == h ]]; then
                printf '  %s%s%s\n' "$C_BOLD" "${labels[i]}" "$C_RESET"
                continue
            fi
            mark=" "; box="[ ]"
            if ((i == cur)); then mark="${C_ACCENT}❯${C_RESET}"; fi
            if [[ -n ${on[${ids[i]}]:-} ]]; then box="${C_ACCENT}[✔]${C_RESET}"; fi
            desc=${descs[i]}
            desc=${desc:0:$((UI_COLS > wide + 13 ? UI_COLS - wide - 13 : 0))}
            printf '  %s %s %-*s  %s%s%s\n' "$mark" "$box" "$wide" "${labels[i]}" "$C_DIM" "$desc" "$C_RESET"
        done
        if ((top + room < n)); then printf '  %s↓ more%s\n' "$C_DIM" "$C_RESET"; else echo; fi
        printf '  %s%s%s' "$C_DIM" "${keys:0:$((UI_COLS - 3))}" "$C_RESET"
        IFS= read -rsn1 key </dev/tty || key=q
        if [[ $key == $'\e' ]]; then
            rest=""
            IFS= read -rsn2 -t 0.05 rest </dev/tty || true
            key+=$rest
        fi
        case $key in
            $'\e[A'|k) pos=$(((pos + ${#sel[@]} - 1) % ${#sel[@]})) ;;
            $'\e[B'|j) pos=$(((pos + 1) % ${#sel[@]})) ;;
            ' ')
                if [[ -n ${on[${ids[cur]}]:-} ]]; then unset "on[${ids[cur]}]"; else on[${ids[cur]}]=1; fi ;;
            a|A)
                all=true
                for i in "${sel[@]}"; do if [[ -z ${on[${ids[i]}]:-} ]]; then all=false; fi; done
                for i in "${sel[@]}"; do if $all; then unset "on[${ids[i]}]"; else on[${ids[i]}]=1; fi; done ;;
            '') break ;;
            b|B|$'\e[D') if ((now > 1)); then result=2; break; fi ;;
            q|Q|$'\e') result=1; break ;;
        esac
    done
    printf '\e[?25h\e[?1049l'
    UI_FULLSCREEN=false
    for i in "${sel[@]}"; do
        if [[ -n ${on[${ids[i]}]:-} ]]; then UI_PICKED+=("${ids[i]}"); fi
    done
    return "$result"
}
