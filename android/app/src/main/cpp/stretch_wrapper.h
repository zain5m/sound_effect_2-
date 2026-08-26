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

// Offline render with quality controls.
//   tonalityLimitHz    - frequencies above this are shifted linearly instead of
//                        being scaled, which keeps the timbre from smearing when
//                        transposing. <= 0 disables the limit.
//   preserveFormants   - keeps the original formants while transposing, so voices
//                        stay natural instead of turning "chipmunk"/"muddy".
//   formantBaseHz      - fundamental hint for formant analysis, 0 = auto detect.
int stretch_process_ex(
    StretchProcessor* processor,
    const float* input,
    int inputFrames,
    float* output,
    int outputFrames,
    float speed,
    float pitchSemitones,
    float tonalityLimitHz,
    int preserveFormants,
    float formantBaseHz
);

#ifdef __cplusplus
}
#endif
