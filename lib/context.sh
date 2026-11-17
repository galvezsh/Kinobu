# shellcheck shell=bash
# Block "context": the system skill, the read-only subagent, the note and the notifications of every agent.

# ---------------------------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------------------------
# GNOME notifications from the agents' hooks: finished, waiting for you, approve or deny
AGENT_NOTIFICATIONS=true
NOTIFY_APPROVALS="dialog"           # dialog: Allow / Deny window (Claude Code, Codex) | notify: notification only
NOTIFY_SOUND=true                   # a short sound with each notice (silent with Do Not Disturb)
NOTIFY_WAIT=45                      # seconds the approval window waits before the terminal decides
NOTIFY_MIN_SECONDS=20               # "finished" is only shown for tasks that took at least this long

# ---------------------------------------------------------------------------------------------
# Block: context
# ---------------------------------------------------------------------------------------------
# Writes the system skill, links it into every agent and adds the Kinobu note to their instructions
install_context() {
    local skill="$SYSTEM_DIR/skills/$APP_ID"
    step "System skill ($skill)"
    write_skill "$skill"
    ok "$(find "$skill" -name '*.md' | wc -l) guides written"

    step "Linking the skill into each agent"
    # Same layout as Omarchy: symlinks, so re-running this script updates every agent.
    # Every supported agent gets it, installed or not, so one installed later is ready too.
    # ~/.agents/skills is read by Codex; Claude Code reads ~/.claude/skills; Antigravity,
    # ~/.gemini/config/skills.
    local dirs=("$HOME/.agents/skills" "$HOME/.claude/skills" "$HOME/.codex/skills"
        "$HOME/.gemini/config/skills") dir link
    for dir in "${dirs[@]}"; do
        link="$dir/$APP_ID"
        mkdir -p "$dir"
        if [[ -e $link && ! -L $link ]]; then
            warn "Kept your own ${link/#$HOME/\~} (not a $APP_NAME link)"
        else
            ln -sfn "$skill" "$link"
            ok "${link/#$HOME/\~}"
        fi
    done

    install_subagents

    step "Note in the agents' global instructions (system + how to work)"
    # Always loaded by the agent (every conversation), so keep it short: details live in the skill
    local pointer
    pointer=$(render agents/note.md APP_NAME APP_ID)
    local -A files=(
        [claude]="$HOME/.claude/CLAUDE.md"
        [codex]="$HOME/.codex/AGENTS.md"
        [agy]="$HOME/.gemini/GEMINI.md"
    )
    local tool
    for tool in claude codex agy; do
        put_block "${files[$tool]}" "<!-- $APP_ID:begin -->" "<!-- $APP_ID:end -->" "$pointer"
        report_changed "${files[$tool]/#$HOME/\~} updated" "${files[$tool]/#$HOME/\~} already up to date"
    done

    if $AGENT_NOTIFICATIONS; then install_agent_hooks; fi
}

# Installs the read-only kinobu-system subagent for every agent that has custom subagents,
# installed or not: one text (files/subagents/instructions.md) in each tool's own format.
# In Claude Code it runs in auto mode: it only reads, so it does not stop
# for approvals (an author's exception to "Kinobu never changes the agents' permissions").
install_subagents() {
    step "Read-only system subagent (kinobu-system)"
    local description instructions tool dest
    # It reads the system logs without sudo through the adm group (Ubuntu's log readers, not
    # root-equivalent). The first user is in it already; another admin is added once.
    if $SYSTEM_WRITES && [[ ",$(getent group adm | cut -d: -f4)," != *",$USER,"* ]]; then
        root usermod -aG adm "$USER"
        need_reboot "added to the adm group (logging out is enough)"
        ok "Added you to the adm group, so it can read the system logs"
    fi
    description=$(render subagents/description.txt)
    instructions=$(render subagents/instructions.md SYSTEM_DIR PROGRAMS_DIR)
    local -A dests=(
        [claude]="$HOME/.claude/agents/kinobu-system.md"
        [codex]="$HOME/.codex/agents/kinobu-system.toml"
        [antigravity]="$HOME/.gemini/config/agents/kinobu-system/agent.md"
    )
    for tool in claude codex antigravity; do
        dest=${dests[$tool]}
        put_user_file "$dest" < <(render "subagents/$tool.${dest##*.}" DESCRIPTION="$description" \
            INSTRUCTIONS="$instructions")
        report_changed "${dest/#$HOME/\~}" "${dest/#$HOME/\~} already up to date"
    done
}

