# Bolo

![Platform](https://img.shields.io/badge/platform-Android-3DDC84)
![Flutter](https://img.shields.io/badge/Flutter-3.47-02569B)
![License](https://img.shields.io/badge/license-MIT-blue)

**A hands-free voice assistant for English and Hinglish. Speech recognition and speech synthesis run
entirely on the phone; only the reply text comes from a cloud LLM (Groq).**

Built for the IISc Computational Intelligence Lab internship assignment (Round 1).
APK: [latest release](https://github.com/Sanjay-Sunil/Bolo/releases/latest).

## Summary

| Requirement | How Bolo meets it | Measured on the phone |
|---|---|---|
| STT fully on-device | Whisper-Hindi2Hinglish-Swift (whisper.cpp, q8_0) in its own isolate | 0.4 s median after end of turn |
| TTS fully on-device | Piper voices: `hi_IN-priyamvada` for Hinglish, `en_US-lessac` for English | first phrase ready in 0.2 s |
| LLM on the cloud | Groq `qwen/qwen3.8-27b`, streamed, with the user's own free API key | first token 0.43 s median |
| English and Hinglish | One code-switching STT model; replies in the language the user spoke | 20/20 replies in the right language |
| **Latency** | Streaming at every stage; speech starts after the first 3 words of the reply | **2.10 s** median, 2.28 s worst, last spoken word to first reply audio |
| **Transcription accuracy** | Whole-turn decoding with a 10 s window; live WER/CER shown in the app | **WER 10.0%**, CER 7.2% (English 10.5%, Hinglish 9.5%) |
| **Pronunciation (Hinglish)** | Hinglish replies in Devanagari for the Hindi voice; English words and numbers respelled before synthesis | Hinglish round-trip WER 16.2% |

Phone: Samsung Galaxy M52 5G (Snapdragon 778G, 6 GB RAM, Android 13), release build.

## The four example sentences

The middle column is what the phone transcribed when a person spoke each sentence. The replies are the
current build's answers to each sentence.

| Sentence | Transcribed on the phone | Reply (as shown; spoken in the matching voice) |
|---|---|---|
| What is the weather forecast for Bangalore tomorrow? | Is the weather forecast for bangaar tomorrow? | I don't have live weather data, so check your phone's weather app for tomorrow's forecast. |
| Can you set a reminder for my meeting at 5 PM? | Can you set a reminder for my meeting at 05:00PM? | I can't set reminders, but you can add a 5 PM event in your phone's calendar app. |
| Mujhe kal subah 7 baje ka alarm set karna hai. | Mujhe kal subah 7 baje ka alarm sakkar karna hai. | Main alarm set nahin kar sakti, par phone ki clock app mein 7 baje ka alarm laga lo. *(spoken: मैं अलार्म सेट नहीं कर सकती, पर फ़ोन की क्लॉक ऐप में 7 बजे का अलार्म लगा लो।)* |
| Aaj ka schedule kya hai, aur meri next meeting kab hai? | Aaj ka schedule kya hai aur mere next meeting kab hai? | Mere paas aapki calendar access nahin hai, isliye main agli meeting ka samay nahin bata sakta. *(spoken: मेरे पास आपकी कैलेंडर एक्सेस नहीं है, इसलिए मैं अगली मीटिंग का समय नहीं बता सकता।)* |

Bolo has no device actions or live data by design: the assignment evaluates the voice pipeline, so the
agent answers these requests honestly and suggests what to do instead.

## Screenshots

| Listening | Thinking | Hinglish reply | English reply | History |
|---|---|---|---|---|
| ![Listening](docs/screenshots/listening.png) | ![Thinking](docs/screenshots/thinking.png) | ![Hinglish reply](docs/screenshots/hinglish-reply.png) | ![English reply](docs/screenshots/english-reply.png) | ![History](docs/screenshots/history.png) |

## Contents

- [Results](#results)
- [Features](#features)
- [Install](#install)
- [How it works](#how-it-works)
- [Tech stack](#tech-stack)
- [Model choices](#model-choices)
- [Build from source](#build-from-source)
- [Project structure](#project-structure)
- [Design decisions](#design-decisions)
- [Limitations](#limitations)
- [License](#license)
- [Acknowledgements](#acknowledgements)

## Results

### Latency

Latency is measured from the **last voiced audio frame** to the first sample of reply audio, so the
0.7 s end-of-turn silence is included. In this run, a laptop spoke the four sentences out loud in three
different voices (12 turns) and the phone listened hands-free.

| Stage | Median | Worst |
|---|---|---|
| End of turn (0.7 s silence) | 801 ms | 824 ms |
| Speech recognition, after end of turn | 399 ms | 681 ms |
| LLM first token | 426 ms | 536 ms |
| First token to first audio | 477 ms | 524 ms |
| **Last spoken word to first reply audio** | **2.10 s** | **2.28 s** |
| Typed message to first reply audio | 0.93 s | 1.01 s |

Groq's response time varies between runs by about ±0.2 s on the median.

### Transcription accuracy

| Speaker | English WER / CER | Hinglish WER / CER | Overall WER / CER |
|---|---|---|---|
| A person speaking into the phone | 10.5% / 8.3% | 9.5% / 6.1% | **10.0% / 7.2%** |
| Synthetic voices from a laptop speaker across a desk (24 turns) | 61.4% / 44.3% | 22.2% / 13.8% | 40.8% / 28.9% |

Scoring normalizes numbers before comparing ("saat" = 7, "5PM" = "5 pm"), as Whisper's own evaluation
does; without that step the person's overall WER is 15.0%. The laptop-speaker setup is a much harder,
far-field test, and its synthetic English voices fared worst ("Bangalore" heard as "Bank of order").

### Pronunciation

Measured as round-trip intelligibility: synthesize a reply, transcribe it with the same STT model, and
compare.

| Text | Round-trip WER |
|---|---|
| Hinglish replies in Devanagari (10 replies) | 16.2% |
| Hinglish replies with English words left in Latin script, before respelling | 23.5% |
| The same replies after respelling English words for the Hindi voice | 14.7% |
| English replies (`en_US-lessac`) | 10.0% |

Both voices were also checked by ear on the phone.

## Features

- **Hands-free conversation**: tap once and talk. The turn ends after 0.7 s of silence, the reply is
  spoken, and the mic reopens. Eight seconds of silence ends the conversation; a tap stops it.
- **Streaming end to end**: live transcript while you speak, the reply streamed token by token, and
  speech starting after the first 3 words while the rest is still being generated.
- **Live visuals**: frequency bars follow your voice (mint to aqua) and the assistant's (peach to coral);
  while it thinks, a sweep of light runs across them. The reply text appears word by word, in time with
  the audio.
- **Readable Hinglish**: replies are spoken from Devanagari but shown in Roman Hinglish.
- **Live metrics**: under every reply, the latency breakdown (end of turn, STT, LLM, TTS, total), STT
  confidence, and WER/CER when the words match one of the four example sentences. Scroll down for the
  history with the same numbers per turn.
- **Typing fallback**, and short messages for no internet, a rejected key, rate limits and stalled
  replies (a stalled reply is retried once).

## Install

1. Download `bolo-v1.0.0-arm64.apk` from the [latest release](https://github.com/Sanjay-Sunil/Bolo/releases/latest)
   and open it on an arm64 Android phone (Android 8.0+). The APK is about 49 MB.
2. On first launch the app downloads 126 MB of models (speech recognition, voice activity, two voices),
   checks each file's SHA-256, and works offline from then on, except for the LLM call.
3. Enter a free Groq API key from [console.groq.com](https://console.groq.com) when asked. It is kept
   in the phone's encrypted storage; long-press **bolo** at the top to change it.
4. Tap the mic and speak in English or Hinglish.

## How it works

```
mic (16 kHz PCM)
  └─▶ VAD isolate ── Silero VAD v5 · segmenter (pauses, end of turn) · FFT bands for the bars
        └─▶ STT isolate ── Whisper-Hindi2Hinglish-Swift (whisper.cpp, q8_0)
              └─▶ main isolate ── Groq chat completion (streamed) ─▶ phrase splitter
                    └─▶ TTS isolate ── text normalizer · Piper (hi_IN / en_US) · FFT bands
                          └─▶ gapless PCM playback, reply text revealed in sync
```

Each model runs in its own Dart isolate, so inference never blocks the UI.

1. **Listening.** Silero VAD marks speech in every 32 ms window. The segmenter turns that into speech
   start, short pauses (200 ms) and end of turn (700 ms).
2. **Transcribing.** About every 0.7 s the whole turn so far is re-transcribed for the live text. At each
   short pause an early final transcription starts. If no more speech follows, it is already the final
   transcript when the turn ends, which hides most of the STT time.
3. **Replying.** The transcript goes to Groq with a short system prompt and four example exchanges. The
   reply streams back and is cut into phrases: the first after 3 words or at a comma, later ones at
   punctuation.
4. **Speaking.** Each phrase is normalized (numbers, symbols, English words in Hindi text), synthesized
   by the voice that matches its script, and queued for gapless playback. Phrase n+1 is synthesized
   while phrase n plays.

The Groq connection is opened as soon as you start speaking, and the STT and TTS models are warmed up
at launch, so the first turn is as fast as the rest.

## Tech stack

| Part | Choice |
|---|---|
| App | Flutter 3.47 (Dart), Riverpod |
| Voice activity | Silero VAD v5 via sherpa-onnx |
| Speech recognition | [Whisper-Hindi2Hinglish-Swift](https://huggingface.co/Oriserve/Whisper-Hindi2Hinglish-Swift), whisper.cpp v1.9.5, q8_0, via a C wrapper and Dart FFI |
| LLM | Groq `qwen/qwen3.8-27b`, OpenAI-compatible streaming API |
| Speech synthesis | Piper `hi_IN-priyamvada-medium` and `en_US-lessac-medium` (int8) via sherpa-onnx |
| Audio | `record` (mic, 16 kHz), `flutter_pcm_sound` (playback, 22.05 kHz) |
| Key storage | `flutter_secure_storage` |

## Model choices

Every option was measured on the demo phone before choosing (4 inference threads).

**Speech recognition** (decode time for a 2 to 4 s clip):

| Runtime | Decode | RAM |
|---|---|---|
| whisper.cpp q5_1, 30 s window | ~2.8 s | +99 MB |
| whisper.cpp q8_0, 30 s window | ~2.0 s | +118 MB |
| **whisper.cpp q8_0, 10 s window (used)** | **0.58 to 0.72 s** | +118 MB |

**Speech synthesis:**

| Voice | First phrase | Real-time factor | RAM | Round-trip WER |
|---|---|---|---|---|
| Kokoro-82M int8, Hindi | 1.89 s | 1.55 | +277 MB | 15.4% |
| Kokoro-82M fp32, Hindi | 1.28 s | 1.03 | +454 MB | 15.4% |
| **Piper hi_IN-priyamvada int8 (used)** | **0.20 s** | **0.29** | +19 MB | 17.9% |
| **Piper en_US-lessac int8 (used)** | **0.23 s** | **0.26** | +40 MB | 10.0% |

A real-time factor above 1 means synthesis is slower than playback, so Kokoro would stall between phrases.

**LLM** (21 English and Hinglish questions, including noisy transcripts):

| Model | Right language and script | First token, median / p90 |
|---|---|---|
| **qwen/qwen3.8-27b (used)** | **20/20** answered | **334 / 588 ms** |
| openai/gpt-oss-120b | 19/21, once leaked its reasoning into the reply | 639 / 950 ms |
| openai/gpt-oss-20b | 16/20 | 903 / 2002 ms |

All measurements and experiments: [`tools/bench/results.md`](tools/bench/results.md).

## Build from source

Prerequisites: Flutter 3.47+, Android SDK with NDK and CMake 3.22, an arm64 Android phone (Android 8.0+)
with USB debugging, and a Groq API key.

```bash
git clone --recursive https://github.com/Sanjay-Sunil/Bolo.git
cd Bolo
cp .env.example .env    # optional: put your key in GROQ_API_KEY to skip the in-app prompt
flutter pub get
flutter run --release --dart-define-from-file=.env
```

`--recursive` fetches whisper.cpp, which the Gradle build compiles from source. `.env` is git-ignored.

```bash
flutter analyze
flutter test    # 155 unit tests
```

The tests cover the segmenter, transcriber scheduling, SSE parsing, the LLM client, phrase splitting,
text normalization, loanwords, Roman Hinglish, WER/CER and the frequency bands.

`tools/convert_swift_ggml.sh` converts the Hugging Face checkpoint to whisper.cpp ggml (f16, q5_1,
q8_0). The app downloads the published q8_0 file from the
[`models-v1`](https://github.com/Sanjay-Sunil/Bolo/releases/tag/models-v1) release.

## Project structure

```
lib/
  app/           model download (ModelManager), clock, thread budget
  audio/         gapless PCM player, FFT band levels for the visualizer
  conversation/  hands-free state machine (ConversationController) and its view models
  llm/           streaming Groq client, SSE parser, system prompt and examples, API key store
  pipeline/      latency metrics, WER/CER, the four example sentences
  stt/           whisper.cpp FFI engine, STT isolate, whole-turn transcriber
  text/          Devanagari to Roman Hinglish for display
  tts/           Piper engine, TTS isolate, phrase splitter, text normalizer, loanwords, numbers
  ui/            main screen, frequency bars, reply text, key sheet, palette
  vad/           Silero detector, segmenter, VAD isolate
  spike/         on-phone test screens used to choose the runtimes and voices
native/          C wrapper around whisper.cpp (prompt, token probabilities, audio window)
third_party/     whisper.cpp v1.9.5 (git submodule)
tools/           model conversion script, benchmark results
docs/            screenshots
```

## Design decisions

- **One code-switching STT model.** Routing between separate Hindi and English engines garbles mixed
  sentences. Swift writes Hinglish in Roman script and English as English.
- **A 10 s minimum encoder window.** Whisper normally pads audio to 30 s; a 10 s window decodes about 3x
  faster. Below about 500 frames Hinglish breaks: "Aaj ka schedule kya hai?" became "Hello.".
- **Whole-turn transcription.** With a 10 s window, decoding the whole turn costs the same as decoding a
  short piece, and it is more accurate than stitching pieces together.
- **Piper over Kokoro.** Kokoro sounds good but runs slower than real time on this phone. Piper is about
  4x faster with the same intelligibility.
- **Hinglish replies in Devanagari.** The Hindi voice only knows Hindi phonemes, so the LLM writes
  Hinglish entirely in Devanagari. About 160 common English words left in Latin script ("meeting",
  "schedule") are respelled before synthesis.
- **Numbers written by code.** The LLM writes digits, and the text normalizer turns them into Hindi or
  English words (7:30 → साढ़े सात). Models often get Hindi number words wrong.
- **No Whisper prompt.** Context prompts and word lists did not lower WER on recorded turns.
- **Mic closed while speaking**, so the assistant never hears itself.

## Limitations

- Groq's response time is the least predictable stage, and its free tier rate-limits bursts of requests.
- STT mishears some names, especially at a distance ("Bangalore" as "bangaar").
- No barge-in: tap to stop the assistant while it speaks.
- No device actions (alarms, reminders, calendar) or live data such as weather.
- Android arm64 only.

## License

[MIT](LICENSE) for this project's code. The models and libraries keep their own licenses.

## Acknowledgements

- [Whisper-Hindi2Hinglish-Swift](https://huggingface.co/Oriserve/Whisper-Hindi2Hinglish-Swift) by
  Oriserve (Apache-2.0), converted to ggml for this app
- [whisper.cpp](https://github.com/ggml-org/whisper.cpp) (MIT)
- [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) (Apache-2.0), for Silero VAD and Piper inference
- [Silero VAD](https://github.com/snakers4/silero-vad) (MIT)
- [Piper](https://github.com/rhasspy/piper) voices `hi_IN-priyamvada-medium` and `en_US-lessac-medium`;
  see each voice's model card for its dataset license
- [Groq](https://groq.com) for the LLM API
- [Inter](https://rsms.me/inter/) typeface (SIL Open Font License, `assets/fonts/OFL-Inter.txt`)
