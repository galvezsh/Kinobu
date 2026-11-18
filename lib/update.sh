# shellcheck shell=bash
# --update: brings a computer set up by an earlier version to this one without touching the
# user's look (their theme and picks in ~/.config/kinobu/look.toml, terminal font, dock,
# weather, power and extensions stay as they are).

# shellcheck disable=SC2034  # read by run_plan and confirm_start
UPDATE_BLOCKS=(apps ai user desktop shortcuts context)
# shellcheck disable=SC2034
declare -A UPDATE_FN=(
    [apps]=update_applications [ai]=update_ai_tools [user]=update_user_files
    [desktop]=update_look [shortcuts]=configure_shortcuts [context]=install_context
)
# shellcheck disable=SC2034
declare -A UPDATE_DESC=(
    [apps]="Ubuntu, the Snap Store apps, Handy and Java; no new apps are added"
    [ai]="The AI tools that are installed and the voice assistant"
    [user]="$APP_NAME's part of the shell and the system summary (palette and fonts are kept)"
    [desktop]="The themes, Seasons and their icons and cursors (your look is kept)"
    [shortcuts]="$APP_NAME's shortcuts, their cheat sheet and the welcome tour"
    [context]="What your AI agents know about this system, and their notifications"
)

# Updates what is installed: system packages, snaps, Handy and GraalVM. Installs no new apps,
# except Handy when it is missing (the voice assistant listens through it).
update_applications() {
    upgrade_system
    step "Apps from the Snap Store"
    if run sudo -n snap refresh; then ok "Up to date"; else warn "The Snap Store apps could not be updated: they update themselves later"; fi
    # Handy's settings are the user's after the first run: only a new install gets Kinobu's
    if is_installed handy; then
        install_handy
    else
        install_handy
        configure_handy
    fi
    if compgen -G "/opt/java/graalvm-jdk-*" >/dev/null; then install_graalvm; fi
    step "Cleaning up"
    apt_get autoremove --purge
    apt_get clean
    ok "Unused packages removed"
}

# Updates the AI tools that are installed, each with its own updater.
update_ai_tools() {
    local entry id cmd url shell found=false
    export PATH="$HOME/.local/bin:$PATH"
    for entry in "${AI_INSTALLERS[@]}"; do
        IFS='|' read -r id cmd url shell <<<"$entry"
        if ! has_cmd "$cmd"; then continue; fi
        found=true
        step "$(software_name "$id")"
        case $id in
            claude) if run claude update; then ok "Up to date"; else warn "Claude Code could not be updated (it updates itself too)"; fi ;;
            *)  # Ollama: the installer is also the updater (settings are kept)
                if run_installer "$url" "$shell"; then ok "Up to date"; else warn "$(software_name "$id") could not be updated"; fi ;;
        esac
    done
    if is_installed lm-studio; then found=true; step "LM Studio"; ok "It updates itself"; fi
    if ! $found; then step "AI tools"; info "None installed"; fi

    step "uv (Python tools for your agents)"
    if ! has_cmd uv; then
        info "Not installed"
    elif run uv self update; then
        ok "Up to date"
    else
        warn "uv could not be updated"
    fi

    install_voice
}

# Rewrites the files Kinobu owns in the shell: the ~/.bashrc block, fastfetch and ydotool's retries.
update_user_files() {
    write_shell_profile
    write_fastfetch
    step "Dictation typing (ydotool)"
    ydotool_retry
}

# The themes and their packs, then the user's own look applied again (kept as it is)
update_look() {
    install_look
    apply_look
}