# Installs kinobu-notify and adds Kinobu's own entries to every agent's hooks, installed or
# not, next to the hooks of other tools (only entries that run kinobu-notify are replaced).
# Formats from each agent's docs: Claude Code and Codex (hooks + PermissionRequest) and
# Antigravity (~/.gemini/config/hooks.json).
# shellcheck disable=SC2016  # the jq filters use jq variables ($ours), not shell ones
install_agent_hooks() {
    step "Agent notifications (GNOME)"
    local n=$NOTIFIER wait=$((NOTIFY_WAIT + 15)) ours
    put_file "$NOTIFIER" 0755 < <(render agents/kinobu-notify WAIT="$NOTIFY_WAIT" MIN="$NOTIFY_MIN_SECONDS" \
        APPROVALS="$NOTIFY_APPROVALS" SOUND="$NOTIFY_SOUND" SYSTEM_DIR PROGRAMS_DIR)
    write_translations
    if $CHANGED; then ok "$NOTIFIER written"; fi
    # Kinobu's approval window (libadwaita)
    put_file "$PROGRAMS_DIR/approve.py" < <(render apps/approve.py)
    # Sends each notice and brings back the agent's terminal when it is clicked
    put_file "$PROGRAMS_DIR/kinobu-notice.py" < <(render agents/kinobu-notice.py)

    # Claude Code and Codex share the format: {"hooks": {"Event": [{matcher, hooks: [...]}]}}
    local claude_style='.hooks = ((.hooks // {})
        | with_entries(.value |= (map(.hooks |= map(select((.command // "") | contains("kinobu-notify") | not)))
                                  | map(select((.hooks // []) | length > 0))))
        | with_entries(select(.value | length > 0)))
      | reduce ($ours | to_entries[]) as $e (.; .hooks[$e.key] = ((.hooks[$e.key] // []) + [$e.value]))'
    ours=$(jq -n --arg n "$n" --argjson w "$wait" '{
        UserPromptSubmit: {hooks: [{type: "command", command: "\($n) claude start", timeout: 5}]},
        Stop: {hooks: [{type: "command", command: "\($n) claude done", timeout: 10}]},
        StopFailure: {hooks: [{type: "command", command: "\($n) claude failed", timeout: 10}]},
        Notification: {matcher: "idle_prompt", hooks: [{type: "command", command: "\($n) claude waiting", timeout: 10}]},
        PermissionRequest: {hooks: [{type: "command", command: "\($n) claude permission", timeout: $w}]}}')
    edit_json "$HOME/.claude/settings.json" "$claude_style" --argjson ours "$ours"
    hooks_report "Claude Code" "$HOME/.claude/settings.json"
    ours=$(jq -n --arg n "$n" --argjson w "$wait" '{
        UserPromptSubmit: {hooks: [{type: "command", command: "\($n) codex start", timeout: 5}]},
        Stop: {hooks: [{type: "command", command: "\($n) codex done", timeout: 10}]},
        PermissionRequest: {hooks: [{type: "command", command: "\($n) codex permission", timeout: $w}]}}')
    edit_json "$HOME/.codex/hooks.json" "$claude_style" --argjson ours "$ours"
    hooks_report "Codex" "$HOME/.codex/hooks.json"
    if $CHANGED; then info "Codex runs new hooks once you trust them: open Codex and type /hooks"; fi

    # Antigravity: one named hook set; waiting = the agent asks you (ask_question, ask_permission)
    ours=$(jq -n --arg n "$n" '{
        PreToolUse: [{matcher: "ask_question|ask_permission", hooks: [{type: "command", command: "\($n) agy waiting", timeout: 5}]}],
        Stop: [{type: "command", command: "\($n) agy done", timeout: 10}]}')
    edit_json "$HOME/.gemini/config/hooks.json" '.["kinobu-notify"] = $ours' --argjson ours "$ours"
    hooks_report "Antigravity" "$HOME/.gemini/config/hooks.json"
}

# One line per agent for install_agent_hooks
hooks_report() {
    report_changed "$1: ${2/#$HOME/\~} updated" "$1: already up to date"
}

# Writes the skill guides from files/skill/ (generic on purpose: hardware is always checked live);
# the shortcut table in shortcuts.md comes from SHORTCUTS
write_skill() {
    local dir=$1 guide table="" entry group accels action
    for entry in "${SHORTCUTS[@]}"; do
        IFS='|' read -r group accels action _ <<<"$entry"
        table+="| $group | $(pretty_all_keys "$accels") | $action |"$'\n'
    done
    put_file "$dir/SKILL.md" < <(render skill/SKILL.md APP_ID APP_NAME APP_VERSION JAVA_DIR WORKSPACES \
        OMB_THEME NERD_FONT_FAMILY SYSTEM_DIR BIN_DIR)
    put_file "$dir/shortcuts.md" < <(render skill/shortcuts.md APP_ID APP_NAME LAUNCHER TABLE="${table%$'\n'}")
    for guide in software desktop hardware agents; do
        put_file "$dir/$guide.md" < <(render "skill/$guide.md" SYSTEM_DIR PROGRAMS_DIR LAUNCHER NOTIFIER)
    done
}
