# Bolo

A hands-free voice assistant for Android that understands **English and Hinglish**.
Speech recognition and speech synthesis run **entirely on the phone**; only the reply text comes from a
cloud LLM (Groq). Replies are spoken in the language you used: English in an English voice, Hinglish in a
Hindi voice.

Built for the IISc Computational Intelligence Lab internship assignment (Round 1). Scored on end-to-end
latency, transcription accuracy and pronunciation, especially for Hinglish.

## What it does

- Tap once and talk. The turn ends by itself after 0.7 s of silence, the reply is spoken, and the mic
  reopens for the next turn. Eight seconds of silence ends the conversation; a tap stops it at any time.
- A frequency-bar visualizer follows your voice while you speak (mint to aqua) and the assistant's voice
  while it answers (peach to coral).
- Your words appear live under the bars while you are still speaking.
- The reply is revealed word by word in time with the audio. Hinglish replies are spoken from Devanagari
  but shown in Roman Hinglish ("Theek hai, aapki meeting 5 baje hai.").
- Under every reply: the latency breakdown and, when what you said matches one of the four assignment
  sentences, its **WER and CER** against that sentence, plus STT confidence. Scroll down for the
  conversation history with the same numbers per turn.
- A keyboard button lets you type instead of speaking.
- Without internet, speech recognition and synthesis keep working, and the app says plainly that replies
  need Groq. Rejected keys, rate limits and stalled replies get their own short messages; a stalled reply
  is retried once.

## How it works

```
mic (16 kHz PCM)
  └─▶ VAD isolate ── Silero VAD v5 · segmenter (pauses, end of turn) · FFT bands for the bars
        └─▶ STT isolate ── Whisper-Hindi2Hinglish-Swift (whisper.cpp, q8_0)
              └─▶ main isolate ── Groq chat completion (streamed) ─▶ phrase splitter
                    └─▶ TTS isolate ── text normalizer · Piper (hi_IN / en_US) · FFT bands
                          └─▶ gapless PCM playback, text revealed in sync
```

Four isolates keep inference off the UI thread: VAD, STT and TTS each own their model, and the main isolate
handles the mic, the speaker, the LLM stream and the UI.

**Streaming, end to end.**

- **STT:** while you speak, the whole turn so far is re-transcribed about every 0.7 s for the live text.
  At every short pause (200 ms) an "early final" transcription starts. If you then stay silent until the
  turn ends, that result is already the final transcript, so most of the STT time hides inside the
  end-of-turn wait.
- **LLM:** the reply streams token by token. The first phrase (3 words, or up to the first comma) goes to
  the TTS isolate while the rest is still arriving.
- **TTS:** phrase n+1 is synthesized while phrase n plays, and phrases are queued back to back with no
  gaps.

**Latency is measured honestly**: from the last voiced audio frame (not from the end-of-turn event) to the
first sample of reply audio, so the 0.7 s silence wait is included.

**Warm start.** The connection to Groq is opened as soon as you start speaking, so the TLS handshake is
not on the critical path. At launch the app runs one silent STT decode and one synthesis per voice, so
the first real turn is not slowed by cold caches.

## Model choices (measured on the demo phone)

Demo phone: Samsung Galaxy M52 5G (Snapdragon 778G, 8 cores, 6 GB RAM, Android 13), release build,
4 inference threads (`clamp(cores / 2, 2, 4)`, safe on mid-range phones).

### Speech recognition: Whisper-Hindi2Hinglish-Swift on whisper.cpp

One code-switching model that writes Hinglish in Roman script and English as English, with no language
detection and no router between two engines (a router garbles mixed sentences). Swift is whisper-base sized
(74M parameters). The larger variants are a little more accurate but far too slow on a phone.

| Runtime / setting | Decode time, 2 to 4 s clip | RAM |
|---|---|---|
| whisper.cpp q5_1, full 30 s window | ~2.8 s | +99 MB |
| whisper.cpp q8_0, full 30 s window | ~2.0 s | +118 MB |
| **whisper.cpp q8_0, 10 s window (chosen)** | **0.58 to 0.72 s** | +118 MB |

q8_0 is faster than q5_1 on this CPU, with the same text. Shrinking the encoder window speeds up decoding,
but Swift's Hinglish output collapses below about 500 frames: at 448 frames "Aaj ka schedule kya hai?"
became "Hello.". So the window never goes below 500 frames (10 s).

