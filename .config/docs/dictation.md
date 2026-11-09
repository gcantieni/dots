# Dictation (`gc-dictate`)

Linux box only: it relies on PulseAudio (`parec`/`pactl`), X11 key injection and GNOME keybindings.

**`gc-dictate`** — local speech-to-text via `whisper.cpp` (built at
  `~/src/whisper.cpp`, `small.en` model, CPU-only — the box has no discrete GPU).
  Toggle-driven, because tmux can't see key *release* so push-to-talk isn't
  possible: first press records, second press transcribes and delivers. Audio is
  captured as raw PCM with `parec` (a killed recorder can't leave a truncated WAV
  header) and wrapped by `ffmpeg` before transcription. Silero **VAD** is on by
  default — without it whisper reliably invents filler ("you", "Thank you.") out
  of silence. Delivery modes: default bracketed-pastes into the originating pane
  *without* submitting (same `load-buffer`/`paste-buffer -p` path as
  `claude_send.lua`), `--clip` copies to the clipboard, `--stdout` prints (used
  by the nvim binding), `--xpaste` copies *and* synthesizes Ctrl-V into the
  focused window (the GNOME hotkey below). Pushes `@dictate_status` into the status bar while
  recording, mirroring `claude-agents hook`. Overridable via `GC_WHISPER_MODEL`,
  `GC_WHISPER_THREADS` (default 8 — 16 is only ~5% faster), `GC_DICTATE_SOURCE`
  / `GC_DICTATE_SOURCE_MATCH` (see below), `GC_DICTATE_MAX_SECONDS` (default
  300s, a runaway-recording backstop).
  Roughly 7× realtime: ~1.7s for an 11s clip.

  **Which mic it records from.** Not the PulseAudio default — that follows
  whatever was plugged in last, and with several headsets plus a webcam on this
  box it lands on the wrong device often enough to look like dictation is
  broken. `resolve_source` instead picks the first non-monitor source whose name
  matches `GC_DICTATE_SOURCE_MATCH` (default `Logitech_Inc_Logitech_H570e`),
  falling back to the PulseAudio default when that headset isn't connected.
  `GC_DICTATE_SOURCE` overrides both with an exact device name. Re-point it
  after a headset change with `pactl list short sources`.

**Teaching it jargon.** Two files in `~/.config/gc-dictate/`. Both hold
site-specific tool names, so they live in `~/.dots-work`, not the public repo,
and `gc-dictate` runs fine when they are absent.

- **`vocab.txt`** — one term per line, assembled into whisper's *initial
  prompt*. whisper treats that prompt as text preceding the audio, so listing a
  tool name biases decoding toward that spelling. It's a nudge, not a rule.
- **`fixups.txt`** — `<extended-regex><TAB><replacement>`, applied
  case-insensitively to the finished transcript. Use this when a term must
  *always* come out right: prompt biasing is probabilistic, these rules aren't.
  A rule like `\bwidget\s*d(\s*d)*\b → widgetd` is what collapses a daemon name
  that whisper keeps hearing as two words with a stray trailing letter.

Tune either one against real audio without speaking again:

```sh
gc-dictate --redo    # re-transcribe the last recording through current lists
```

Two gotchas, both measured rather than assumed:
- **The prompt carries style, not just vocabulary.** A bare comma-separated list
  makes whisper emit the whole transcript with no capitalization or punctuation
  (`and so my fellow americans ask not…`). Wrapping the terms in a real
  sentence ending in a period leaves output byte-identical to no-prompt. That's
  why `vocab_prompt` builds a "Glossary for this recording: …" sentence instead
  of just joining the lines.
- whisper keeps only ~224 tokens of initial prompt and **silently drops the
  tail**, so a long `vocab.txt` quietly stops helping. Roughly 100 terms is the
  ceiling; `gc-dictate` warns on stderr past 800 characters.

**Dictating outside tmux (browsers).** `Super+V` is a GNOME custom keybinding
running `gc-dictate --xpaste`, so the toggle works from any window — press once,
speak, press again and the transcript is pasted where the cursor is. Feedback is
a `notify-send` toast rather than the tmux status bar, since there's no tmux to
draw into. gsettings lives outside `dots`, so reproduce it on a new box with:

```sh
BASE=org.gnome.settings-daemon.plugins.media-keys.custom-keybinding
P=/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/
# Super+V is toggle-message-tray by default; Super+M keeps that reachable.
gsettings set org.gnome.shell.keybindings toggle-message-tray "['<Super>m']"
gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "['$P']"
gsettings set "$BASE:$P" name 'dictate: toggle record and paste'
gsettings set "$BASE:$P" command '/home/gcantieni/bin/gc-dictate --xpaste'
gsettings set "$BASE:$P" binding '<Super>v'
```

Caveats worth knowing:
- It sends **Ctrl-V**, so it pastes in browsers and GTK/Qt apps but not in a
  terminal, where paste is Ctrl-Shift-V. Use the tmux bindings there.
- The paste goes wherever focus is *when transcription finishes*, ~2s after the
  second press — don't switch windows in between.
- The clipboard is overwritten with the transcript, not restored afterwards.
- Key injection is XTEST via `python3-xlib` (already installed) unless `xdotool`
  is present, in which case that's preferred. Both are X11-only: this breaks
  under Wayland, where no client may synthesize input.
- If nothing pastes, suspect the microphone before the plumbing: a wrong or
  quiet device makes VAD find no speech, so the transcript is empty and the
  paste is a no-op with no error anywhere. Check which device was used and how
  loud it was:
  ```sh
  timeout 3 parec --format=s16le --rate=16000 --channels=1 --raw \
      --device="$(pactl info | sed -n 's/^Default Source: //p')" > /tmp/mic.pcm
  ffmpeg -hide_banner -f s16le -ar 16000 -ac 1 -i /tmp/mic.pcm \
      -af volumedetect -f null /dev/null 2>&1 | grep _volume
  ```
  Speaking normally should give a `max_volume` above roughly −15 dB; a peak down
  near −45 dB is ambient noise and means nothing is reaching the mic.

Rebuilding the engine on a new box (the script is versioned in `dots`, the
~490MB of models and the build tree are not):

```sh
git clone --depth 1 https://github.com/ggml-org/whisper.cpp.git ~/src/whisper.cpp
cd ~/src/whisper.cpp
/usr/bin/cmake -B build -DCMAKE_BUILD_TYPE=Release \
    -DWHISPER_BUILD_TESTS=OFF -DWHISPER_BUILD_SERVER=OFF -DGGML_NATIVE=ON
/usr/bin/cmake --build build -j 20
bash models/download-ggml-model.sh small.en     # ~490MB
bash models/download-vad-model.sh silero-v6.2.0 # ~900KB, see VAD note above
```

Gotchas worth remembering:
- Spell `/usr/bin/cmake` explicitly if another cmake comes first on `PATH`; a
  site-provided one may be broken against this distro.
- No BLAS package is needed; ggml's own AVX2 kernels are used via `GGML_NATIVE`.
  That also means the build is tied to the host CPU — rebuild per machine rather
  than copying `build/`.
- The model download is large enough to look finished when it isn't. A truncated
  file fails at load with `not all tensors loaded ... expected 479, got 323`
  rather than anything mentioning the download — check the size (487,614,201
  bytes for `small.en`) before debugging further.
- Accuracy upgrade path: `download-ggml-model.sh medium.en` and point
  `GC_WHISPER_MODEL` at it. ~3× slower, still comfortably faster than realtime.
