# shellcheck shell=bash
# Block "ai": the AI agents and local AI tools the user chose, and uv.

# ---------------------------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------------------------
# Official installers, run as the user: "software id|command it installs|installer URL|shell"
AI_INSTALLERS=(
    "claude|claude|https://claude.ai/install.sh|bash"
    "codex|codex|https://chatgpt.com/codex/install.sh|sh"
    "agy|agy|https://antigravity.google/cli/install.sh|bash"
    "ollama|ollama|https://ollama.com/install.sh|sh"
)
LMSTUDIO_URL="https://lmstudio.ai/download/latest/linux/x64?format=deb"   # the package is lm-studio
UV_URL="https://astral.sh/uv/install.sh"
AGENT_TOOLS=(claude codex agy)      # coding agents, in the order they become the default one

# Zen, the voice assistant (always installed with Handy, which it listens through). Its voices
# follow the desktop language (ZEN_PIPER; English for any other). Qwen3-TTS, its most natural
# voice, runs in llama.cpp's Vulkan build (any GPU vendor) and is installed only with a dedicated
# graphics card unless ZEN_QWEN says otherwise. The voice worker's Python packages and Qwen's
# reference voices are set up by zen.py --prepare (files/apps/zen.py).
ZEN_QWEN=auto                      # auto (with a dedicated graphics card) | yes | no
KOKORO_URL="https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.1"
PIPER_URL="https://huggingface.co/rhasspy/piper-voices/resolve/main"
declare -A ZEN_PIPER=(             # Piper voices per language (only ones with a free licence)
    [es]="es/es_ES/davefx/medium/es_ES-davefx-medium"
    [en]="en/en_US/joe/medium/en_US-joe-medium en/en_US/kristin/medium/en_US-kristin-medium"
)
LLAMA_BUILD=b12284                  # llama.cpp release with Vulkan and Qwen3-TTS (llama-server /tts)
QWEN_URL="https://huggingface.co/ggml-org/Qwen3-TTS-12Hz-1.7B-Base-GGUF/resolve/main"
QWEN_FILES="Qwen3-TTS-12Hz-1.7B-Base-Q4_K_M.gguf:qwen3-tts-1.7b-base-Q4_K_M.gguf mmproj-Qwen3-TTS-12Hz-1.7B-Base-Q8_0.gguf:mmproj-qwen3-tts-1.7b-base-Q8_0.gguf"

# ---------------------------------------------------------------------------------------------
# Block: ai
# ---------------------------------------------------------------------------------------------
has_cmd() { command -v "$1" >/dev/null 2>&1; }

# Downloads an official installer and runs it with its output in the log. Returns 1 if it fails.
run_installer() {   # run_installer URL SHELL
    local script="$TMP_DIR/installer.sh"
    rm -f "$script"
    if ! curl -fsSL "$1" -o "$script" 2>>"$LOG"; then return 1; fi
    # Codex's installer asks questions unless told not to
    run env CODEX_NON_INTERACTIVE=true "$2" "$script"
}

install_ai_tools() {
    local entry id cmd url shell tool path="" agent=""
    # npm installs global tools in ~/.local instead of /usr (no sudo needed)
    if has_cmd npm && [[ "$(npm config get prefix 2>/dev/null)" != "$HOME/.local" ]]; then
        npm config set prefix "$HOME/.local" >>"$LOG" 2>&1 || true
    fi
    export PATH="$HOME/.local/bin:$PATH"

    for entry in "${AI_INSTALLERS[@]}"; do
        IFS='|' read -r id cmd url shell <<<"$entry"
        if ! chosen "$id"; then continue; fi
        # Ollama installs a system service: not for --user, which never asks for a password
        if ! $SYSTEM_WRITES && ! in_list "$id" "${AGENT_TOOLS[*]}"; then continue; fi
        step "$(software_name "$id")"
        if has_cmd "$cmd"; then
            ok "Already installed"
        elif run_installer "$url" "$shell"; then
            ok "Installed"
            if in_list "$id" "${AGENT_TOOLS[*]}"; then NEXT_STEPS+=("Open $(software_name "$id") once to sign in: type $cmd in a terminal"); fi
        else
            warn "$(software_name "$id") could not be installed: run $APP_NAME again later, or see ${url%/*}"
        fi
    done

    if $SYSTEM_WRITES && chosen lmstudio; then
        step "LM Studio"
        if is_installed lm-studio; then
            ok "Already installed"
        elif install_deb "$LMSTUDIO_URL" lmstudio; then
            ok "Installed"
        else
            warn "LM Studio could not be installed: get it from https://lmstudio.ai"
        fi
    fi

    step "uv (Python tools for your agents)"
    if has_cmd uv; then
        ok "Already installed"
    elif run_installer "$UV_URL" sh; then
        ok "Installed"
    else
        warn "uv could not be installed: see https://docs.astral.sh/uv/"
    fi

    install_zen

    # The first chosen agent that is installed opens with Super+Shift+Enter
    step "Default agent"
    for tool in "${AGENT_TOOLS[@]}"; do
        if chosen "$tool" && path=$(command -v "$tool" 2>/dev/null); then agent=$tool; break; fi
    done
    mkdir -p "$CONFIG_DIR"
    if [[ -n $agent ]]; then
        printf '%s\n' "$path" >"$CONFIG_DIR/agent"
        ok "$(software_name "$agent") (Super+Shift+Enter)"
    else
        rm -f "$CONFIG_DIR/agent"
        info "No agent chosen: Super+Shift+Enter will have nothing to open"
    fi
}

