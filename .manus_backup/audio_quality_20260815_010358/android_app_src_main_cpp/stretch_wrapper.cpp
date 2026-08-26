#include "stretch_wrapper.h"
#include "stretch_wrapper.h"

#include "signalsmith/signalsmith-stretch/signalsmith-stretch.h"
#include <vector>

class InterleavedChannelAdapter {
public:
    InterleavedChannelAdapter(
            const float* input,
            int frames,
            int channels
    ) : channels(channels), frames(frames) {

        data.resize(channels);

        for (int ch = 0; ch < channels; ch++) {
            data[ch].resize(frames);

            for (int i = 0; i < frames; i++) {
                data[ch][i] = input[i * channels + ch];
            }
        }
    }

    float* operator[](int channel) {
        return data[channel].data();
    }

private:
    int channels;
    int frames;
    std::vector<std::vector<float>> data;
};

class OutputChannelAdapter {
public:
    OutputChannelAdapter(
            float* output,
            int frames,
            int channels
    ) : output(output), frames(frames), channels(channels) {

        data.resize(channels);

        for (int ch = 0; ch < channels; ch++) {
            data[ch].resize(frames);
        }
    }

    float* operator[](int channel) {
        return data[channel].data();
    }

    void writeBack() {
        for (int i = 0; i < frames; i++) {
            for (int ch = 0; ch < channels; ch++) {
                output[i * channels + ch] = data[ch][i];
            }
        }
    }

private:
    float* output;
    int frames;
    int channels;
    std::vector<std::vector<float>> data;
};
struct StretchProcessor {
    signalsmith::stretch::SignalsmithStretch<float> stretch;

    int channels;
    int sampleRate;
};
int stretch_test_connection() {
    return 2026;
}

StretchProcessor* stretch_create(
        int channels,
        int sampleRate
) {
    auto* processor = new StretchProcessor();

    processor->channels = channels;
    processor->sampleRate = sampleRate;

    processor->stretch.presetDefault(
            channels,
            sampleRate
    );

    return processor;
}

void stretch_destroy(
        StretchProcessor* processor
) {
    delete processor;
}

int stretch_reset(
        StretchProcessor* processor
) {
    if (!processor)
        return -1;

    processor->stretch.reset();

    return 0;
}

int stretch_process(
        StretchProcessor* processor,
        const float* input,
        int inputFrames,
        float* output,
        int outputFrames,
        float speed
) {
    if (!processor)
        return -1;

    if (!input)
        return -2;

    if (!output)
        return -3;

    if (speed <= 0.0f)
        return -4;

    InterleavedChannelAdapter inputBuffer(
            input,
            inputFrames,
            processor->channels
    );

    OutputChannelAdapter outputBuffer(
            output,
            outputFrames,
            processor->channels
    );

    processor->stretch.setTransposeFactor(1.0f);

    processor->stretch.setTempo(1.0f / speed);

    bool ok = processor->stretch.exact(
            inputBuffer,
            inputFrames,
            outputBuffer,
            outputFrames
    );

    if (!ok)
        return -5;

    outputBuffer.writeBack();

    return 0;
}

int stretch_flush(
        StretchProcessor* processor,
        float* output,
        int outputFrames
) {
    if (!processor)
        return -1;

    if (!output)
        return -2;

    OutputChannelAdapter outputBuffer(
            output,
            outputFrames,
            processor->channels
    );

    processor->stretch.flush(
            outputBuffer,
            outputFrames
    );

    outputBuffer.writeBack();

    return 0;
}