### Speech synthesis: Piper (hi_IN-priyamvada, en_US-lessac)

| Engine | First phrase | Real-time factor | RAM | Round-trip WER* |
|---|---|---|---|---|
| Kokoro-82M int8 (hf_alpha) | 1.9 s | 1.55 | +277 MB | 15.4% |
| Kokoro-82M fp32 (hf_alpha) | 1.3 s | 1.03 | +454 MB | 15.4% |
| **Piper hi_IN-priyamvada int8** | **0.2 s** | **0.29** | +19 MB | 17.9% |
| **Piper en_US-lessac int8** | | 0.28 | +40 MB | 10.0% (English) |

\*Round-trip WER: synthesize a sentence, transcribe it with Swift, score against the input. It measures
intelligibility.

Kokoro pronounces Hindi well but is slower than real time on this phone, so a streamed reply would stall
between phrases. Piper is about 4x faster with the same intelligibility, and both voices were approved by
ear. On 10 Hinglish replies, round-trip WER was 16.2% for Piper vs 19.2% for Kokoro.

### LLM: Groq, `qwen/qwen3.8-27b` with four example exchanges

The system prompt is followed by four short example exchanges (two English, two Hinglish), which teach
the language rule better than instructions alone. Tested on 21 English and Hinglish questions, including
noisy transcripts like "bangaar" and "sakkar":

| Model | Right language and script | First token, median / p90 |
|---|---|---|
| **qwen/qwen3.8-27b**, reasoning off | **20/20** answered (1 network timeout) | **334 / 588 ms** |
| openai/gpt-oss-120b, reasoning low | 19/21; once leaked its reasoning into the reply | 639 / 950 ms |
| openai/gpt-oss-20b, reasoning low | 16/20 | 903 / 2002 ms |

`max_tokens` is 100 to keep replies short and spoken-length.

## Hinglish handling

- **Replies in Devanagari.** The system prompt asks for Hinglish replies written entirely in Devanagari,
  including English words (मीटिंग, शेड्यूल), because the Hindi voice only knows Hindi phonemes.
- **Latin words are respelled before synthesis.** A Latin word left in a Hindi phrase comes out garbled:
  "next meeting" was heard back as "next bite". About 160 common English words, and their plurals, are
  rewritten to their usual Hindi spelling first. On replies containing such words, round-trip WER drops
  from 23.5% to 14.7%.
- **Numbers are spelled by code, not the model.** The LLM writes digits, and the text normalizer turns
  them into words in the phrase's language: 7:30 → साढ़े सात, 28°C → twenty eight degrees Celsius. Models
  tend to get Hindi number words wrong.
- **Display text is Roman Hinglish.** The on-screen reply is converted back from Devanagari: English
  loanwords return to their English spelling (मीटिंग → meeting), and other words are transliterated with
  Hindi schwa deletion (करना → karna, not "karanaa").

## Measured end to end

**Current build, automated run.** The laptop plays the four assignment sentences out loud (three
different synthetic speakers, 12 turns) and the phone listens hands-free, exactly as with a person.
Times in ms, from the last voiced frame to the first sample of reply audio:

| Stage | Median | Worst |
|---|---|---|
| End of turn (0.7 s silence) | 801 | 824 |
| STT after end of turn | 399 | 681 |
| LLM first token (Groq qwen3.8-27b) | 426 | 536 |
| TTS, first token to first audio | 477 | 524 |
| **Total** | **2104** | **2276** |

Over this laptop-speaker-to-phone-mic path, STT WER was 37.5% to 44.2% (CER 26% to 32%) across runs of the
same clips; the air path is far harsher than speaking into the phone. Numbers are normalized before
scoring ("saat" = 7, "5PM" = "5 pm"), as Whisper's own evaluation does.

**Earlier live session with a person speaking** (build with gpt-oss-120b), the four sentences, ms:

| # | Heard by STT | End of turn | STT | LLM first token | TTS | **Total** |
|---|---|---|---|---|---|---|
| 1 | Is the weather forecast for bangaar tomorrow? | 805 | 246 | 2411 | 443 | 3906 |
| 2 | Can you set a reminder for my meeting at 05:00PM? | 782 | 785 | 2638 | 331 | 4537 |
| 3 | Mujhe kal subah 7 baje ka alarm sakkar karna hai. | 822 | 554 | 871 | 438 | 2686 |
| 4 | Aaj ka schedule kya hai aur mere next meeting kab hai? | 787 | 607 | 1669 | 448 | 3511 |