# Downloads a file once: skipped when it is already there; an interrupted download starts again
fetch() {
    if [[ -s $2 ]]; then return 0; fi
    mkdir -p "$(dirname "$2")"
    if download "$1" "$2.part"; then mv "$2.part" "$2"; return 0; fi
    rm -f "$2.part"
    return 1
}

# True when Zen should get Qwen3-TTS: ZEN_QWEN=yes, or auto with a dedicated graphics card
zen_qwen() {
    local gpus
    case $ZEN_QWEN in yes) return 0 ;; no) return 1 ;; esac
    gpus=$(lspci 2>/dev/null | grep -E 'VGA|3D|Display' || true)
    [[ $gpus =~ $DISCRETE_GPU ]]
}

# Zen, the voice assistant: the app, its voice worker and icon, Kokoro, the Piper voices of the
# desktop language and, with a dedicated graphics card, llama.cpp (Vulkan) and Qwen3-TTS. Then
# zen.py --prepare installs the worker's Python packages (uv) and Qwen's reference voices.
# Only what is missing is downloaded: about 450 MB the first time, 2 GB with Qwen3-TTS.
install_zen() {
    step "Zen (voice assistant, Super+Shift+Space)"
    local models="$DATA_DIR/zen/models" llama="$DATA_DIR/zen/llama" lang voice pair qwen=false
    local failed=false engine=kokoro
    lang=${LANG%%[_.]*}
    if [[ -z ${ZEN_PIPER[$lang]:-} ]]; then lang=en; fi
    write_translations
    put_file "$PROGRAMS_DIR/zen.py" < <(render apps/zen.py SYSTEM_DIR PROGRAMS_DIR)
    put_file "$PROGRAMS_DIR/zen-tts.py" < <(render apps/zen-tts.py)
    put_file "$PREFIX/share/icons/hicolor/scalable/apps/os.kinobu.Zen.svg" < <(render apps/zen.svg)
    put_file "$PREFIX/share/applications/os.kinobu.Zen.desktop" < <(render apps/zen.desktop SYSTEM_DIR PROGRAMS_DIR)
    fetch "$KOKORO_URL/kokoro-v1.0.onnx" "$models/kokoro-v1.0.onnx" || failed=true
    fetch "$KOKORO_URL/voices-v1.0.bin" "$models/voices-v1.0.bin" || failed=true
    for voice in ${ZEN_PIPER[$lang]}; do
        fetch "$PIPER_URL/$voice.onnx" "$models/${voice##*/}.onnx" || failed=true
        fetch "$PIPER_URL/$voice.onnx.json" "$models/${voice##*/}.onnx.json" || failed=true
    done
    if zen_qwen; then
        qwen=true engine=qwen
        if [[ "$(cat "$llama/.build" 2>/dev/null)" != "$LLAMA_BUILD" ]]; then
            if download "https://github.com/ggml-org/llama.cpp/releases/download/$LLAMA_BUILD/llama-$LLAMA_BUILD-bin-ubuntu-vulkan-x64.tar.gz" "$TMP_DIR/llama.tar.gz"; then
                rm -rf "$llama"
                mkdir -p "$llama"
                # A damaged download must not look installed: the marker is written only on success
                if tar -xzf "$TMP_DIR/llama.tar.gz" -C "$llama" --strip-components=1 2>>"$LOG"; then
                    echo "$LLAMA_BUILD" >"$llama/.build"
                else
                    failed=true
                fi
            else failed=true; fi
        fi
        for pair in $QWEN_FILES; do
            fetch "$QWEN_URL/${pair%%:*}" "$models/${pair#*:}" || failed=true
        done
    fi
    if ! run env PATH="$HOME/.local/bin:$PATH" python3 "$PROGRAMS_DIR/zen.py" --prepare; then failed=true; fi
    # First install: the best voice this computer can run (Qwen3-TTS with a dedicated card)
    if [[ ! -f $CONFIG_DIR/zen.json ]]; then
        mkdir -p "$CONFIG_DIR"
        printf '{\n  "engine": "%s"\n}\n' "$engine" >"$CONFIG_DIR/zen.json"
    fi
    if ! is_installed handy; then warn "Zen listens through Handy, which is not installed: run $APP_NAME again"; fi
    if $failed; then warn "Zen: some voices could not be set up (bash kinobu.sh --update tries again)"
    else ok "Ready in the app grid and on Super+Shift+Space (voices: $lang, Qwen3-TTS: $($qwen && echo yes || echo no))"; fi
}
