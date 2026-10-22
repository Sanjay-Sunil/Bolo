# Bench results

Demo phone: Samsung Galaxy M52 5G (Snapdragon 778G, 8 cores, 6 GB), release build, 4 inference threads.

## STT runtime: Whisper-Hindi2Hinglish-Swift on whisper.cpp v1.9.5 (2026-10-22)

Clips recorded on the phone (voice-communication mic source, Silero VAD cut); sentence 4 was cut by VAD into two clips at the comma.
Greedy decoding, `language=en`, single segment, no temperature fallback. Times are `whisper_full` wall time.

| Clip | Length | q5_1 full | q5_1 500 | q8_0 full | q8_0 750 | q8_0 500 |
|---|---|---|---|---|---|---|
| 1 | 3.22 s | 2821 ms | 939 ms | 2025 ms | 943 ms | 649 ms |
| 2 | 3.79 s | 2955 ms | 928 ms | 2002 ms | 1091 ms | 723 ms |
| 3 | 4.31 s | 3159 ms | 950 ms | 2072 ms | 976 ms | 647 ms |
| 4a | 1.91 s | 2725 ms | 876 ms | 1962 ms | 890 ms | 583 ms |
| 4b | 2.29 s | 2773 ms | 846 ms | 2003 ms | 1087 ms | 586 ms |

Window = encoder frames (50 per second of audio; full = 1500 = 30 s).

Load: q5_1 249 ms / +99 MB RSS, q8_0 483 ms / +118 MB RSS.

### Window size vs accuracy (q8_0)

At 500 frames and above the text matches the full window on every clip. At 448 frames or below Hinglish breaks:
clip 3 becomes "Mujhe karn samay se baaji ka laaraansi karna hai.", clip 4a becomes "Hello.", clip 4b loses "Aur mere".
Sizing the window to the clip (~256 to 280 frames) gave "mujhe ek karna hai." for clip 3 on the phone.

### Accuracy (q8_0, 500 frames)

| # | Reference | Hypothesis | WER | CER |
|---|---|---|---|---|
| 1 | What is the weather forecast for Bangalore tomorrow? | What is the vajah focus for baingalor tomorrow? | 37.5% | 23.5% |
| 2 | Can you set a reminder for my meeting at 5 PM? | Can you set your reminder for my meeting at 5PM? | 27.3% | 11.1% |
| 3 | Mujhe kal subah 7 baje ka alarm set karna hai. | Mujhe kal subah shaam baje ka alarm set karna hai. | 10.0% | 11.1% |
| 4 | Aaj ka schedule kya hai, aur meri next meeting kab hai? | Aaj ka schedule kya hai? Aur mere next meeting kab hai? | 9.1% | 1.9% |

Overall WER 20% (8 / 40 words). The same errors appear with the full 30 s window, so they come from the model, not the runtime settings.
"5PM" vs "5 PM" accounts for 2 of the 3 errors in sentence 2.

## TTS: Kokoro-82M vs Piper (2026-10-22)

sherpa-onnx 1.13.8, 4 threads, release build. Hindi text is in Devanagari; sherpa-onnx phonemizes it with espeak-ng Hindi rules
(e.g. `ʈʰˈiːk hɛː, ˌaːpkˌi miʈˈĩɡ ʃˈaːm pˈãnc bˈʌɟeː hɛː`). Kokoro's `lang` option made no difference.
Synth time is the median of 3 runs. Round-trip WER: synthesize, resample to 16 kHz, transcribe with Swift q8_0 (laptop), score
against a romanized reference (4 Hindi / 3 English sentences). This measures intelligibility, not naturalness.

