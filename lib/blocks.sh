# shellcheck shell=bash
# The setup blocks, in run order. Each one will get its own file in lib/ as it is written.

BLOCKS=(apt apps ai drivers services user desktop shortcuts context)
declare -A BLOCK_TITLE=(
    [apt]="Optimised packages" [apps]="Applications" [ai]="AI tools"
    [drivers]="Drivers" [services]="Services" [user]="Shell and terminals"
    [desktop]="Desktop" [shortcuts]="Shortcuts" [context]="Agent context"
)
declare -A BLOCK_DESC=(
    [apt]="Faster builds of Ubuntu packages when the processor supports them"
    [apps]="The apps you choose, the development base and a system upgrade"
    [ai]="The AI agents and local AI tools you choose, and the voice assistant"
    [drivers]="The drivers Ubuntu recommends for this hardware"
    [services]="Dictation input and services a desktop does not need"
    [user]="Prompt, terminal font and the Kinobu system summary"
    [desktop]="Theme, extensions, dock, workspaces and wallpapers"
    [shortcuts]="Easy-to-remember keyboard shortcuts and their cheat sheet"
    [context]="What your AI agents know about this system, and their notifications"
)

# The function that runs each block (RUN_KIND, set in main, is setup or update)
# shellcheck disable=SC2034  # read by run_plan (core.sh)
declare -A BLOCK_FN=(
    [apt]=enable_apt_v3 [apps]=manage_applications [ai]=install_ai_tools
    [drivers]=install_drivers [services]=configure_services [user]=configure_user
    [desktop]=configure_desktop [shortcuts]=configure_shortcuts [context]=install_context
)

# The function and the description of a block in this run (an update has its own).
block_fn()   { if [[ ${RUN_KIND:-} == update ]]; then echo "${UPDATE_FN[$1]:-}"; else echo "${BLOCK_FN[$1]:-}"; fi; }
block_desc() { if [[ ${RUN_KIND:-} == update ]]; then echo "${UPDATE_DESC[$1]:-}"; else echo "${BLOCK_DESC[$1]:-}"; fi; }

# Prints one "id|title|description|on" line per block, for ui_checklist.
block_items() {
    local block
    for block in "${BLOCKS[@]}"; do
        echo "$block|${BLOCK_TITLE[$block]}|${BLOCK_DESC[$block]}|on"
    done
}
