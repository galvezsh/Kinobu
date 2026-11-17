# Zen (Kinobu): text-to-speech worker. zen.py starts it once and keeps it running, so each
# engine's model is loaded only once. One JSON request per line on stdin:
#   {"engine": "kokoro"|"piper"|"qwen", "voice": "em_santa", "lang": "es", "text": "...", "out": "/tmp/x.wav"}
# One JSON answer per line on stdout: {"out": path} or {"error": text}.
# Qwen3-TTS runs in llama.cpp's own server (llama-server, Vulkan: any GPU vendor), started on
# first use and stopped with this worker; it clones a reference voice (qwen-ref-<voice>-<lang>.wav,
# or qwen-ref-<voice>.wav when that language has none).
# Usage: zen-tts.py MODELS_DIR LLAMA_DIR   (runs in its own Python environment, see zen.py)
import atexit
import base64
import json
import os
import re
import signal
import socket
import subprocess
import sys
import time
import urllib.request
import wave

import numpy as np
import soundfile as sf

MODELS = sys.argv[1]
LLAMA = sys.argv[2] if len(sys.argv) > 2 else ""
QWEN_MODEL = "qwen3-tts-1.7b-base-Q4_K_M.gguf"
QWEN_MMPROJ = "mmproj-qwen3-tts-1.7b-base-Q8_0.gguf"
DISCRETE = re.compile(r"NVIDIA|GeForce|Radeon RX|Radeon Pro|Arc\b", re.I)
PIPER_VOICES = {"davefx": "es_ES-davefx-medium.onnx", "joe": "en_US-joe-medium.onnx",
                "kristin": "en_US-kristin-medium.onnx"}
KOKORO_LANG = {"es": "es", "en": "en-us", "fr": "fr-fr", "it": "it", "pt": "pt-br"}   # else English
QWEN_LANG = {"zh", "en", "de", "it", "pt", "es", "ja", "ko", "fr", "ru"}
loaded = {}


def kokoro():
    if "kokoro" not in loaded:
        from kokoro_onnx import Kokoro
        loaded["kokoro"] = Kokoro(os.path.join(MODELS, "kokoro-v1.0.onnx"),
                                  os.path.join(MODELS, "voices-v1.0.bin"))
    return loaded["kokoro"]


def piper(voice):
    key = "piper-" + voice
    if key not in loaded:
        from piper import PiperVoice
        loaded[key] = PiperVoice.load(os.path.join(MODELS, PIPER_VOICES[voice]))
    return loaded[key]


def gpu_device():
    """The Vulkan device llama.cpp should use: a dedicated card when there is one."""
    env = {**os.environ, "LD_LIBRARY_PATH": LLAMA}
    out = subprocess.run([os.path.join(LLAMA, "llama-server"), "--list-devices"], env=env,
                         capture_output=True, text=True, timeout=60).stdout
    devices = re.findall(r"^\s+(Vulkan\d+): (.+?) \(", out, re.M)
    for name, label in devices:
        if DISCRETE.search(label):
            return name
    return devices[0][0] if devices else None


class Qwen:
    def __init__(self):
        with socket.socket() as sock:                      # a free local port
            sock.bind(("127.0.0.1", 0))
            self.port = sock.getsockname()[1]
        device = gpu_device()
        args = [os.path.join(LLAMA, "llama-server"), "-m", os.path.join(MODELS, QWEN_MODEL),
                "-mm", os.path.join(MODELS, QWEN_MMPROJ), "--host", "127.0.0.1",
                "--port", str(self.port), "-ngl", "99" if device else "0"]
        if device:
            args += ["--device", device]
        self.proc = subprocess.Popen(args, env={**os.environ, "LD_LIBRARY_PATH": LLAMA},
                                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        atexit.register(self.stop)
        deadline = time.monotonic() + 180
        while time.monotonic() < deadline:                 # wait until the model is loaded
            if self.proc.poll() is not None:
                raise RuntimeError("llama-server stopped while loading")
            try:
                with urllib.request.urlopen(f"http://127.0.0.1:{self.port}/health", timeout=2) as r:
                    if r.status == 200:
                        return
            except OSError:
                pass
            time.sleep(0.5)
        raise RuntimeError("llama-server did not start in time")

    def speak(self, text, voice, lang, out):
        if voice.startswith("my-"):                         # a personal voice (zen.py: PERSONAL)
            ref = os.path.join(os.path.dirname(MODELS), "voices", voice[3:] + ".wav")
        else:
            ref = os.path.join(MODELS, f"qwen-ref-{voice}-{lang}.wav")
            if not os.path.isfile(ref):
                ref = os.path.join(MODELS, f"qwen-ref-{voice}.wav")
        with open(ref, "rb") as f:
            ref = base64.b64encode(f.read()).decode()
        body = json.dumps({"input": text, "lang": lang, "speaker_ref_b64": ref}).encode()
        request = urllib.request.Request(f"http://127.0.0.1:{self.port}/tts", data=body,
                                         headers={"Content-Type": "application/json"})
        with urllib.request.urlopen(request, timeout=120) as r:
            data = r.read()
        with open(out, "wb") as f:
            f.write(data)

    def stop(self):
        if self.proc.poll() is None:
            self.proc.terminate()


def qwen():
    if "qwen" not in loaded:
        engine = Qwen()
        # the first request compiles the GPU kernels (~15 s): pay it now, not on the first answer
        warm = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), f"kinobu-zen-warm-{os.getpid()}.wav")
        try:
            engine.speak("Hola.", "kinobu", "es", warm)
        finally:
            if os.path.exists(warm):
                os.remove(warm)
        loaded["qwen"] = engine
    return loaded["qwen"]


def normalise(path):
    samples, rate = sf.read(path)
    peak = float(np.max(np.abs(samples))) or 1.0
    sf.write(path, samples / peak * 0.89, rate)


def speak(req):
    if req["engine"] == "kokoro":
        samples, rate = kokoro().create(req["text"], voice=req["voice"], speed=req.get("speed", 1.0),
                                        lang=KOKORO_LANG.get(req.get("lang", "en"), "en-us"))
        peak = float(np.max(np.abs(samples))) or 1.0
        sf.write(req["out"], samples / peak * 0.89, rate)       # Kokoro comes out quiet: -1 dBFS
    elif req["engine"] == "qwen":
        lang = req.get("lang", "en")
        qwen().speak(req["text"], req["voice"], lang if lang in QWEN_LANG else "en", req["out"])
        normalise(req["out"])
    elif req["engine"] == "piper":
        with wave.open(req["out"], "wb") as w:
            piper(req["voice"]).synthesize_wav(req["text"], w)
    else:
        raise ValueError(f"unknown engine {req['engine']}")


def main():
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))  # so atexit stops llama-server
    print(json.dumps({"ready": True}), flush=True)
    for line in sys.stdin:
        try:
            req = json.loads(line)
            if req.get("warm"):                                # load the model before the first answer
                {"kokoro": kokoro, "qwen": qwen}.get(req["warm"], lambda: piper(req.get("voice", "davefx")))()
                print(json.dumps({"warm": req["warm"]}), flush=True)
                continue
            speak(req)
            print(json.dumps({"out": req["out"]}), flush=True)
        except Exception as e:                                 # report and keep serving
            print(json.dumps({"error": f"{type(e).__name__}: {e}"}), flush=True)


if __name__ == "__main__":
    main()
