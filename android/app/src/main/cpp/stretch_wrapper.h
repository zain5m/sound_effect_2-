#pragma once

#ifdef __cplusplus
extern "C" {
#endif

typedef struct StretchProcessor StretchProcessor;

int stretch_test_connection(void);
StretchProcessor* stretch_create(int channels, int sampleRate);
void stretch_destroy(StretchProcessor* processor);
int stretch_reset(StretchProcessor* processor);

// Offline render. outputFrames defines the exact requested output duration.
int stretch_process(
    StretchProcessor* processor,
    const float* input,
    int inputFrames,
    float* output,
    int outputFrames,
    float speed,
    float pitchSemitones
);

#ifdef __cplusplus
}
#endif
