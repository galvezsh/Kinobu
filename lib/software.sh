# shellcheck shell=bash
# The software the user can choose, and the menus that ask for it.

# One menu per entry of MENUS. SOFTWARE lines are "menu|id|name|description|on/off|source"
# (on = preselected), and "menu|-|Section" starts a section. The source tells the apps block how
# to install it: "apt:<packages>", "snap:<name> [flags]", "deb:<package> <url>" or "own" (code in
# the block); AI tools have none, the ai block installs them. Unticking never uninstalls.
MENUS=(apps dev ai extra)
declare -A MENU_TITLE=([apps]="Applications" [dev]="Development" [ai]="AI agents" [extra]="Extra tools")
declare -A MENU_TEXT=(
    [apps]="Everyday apps. Firefox always stays installed; the first browser you pick here becomes the default one."
    [dev]="Editors and IDEs. Python, Node.js, the GraalVM JDK and the build tools are always installed."
    [ai]="Coding agents that $APP_NAME integrates into the system. The first one you pick opens with Super+Shift+Enter."
    [extra]="Containers, virtual machines, local AI and office suites."
)
SOFTWARE=(
    "apps|-|Web browsers"
    "apps|helium|Helium|fast, private Chromium|off|apt:helium-bin"
    "apps|chrome|Google Chrome|Google's browser|on|deb:google-chrome-stable https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
    "apps|-|Media"
    "apps|spotify|Spotify|music streaming|off|apt:spotify-client"
    "apps|vlc|VLC|plays any video or audio file|off|apt:vlc"
    "apps|-|Media creation"
    "apps|obs|OBS Studio|screen recording and streaming|off|apt:obs-studio"
    "apps|audacity|Audacity|audio editor|off|apt:audacity"
    "apps|handbrake|HandBrake|video converter|off|apt:handbrake"
    "apps|blender|Blender|3D modelling and animation|off|snap:blender --classic"
    "apps|gimp|GIMP|photo editing|off|apt:gimp"
    "apps|krita|Krita|digital painting|off|apt:krita"
    "apps|-|Desktop"
    "apps|missioncenter|Mission Center|task manager, like the one in Windows (Ctrl+Shift+Esc)|on|snap:mission-center"
    "dev|-|Editors"
    "dev|vscode|VS Code|Microsoft's editor, with Copilot|on|apt:code"
    "dev|antigravity|Antigravity|Google's agentic IDE|off|snap:antigravity-ide-snap --classic"
    "dev|cursor|Cursor|AI code editor|off|apt:cursor"
    "dev|androidstudio|Android Studio|Android apps|off|snap:android-studio --classic"
    "dev|eclipse|Eclipse|Java IDE (Eclipse Foundation)|off|snap:eclipse --classic"
    "dev|-|JetBrains"
    "dev|intellij|IntelliJ IDEA|Java, Kotlin|on|snap:intellij-idea --classic"
    "dev|pycharm|PyCharm|Python|on|snap:pycharm --classic"
    "dev|webstorm|WebStorm|JavaScript, TypeScript|off|snap:webstorm --classic"
    "dev|clion|CLion|C, C++|off|snap:clion --classic"
    "dev|goland|GoLand|Go|off|snap:goland --classic"
    "dev|rider|Rider|.NET, C#|off|snap:rider --classic"
    "dev|phpstorm|PhpStorm|PHP|off|snap:phpstorm --classic"
    "dev|rubymine|RubyMine|Ruby|off|snap:rubymine --classic"
    "dev|rustrover|RustRover|Rust|off|snap:rustrover --classic"
    "dev|datagrip|DataGrip|databases|off|snap:datagrip --classic"
    "ai|-|Coding agents"
    "ai|claude|Claude Code|Anthropic|on"
    "ai|codex|Codex|OpenAI|off"
    "ai|agy|Antigravity CLI|Google|off"
    "extra|-|Containers and virtual machines"
    "extra|docker|Docker Engine|containers (used with sudo docker)|off|apt:docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
    "extra|virtmanager|virt-manager|virtual machines with KVM|off|apt:virt-manager qemu-system-x86 libvirt-daemon-system ovmf swtpm-tools qemu-utils"
    "extra|-|Local AI"
    "extra|ollama|Ollama|run models on this computer|off"
    "extra|lmstudio|LM Studio|run models on this computer, with a window|off"
    "extra|-|Office"
    "extra|libreoffice|LibreOffice|Writer, Calc, Impress|off|apt:libreoffice libreoffice-gnome libreoffice-style-yaru"
    "extra|onlyoffice|OnlyOffice|suite that looks like Microsoft Office|off|snap:onlyoffice-desktopeditors"
)
AI_TOOLS=(claude codex agy ollama lmstudio)   # installed by the ai block; the rest by apps