| Engine / voice | Lang | Load | RAM (RSS delta) | First phrase "ठीक है," | 3 s sentence | RTF | Round-trip WER | CER |
|---|---|---|---|---|---|---|---|---|
| Kokoro int8, hf_alpha | hi | 3.1 s | +277 MB | 1885 ms | 4700 ms | ~1.55 | 15.4% | 3.9% |
| Kokoro fp32, hf_alpha | hi | 3.0 s | +454 MB | 1282 ms | 3105 ms | ~1.03 | 15.4% | 4.3% |
| **Piper hi_IN-priyamvada int8** | hi | 3.1 s | +19 MB | **200 ms** | **881 ms** | **~0.29** | 17.9% | 5.3% |
| Kokoro int8, af_heart | en | | | | 3242 ms (2.05 s audio) | ~1.58 | 16.7% | 5.3% |
| Kokoro fp32, af_heart | en | | | | 2212 ms (2.02 s audio) | ~1.10 | 16.7% | 5.3% |
| **Piper en_US-lessac int8** | en | 2.6 s | +40 MB | | 564 ms (2.01 s audio) | ~0.28 | **10.0%** | 2.6% |
| Piper en_US-amy int8 | en | 3.4 s | +20 MB | | 751 ms (2.66 s audio) | ~0.28 | 13.3% | 3.3% |
| Piper en_US-hfc_female int8 | en | 2.9 s | +13 MB | | 636 ms (2.32 s audio) | ~0.27 | 20.0% | 7.3% |

Kokoro needs as long as (or longer than) the audio it produces on this phone, so streamed playback would stall.
Pick: Piper `hi_IN-priyamvada` + Piper `en_US-lessac`, int8, 22.05 kHz.

### Hinglish round-trip (2026-10-22)

13 assistant-style Hinglish replies: 10 written fully in Devanagari (English words in their usual Hindi spelling),
3 with English words left in Latin script. Same round-trip method as above. Piper on the phone: RTF 0.26 to 0.30 for 3 to 5 s sentences.

| Engine | All Devanagari (99 words) | Latin left in (34 words) | Latin left in, after `TextNormalizer` loanwords |
|---|---|---|---|
| Piper hi_IN-priyamvada | 16.2% WER / 6.0% CER | 23.5% / 11.5% | **14.7%** |
| Kokoro fp32 hf_alpha | 19.2% / 9.4% | 20.6% / 11.0% | |

Latin words inside a Hindi phrase are mispronounced by the Hindi voice ("next meeting" -> "next bite", "design team" -> "dishaan tin",
"charger" -> "shaaj"). Common Hindi spellings fix it (नेक्स्ट मीटिंग, डिज़ाइन टीम, चार्जर); invented phonetic spellings don't (स्केजूल).
`lib/tts/loanwords.dart` respells ~170 common words (plus plurals) before synthesis.

## LLM first look (2026-10-22, laptop on home Wi-Fi, not the phone)

System prompt from `lib/llm/prompt.dart`, the 4 test sentences as user text, 2 runs each, `stream: true`, `max_tokens` 100.
"Script OK" = English question answered without Devanagari; Hinglish question answered in Devanagari with no Latin words.
RAM: none on the phone (cloud model).

| Provider / model | Options | First token (median) | Full reply (median) | Script OK |
|---|---|---|---|---|
| Groq qwen/qwen3.8-27b | reasoning_effort none | 246 ms | 329 ms | 7/8 (one Hinglish question answered in English) |
| Groq openai/gpt-oss-120b | reasoning_effort low | 460 ms | 572 ms | 8/8 |
| Groq openai/gpt-oss-20b | reasoning_effort low | 724 ms | 779 ms | 8/8 |
| Gemini gemini-2.5-flash | reasoning_effort none | 946 ms | 1119 ms | 6/6 (1 request failed) |
| Gemini gemini-3.5-flash-lite / flash-lite-latest | default | ~10.2 s | ~10.4 s | 8/8 |
| Gemini gemini-2.5-flash-lite | | n/a | n/a | "no longer available to new users" |

Groq llama-3.3-70b-versatile is not offered to this key. Provisional defaults: Groq qwen3.8-27b, Gemini 2.5 Flash; the Phase 5 benchmark on the phone decides.
