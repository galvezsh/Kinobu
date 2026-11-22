# shellcheck shell=bash
# Block "context": the skills (the system's and the one for developing programs), the read-only
# subagent, the note, the answer style and the notifications of every agent.

# ---------------------------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------------------------
# GNOME notifications from the agents' hooks: finished, waiting for you, approve or deny
AGENT_NOTIFICATIONS=true
NOTIFY_APPROVALS="dialog"           # dialog: Allow / Deny window | notify: notification only
NOTIFY_SOUND=true                   # a short sound with each notice (silent with Do Not Disturb)
NOTIFY_WAIT=45                      # seconds the approval window waits before the terminal decides
NOTIFY_MIN_SECONDS=20               # "finished" is only shown for tasks that took at least this long

# ---------------------------------------------------------------------------------------------
# Block: context
# ---------------------------------------------------------------------------------------------
# Writes the skills, links them into every agent and adds the Kinobu note to their instructions
install_context() {
    local skills="$SYSTEM_DIR/skills"
    step "Skills for the agents ($skills)"
    write_skill "$skills/$APP_ID"
    write_dev_skill "$skills/$APP_ID-dev"
    ok "The system's ($(find "$skills/$APP_ID" -name '*.md' | wc -l) guides) and the one for developing programs"

    step "Linking the skills into each agent"
    # Same layout as Omarchy: symlinks, so re-running this script updates every agent.
    # Every supported agent gets them, installed or not, so one installed later is ready too.
    local dirs=("$HOME/.claude/skills") dir name link
    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
        for name in "$APP_ID" "$APP_ID-dev"; do
            link="$dir/$name"
            if [[ -e $link && ! -L $link ]]; then
                warn "Kept your own ${link/#$HOME/\~} (not a $APP_NAME link)"
            else
                ln -sfn "$skills/$name" "$link"
                ok "${link/#$HOME/\~}"
            fi
        done
    done

    install_subagents

    step "Note in the agents' global instructions (system + how to work)"
    # Always loaded by the agent (every conversation), so keep it short: details live in the skills
    local pointer
    # shellcheck disable=SC2034  # read by render (files/agents/note.md)
    USER_LANGUAGE=$(user_language)
    pointer=$(render agents/note.md APP_NAME APP_ID USER_LANGUAGE)
    local -A files=(
        [claude]="$HOME/.claude/CLAUDE.md"
    )
    local tool
    for tool in "${AGENT_TOOLS[@]}"; do
        put_block "${files[$tool]}" "<!-- $APP_ID:begin -->" "<!-- $APP_ID:end -->" "$pointer"
        report_changed "${files[$tool]/#$HOME/\~} updated" "${files[$tool]/#$HOME/\~} already up to date"
    done

    set_answer_style
    if $AGENT_NOTIFICATIONS; then install_agent_hooks; fi
}

# The user's language for the note, e.g. "Spanish (es_ES)", from their locale (English for C)
user_language() {
    local raw=${LANGUAGE:-${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}} name
    raw=${raw%%:*} raw=${raw%%.*} raw=${raw%%@*}
    if [[ -z $raw || $raw == C || $raw == POSIX ]]; then raw=en_US; fi
    case ${raw%%_*} in
        en) name=English ;; es) name=Spanish ;; de) name=German ;; fr) name=French ;;
        it) name=Italian ;; pt) name=Portuguese ;; ca) name=Catalan ;; nl) name=Dutch ;;
        *) name=$raw ;;
    esac
    printf '%s (%s)\n' "$name" "$raw"
}

# Claude Code answers tersely (its built-in Concise output style: the result first, no preamble
# or narration), unless the user already chose a style in either of its settings files. Its
# verbose mode (full command output on screen) stays off, always.
set_answer_style() {
    step "How the agents answer"
    local settings="$HOME/.claude/settings.json" chosen
    edit_json "$settings" '.verbose = false'
    chosen=$(jq -r '.outputStyle // empty' "$settings" "$HOME/.claude/settings.local.json" 2>/dev/null || true)
    if [[ -n $chosen ]]; then
        ok "Claude Code keeps the answer style you chose (${chosen//$'\n'/, }); verbose mode off"
        return 0
    fi
    edit_json "$settings" '.outputStyle = "Concise"'
    report_changed "Claude Code answers concisely (its Concise output style); verbose mode off" \
        "Claude Code already answers concisely; verbose mode off"
}

# Installs the read-only kinobu-agent subagent for every agent that has custom subagents,
# installed or not: one text (files/subagents/instructions.md) in each tool's own format.
# In Claude Code it runs in auto mode: it only reads, so it does not stop
# for approvals (an author's exception to "Kinobu never changes the agents' permissions").
install_subagents() {
    step "Read-only system subagent (kinobu-agent)"
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
        [claude]="$HOME/.claude/agents/kinobu-agent.md"
    )
    for tool in "${AGENT_TOOLS[@]}"; do
        dest=${dests[$tool]}
        put_user_file "$dest" < <(render "subagents/$tool.${dest##*.}" DESCRIPTION="$description" \
            INSTRUCTIONS="$instructions")
        report_changed "${dest/#$HOME/\~}" "${dest/#$HOME/\~} already up to date"
    done
}