STT word error rate on these sentences, spoken by a person: **15%** (6 of 40 words; two of the errors are
"05:00PM" vs "5 PM").
Everything except the LLM adds up to about 1.5 s; Groq's time to first token varied from 0.9 to 2.6 s
during this session, which is why the model was then switched to qwen3.8-27b (about half the first-token
time in testing). Free-speech turns in a later session took 1.75 to 2.5 s; typed turns, which skip the
silence wait and STT, take 1.2 to 1.4 s to first audio.

We also tried giving Whisper a context prompt. Generic Hinglish sentences or an English word list did not
lower WER on the recorded turns, so the app decodes without a prompt. Details and all other numbers:
[`tools/bench/results.md`](tools/bench/results.md).

## Build and run

Requirements: Flutter 3.47+, Android SDK with NDK and CMake 3.22, an arm64 Android phone (Android 8+).

```bash
git clone --recursive https://github.com/Sanjay-Sunil/Bolo.git
cd Bolo
cp .env.example .env          # then put your Groq key in GROQ_API_KEY
flutter pub get
flutter run --release --dart-define-from-file=.env
```

On first launch the app downloads 126 MB of models and checks each file's SHA-256: Silero VAD and the
two Piper voices from the sherpa-onnx releases, and the converted Swift model from this repo's
[`models-v1`](https://github.com/Sanjay-Sunil/Bolo/releases/tag/models-v1) release. After that it works
offline except for the LLM call. The key is compiled in from `.env`, which is git-ignored and never
committed.

`tools/convert_swift_ggml.sh` rebuilds the Swift ggml files (f16, q5_1, q8_0) from the Hugging Face
checkpoint.

```bash
flutter analyze
flutter test        # 152 unit tests: segmenter, transcriber scheduling, SSE parser, phrase splitter,
                    # text normalizer, loanwords, Roman Hinglish, WER, band levels, LLM client, ...
```

## Project layout

```
lib/
  app/           model download (ModelManager), clock, thread budget
  audio/         gapless PCM player, FFT band levels for the visualizer
  conversation/  hands-free state machine (ConversationController) and its view models
  llm/           streaming Groq/OpenAI-compatible client, SSE parser, system prompt
  stt/           whisper.cpp FFI engine, STT isolate, whole-turn transcriber
  tts/           Piper engine, TTS isolate, phrase splitter, text normalizer, loanwords, number words
  text/          Devanagari to Roman Hinglish for display
  vad/           Silero detector, segmenter, VAD isolate
  pipeline/      per-turn latency metrics, WER/CER, the four test sentences
  ui/            main screen, visualizer, reply reveal, palette
  spike/         on-phone test screens used to choose the runtimes and voices
native/          C wrapper around whisper.cpp (prompt, token probabilities, audio window)
third_party/     whisper.cpp v1.9.5 (submodule)
tools/           model conversion script, benchmark results
```

## Limitations

- Groq's time to first token is the least predictable stage, and the free tier rate-limits bursts of
  requests.
- STT mishears some proper nouns and phrases ("Bangalore" as "bangaar").
- No barge-in: the mic is closed while the assistant speaks, to avoid hearing itself. Tap to stop.
- The app cannot set alarms or read calendars (no device actions, by design); it says so and suggests what
  to do.
- Tested on Android (arm64) only. The LLM provider and key are set at build time; there is no settings
  screen.

## Credits and licenses

- [Whisper-Hindi2Hinglish-Swift](https://huggingface.co/Oriserve/Whisper-Hindi2Hinglish-Swift) by Oriserve
  (Apache-2.0), converted to ggml for this app.
- [whisper.cpp](https://github.com/ggml-org/whisper.cpp) (MIT).
- [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) (Apache-2.0) for Silero VAD and Piper inference.
- [Silero VAD](https://github.com/snakers4/silero-vad) (MIT).
- [Piper](https://github.com/rhasspy/piper) voices `hi_IN-priyamvada-medium` and `en_US-lessac-medium`;
  see each voice's model card for its dataset license.
- [Inter](https://rsms.me/inter/) font (SIL Open Font License, `assets/fonts/OFL-Inter.txt`).
