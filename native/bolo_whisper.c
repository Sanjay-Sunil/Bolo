#include <math.h>
#include <stdint.h>
#include <string.h>
#include <time.h>

#include "whisper.h"

#define BW_EXPORT __attribute__((visibility("default"))) __attribute__((used))

static int64_t now_ms(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (int64_t) ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
}

BW_EXPORT void * bw_init(const char * model_path) {
    struct whisper_context_params cparams = whisper_context_default_params();
    cparams.use_gpu = false;
    return whisper_init_from_file_with_params(model_path, cparams);
}

BW_EXPORT void bw_free(void * ctx) {
    if (ctx) whisper_free((struct whisper_context *) ctx);
}

// Decodes 16 kHz mono PCM. Returns 0 on success; writes UTF-8 text into `out`,
// the mean log-probability of text tokens into `avg_logprob`, and wall time into `decode_ms`.
BW_EXPORT int bw_transcribe(void * vctx, const float * pcm, int n_samples, const char * prompt,
                            int n_threads, int audio_ctx, char * out, int out_cap,
                            float * avg_logprob, int * decode_ms) {
    struct whisper_context * ctx = (struct whisper_context *) vctx;
    struct whisper_full_params p = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    p.language = "en";
    p.translate = false;
    p.n_threads = n_threads;
    p.audio_ctx = audio_ctx;
    p.no_context = true;
    p.no_timestamps = true;
    p.single_segment = true;
    p.suppress_blank = true;
    p.temperature = 0.0f;
    p.temperature_inc = 0.0f;  // no fallback re-decodes: they multiply latency
    p.print_progress = false;
    p.print_realtime = false;
    p.print_special = false;
    p.print_timestamps = false;
    p.initial_prompt = (prompt && prompt[0]) ? prompt : NULL;

    const int64_t t0 = now_ms();
    if (whisper_full(ctx, p, pcm, n_samples) != 0) return -1;
    *decode_ms = (int) (now_ms() - t0);

    const whisper_token eot = whisper_token_eot(ctx);
    double sum = 0.0;
    int count = 0;
    size_t len = 0;
    out[0] = '\0';
    const int n_seg = whisper_full_n_segments(ctx);
    for (int s = 0; s < n_seg; s++) {
        const char * text = whisper_full_get_segment_text(ctx, s);
        const size_t tl = strlen(text);
        if (len + tl + 1 < (size_t) out_cap) {
            memcpy(out + len, text, tl);
            len += tl;
            out[len] = '\0';
        }
        const int n_tok = whisper_full_n_tokens(ctx, s);
        for (int t = 0; t < n_tok; t++) {
            if (whisper_full_get_token_id(ctx, s, t) >= eot) continue;
            const float prob = whisper_full_get_token_p(ctx, s, t);
            sum += log(prob > 1e-10f ? prob : 1e-10f);
            count++;
        }
    }
    *avg_logprob = count > 0 ? (float) (sum / count) : 0.0f;
    return 0;
}