# Installs kinobu-notify and adds Kinobu's own entries to every agent's hooks, installed or
# not, next to the hooks of other tools (only entries that run kinobu-notify are replaced).
# Format from Claude Code's docs (hooks + PermissionRequest).
# shellcheck disable=SC2016  # the jq filters use jq variables ($ours), not shell ones
install_agent_hooks() {
    step "Agent notifications (GNOME)"
    local n=$NOTIFIER wait=$((NOTIFY_WAIT + 15)) ours gate_wait
    put_file "$NOTIFIER" 0755 < <(render agents/kinobu-notify WAIT="$NOTIFY_WAIT" MIN="$NOTIFY_MIN_SECONDS" \
        APPROVALS="$NOTIFY_APPROVALS" SOUND="$NOTIFY_SOUND" SYSTEM_DIR PROGRAMS_DIR)
    write_translations
    if $CHANGED; then ok "$NOTIFIER written"; fi
    # Kinobu's approval window (libadwaita)
    put_file "$PROGRAMS_DIR/approve.py" < <(render apps/approve.py)
    # Sends each notice and brings back the agent's terminal when it is clicked
    put_file "$PROGRAMS_DIR/kinobu-notice.py" < <(render agents/kinobu-notice.py)

    # Claude Code's format: {"hooks": {"Event": [{matcher, hooks: [...]}]}}
    local claude_style='.hooks = ((.hooks // {})
        | with_entries(.value |= (map(.hooks |= map(select((.command // "") | contains("kinobu-notify") | not)))
                                  | map(select((.hooks // []) | length > 0))))
        | with_entries(select(.value | length > 0)))
      | reduce ($ours | to_entries[]) as $e (.; .hooks[$e.key] = ((.hooks[$e.key] // []) + [$e.value]))'
    # Notices run in the background (async): they answer nothing, so they never hold the agent.
    # Gate must answer, so it runs in the foreground, with a line in the terminal while it waits.
    # After a compaction the agent is told to read the project's CONTEXT.md again.
    gate_wait=$(notify_text gate_wait)
    ours=$(jq -n --arg n "$n" --argjson w "$wait" --arg gate "$gate_wait" '{
        UserPromptSubmit: {hooks: [{type: "command", command: "\($n) claude start", timeout: 5}]},
        Stop: {hooks: [{type: "command", command: "\($n) claude done", timeout: 10, async: true}]},
        StopFailure: {hooks: [{type: "command", command: "\($n) claude failed", timeout: 10, async: true}]},
        Notification: {matcher: "idle_prompt|elicitation_dialog|elicitation_url_dialog|agent_needs_input",
                       hooks: [{type: "command", command: "\($n) claude waiting", timeout: 10, async: true}]},
        PermissionRequest: {hooks: [{type: "command", command: "\($n) claude permission", timeout: $w,
                                     statusMessage: $gate}]},
        SessionStart: {matcher: "compact", hooks: [{type: "command", command: "\($n) claude compacted", timeout: 5}]}}')
    edit_json "$HOME/.claude/settings.json" "$claude_style" --argjson ours "$ours"
    hooks_report "Claude Code" "$HOME/.claude/settings.json"
}

# A text of the notices (files/i18n, section "notify") in the user's language, English if missing
notify_text() {
    local code file text
    code=$(user_language); code=${code##*(}; code=${code%%_*}
    for file in "$ROOT_DIR/files/i18n/$code.json" "$ROOT_DIR/files/i18n/en.json"; do
        text=$(jq -r --arg k "$1" '.notify[$k] // empty' "$file" 2>/dev/null || true)
        if [[ -n $text ]]; then printf '%s\n' "$text"; return 0; fi
    done
    printf '%s\n' "$1"
}

# One line per agent for install_agent_hooks
hooks_report() {
    report_changed "$1: ${2/#$HOME/\~} updated" "$1: already up to date"
}

# Writes the system skill from files/skills/kinobu/ (generic on purpose: hardware, versions and
# apps are always checked live); the shortcut table in shortcuts.md comes from SHORTCUTS
write_skill() {
    local dir=$1 guide table="" entry group accels action
    for entry in "${SHORTCUTS[@]}"; do
        IFS='|' read -r group accels action _ <<<"$entry"
        table+="| $group | $(pretty_all_keys "$accels") | $action |"$'\n'
    done
    put_file "$dir/SKILL.md" < <(render skills/kinobu/SKILL.md APP_ID APP_NAME SYSTEM_DIR BIN_DIR LAUNCHER)
    put_file "$dir/shortcuts.md" < <(render skills/kinobu/shortcuts.md APP_ID APP_NAME LAUNCHER TABLE="${table%$'\n'}")
    for guide in software desktop look hardware agents; do
        put_file "$dir/$guide.md" < <(render "skills/kinobu/$guide.md" APP_NAME SYSTEM_DIR BIN_DIR LAUNCHER NOTIFIER)
    done
}

# Writes the skill for developing programs (git checkpoints, CONTEXT.md, architecture)
write_dev_skill() {
    put_file "$1/SKILL.md" < <(render skills/kinobu-dev/SKILL.md APP_ID)
}