in_list() { [[ " $2 " == *" $1 "* ]]; }             # in_list WORD "a b c"
planned() { in_list "$1" "${PLAN[*]}"; }            # is this block going to run?
chosen()  { in_list "$1" "${CHOSEN[*]}"; }          # did the user pick this software?

# Prints the block that installs a software id.
software_block() { if in_list "$1" "${AI_TOOLS[*]}"; then echo ai; else echo apps; fi; }

# Prints the name of a software id ("Google Chrome"), or how the apps block installs it.
software_name()   { software_field "$1" 3; }
software_source() { software_field "$1" 6; }
software_field() {
    local entry
    local -a field=()
    for entry in "${SOFTWARE[@]}"; do
        IFS='|' read -ra field <<<"$entry"
        if [[ ${field[1]} == "$1" ]]; then echo "${field[$2 - 1]:-}"; return 0; fi
    done
}

# True when a software id can be chosen in this run: its block is planned and, with --user (no
# password), it installs in the user's own folder, which only the coding agents do.
offered() {
    if ! planned "$(software_block "$1")"; then return 1; fi
    if ! $SYSTEM_WRITES && ! in_list "$1" "${AGENT_TOOLS[*]}"; then return 1; fi
    return 0
}

# True when a menu has something to offer for the planned blocks.
menu_offered() {
    local entry menu id
    for entry in "${SOFTWARE[@]}"; do
        IFS='|' read -r menu id _ <<<"$entry"
        if [[ $menu == "$1" && $id != - ]] && offered "$id"; then return 0; fi
    done
    return 1
}

# Prints the "id|name|description|state" items of one menu whose block is planned, with its
# section headings. The state comes from PICK, so going back shows what was ticked.
menu_items() {
    local entry menu id name desc heading=""
    for entry in "${SOFTWARE[@]}"; do
        IFS='|' read -r menu id name desc _ <<<"$entry"
        if [[ $menu != "$1" ]]; then continue; fi
        if [[ $id == - ]]; then heading=$name; continue; fi
        if ! offered "$id"; then continue; fi
        if [[ -n $heading ]]; then echo "-|$heading"; heading=""; fi
        if [[ -n ${PICK[$id]:-} ]]; then echo "$id|$name|$desc|on"; else echo "$id|$name|$desc|off"; fi
    done
}

# Asks what to install, one menu after another (B goes back). The ids end up in CHOSEN.
# Without a terminal the preselected software is taken. Returns 1 if the user quits.
choose_software() {
    local -A PICK=()
    local -a menus=() items=()
    local entry menu id state line i=0 code
    for entry in "${SOFTWARE[@]}"; do
        IFS='|' read -r _ id _ _ state _ <<<"$entry"
        if [[ $state == on ]]; then PICK[$id]=1; fi
    done
    for menu in "${MENUS[@]}"; do
        if menu_offered "$menu"; then menus+=("$menu"); fi
    done
    while has_tty && ((i < ${#menus[@]})); do
        menu=${menus[i]}
        mapfile -t items < <(menu_items "$menu")
        code=0
        ui_checklist "${MENU_TITLE[$menu]}" "${MENU_TEXT[$menu]}" "$((i + 1))/${#menus[@]}" "${items[@]}" || code=$?
        if ((code == 1)); then return 1; fi
        for line in "${items[@]}"; do
            id=${line%%|*}
            if [[ $id != - ]]; then unset "PICK[$id]"; fi
        done
        for id in "${UI_PICKED[@]}"; do PICK[$id]=1; done
        if ((code == 2)); then i=$((i - 1)); else i=$((i + 1)); fi
    done
    CHOSEN=()
    for entry in "${SOFTWARE[@]}"; do
        IFS='|' read -r _ id _ <<<"$entry"
        if [[ $id != - && -n ${PICK[$id]:-} ]] && offered "$id"; then CHOSEN+=("$id"); fi
    done
}

# Prints what was chosen, one line per menu.
software_summary() {
    local menu entry m id name names
    ui_section "Your software"
    for menu in "${MENUS[@]}"; do
        if ! menu_offered "$menu"; then continue; fi
        names=""
        for entry in "${SOFTWARE[@]}"; do
            IFS='|' read -r m id name _ <<<"$entry"
            if [[ $m == "$menu" && $id != - ]] && chosen "$id"; then names+="$name, "; fi
        done
        names=${names%, }
        ui_fact "${MENU_TITLE[$menu]}" "${names:-nothing selected}"
    done
    echo
}
