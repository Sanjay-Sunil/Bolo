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
