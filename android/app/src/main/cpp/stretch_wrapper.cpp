#include "stretch_wrapper.h"

#include <cmath>
#include <vector>

#include "signalsmith-stretch/signalsmith-stretch.h"  // vendored under native/signalsmith/

namespace {

class InterleavedInput {
 public:
  InterleavedInput(const float* input, int frames, int channels)
      : channels_(channels), data_(channels, std::vector<float>(frames)) {
    for (int frame = 0; frame < frames; ++frame) {
      for (int channel = 0; channel < channels_; ++channel) {
        data_[channel][frame] = input[frame * channels_ + channel];
      }
    }
  }

  float* operator[](int channel) { return data_[channel].data(); }

 private:
  int channels_;
  std::vector<std::vector<float>> data_;
};

class InterleavedOutput {
 public:
  InterleavedOutput(float* output, int frames, int channels)
      : output_(output), frames_(frames), channels_(channels),
        data_(channels, std::vector<float>(frames, 0.0f)) {}

  float* operator[](int channel) { return data_[channel].data(); }

  void writeBack() {
    for (int frame = 0; frame < frames_; ++frame) {
      for (int channel = 0; channel < channels_; ++channel) {
        output_[frame * channels_ + channel] = data_[channel][frame];
      }
    }
  }

 private:
  float* output_;
  int frames_;
  int channels_;
  std::vector<std::vector<float>> data_;
};

}  // namespace

struct StretchProcessor {
  signalsmith::stretch::SignalsmithStretch<float> stretch;
  int channels = 0;
  int sampleRate = 0;
};

extern "C" int stretch_test_connection() { return 20260815; }

extern "C" StretchProcessor* stretch_create(int channels, int sampleRate) {
  if (channels < 1 || channels > 8 || sampleRate < 8000 || sampleRate > 192000) {
    return nullptr;
  }

  auto* processor = new StretchProcessor();
  processor->channels = channels;
  processor->sampleRate = sampleRate;
  // Full-quality preset. Split computation is not needed for offline export.
  processor->stretch.presetDefault(channels, static_cast<float>(sampleRate), false);
  return processor;
}

extern "C" void stretch_destroy(StretchProcessor* processor) { delete processor; }

extern "C" int stretch_reset(StretchProcessor* processor) {
  if (processor == nullptr) return -1;
  processor->stretch.reset();
  return 0;
}

extern "C" int stretch_process(
    StretchProcessor* processor,
    const float* input,
    int inputFrames,
    float* output,
    int outputFrames,
    float speed,
    float pitchSemitones) {
  if (processor == nullptr) return -1;
  if (input == nullptr || output == nullptr) return -2;
  if (inputFrames <= 0 || outputFrames <= 0) return -3;
  if (!(speed > 0.0f) || speed < 0.25f || speed > 4.0f) return -4;
  if (!std::isfinite(pitchSemitones) || pitchSemitones < -24.0f || pitchSemitones > 24.0f) {
    return -5;
  }

  // Exact offline rendering avoids state leakage between independently exported segments.
  processor->stretch.reset();
  processor->stretch.setTransposeSemitones(pitchSemitones);

  InterleavedInput inputBuffer(input, inputFrames, processor->channels);
  InterleavedOutput outputBuffer(output, outputFrames, processor->channels);
  const bool ok = processor->stretch.exact(
      inputBuffer, inputFrames, outputBuffer, outputFrames);
  if (!ok) return -6;

  outputBuffer.writeBack();
  return 0;
}
