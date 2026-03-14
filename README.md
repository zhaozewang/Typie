<p align="center">
  <img src="assets/banner.png" alt="Typie" width="100%" />
</p>

<h1 align="center">Agentic AI is only as fast as you can prompt it.</h1>

<p align="center">
  <strong>Whisper-based, privacy-preserving voice dictation for macOS that boosts your prompts/sec by turning spoken intent into fast, local, on-device text.</strong>
</p>

<h3 align="center">
  <a href="#quick-start">🚀 Quick Start</a>
  &nbsp;&nbsp;&nbsp;
  <a href="#features">🧠 Features</a>
  &nbsp;&nbsp;&nbsp;
  <a href="#privacy">🛡️ Privacy</a>
  &nbsp;&nbsp;&nbsp;
  <a href="#license">📜 License</a>
</h3>

## Features

- **Global hotkey** — trigger dictation from any app
- **Fully local** — on-device transcription with `whisper.cpp`
- **Privacy-preserving** — no audio, text, or telemetry leaves your Mac
- **Built for prompt throughput** — turn spoken intent into fast, usable text
- **Prompt-aware dictation** — adapts to your vocabulary and speaking patterns
- **Clipboard-safe insertion** — inserts into your focused app and restores your clipboard
- **Native menu bar app** — lightweight and always ready

## Quick Start

```bash
make setup-whisper
make run
````

If you prefer manual setup:

```bash
git clone https://github.com/ggerganov/whisper.cpp.git /tmp/whisper.cpp
cd /tmp/whisper.cpp
cmake -B build && cmake --build build --config Release -j
sudo cp build/bin/whisper-cli /usr/local/bin/whisper-cpp
make run
```

On first launch, grant:

* **Microphone** — required to record audio
* **Accessibility** — required to insert text into other apps

## Privacy

* All transcription runs locally on-device
* No audio, text, or telemetry leaves your Mac
* Temporary audio files are deleted after transcription
* No analytics, crash reporting, or remote logging

## License

MIT

## Credits

Built by **Zhaoze Wang**, with **Claude Code** and **OpenAI**.

Powered by [`whisper.cpp`](https://github.com/ggerganov/whisper.cpp).
