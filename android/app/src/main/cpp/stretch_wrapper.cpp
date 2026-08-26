#include "stretch_wrapper.h"

#include <algorithm>
#include <cmath>
#include <vector>

#include "signalsmith-stretch/signalsmith-stretch.h"  // vendored under native/signalsmith/

namespace {

// Deinterleaved planar buffer, the layout Signalsmith Stretch expects.
class PlanarBuffer {
 public:
  PlanarBuffer(int channels, int frames)
      : data_(channels, std::vector<float>(frames, 0.0f)) {}

  float* operator[](int channel) { return data_[channel].data(); }
  const float* operator[](int channel) const { return data_[channel].data(); }

 private:
  std::vector<std::vector<float>> data_;
};

constexpr float kDefaultTonalityLimitHz = 8000.0f;

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
  return stretch_process_ex(
      processor, input, inputFrames, output, outputFrames, speed,
      pitchSemitones, kDefaultTonalityLimitHz, 1, 0.0f);
}

extern "C" int stretch_process_ex(
    StretchProcessor* processor,
    const float* input,
    int inputFrames,
    float* output,
    int outputFrames,
    float speed,
    float pitchSemitones,
    float tonalityLimitHz,
    int preserveFormants,
    float formantBaseHz) {
  if (processor == nullptr) return -1;
  if (input == nullptr || output == nullptr) return -2;
  if (inputFrames <= 0 || outputFrames <= 0) return -3;
  if (!(speed > 0.0f) || speed < 0.25f || speed > 4.0f) return -4;
  if (!std::isfinite(pitchSemitones) || pitchSemitones < -24.0f || pitchSemitones > 24.0f) {
    return -5;
  }

  const int channels = processor->channels;
  const float sampleRate = static_cast<float>(processor->sampleRate);
  auto& stretch = processor->stretch;

  // Exact offline rendering avoids state leakage between independently exported segments.
  stretch.reset();

  // Without a tonality limit every partial is scaled, which smears the timbre
  // (the classic "underwater" pitch-shift sound). Above the limit the spectrum is
  // shifted linearly instead, keeping transients and sibilance crisp.
  float tonalityLimit = 0.0f;
  if (std::isfinite(tonalityLimitHz) && tonalityLimitHz > 0.0f) {
    tonalityLimit = std::min(tonalityLimitHz, sampleRate * 0.5f) / sampleRate;
  }
  stretch.setTransposeSemitones(pitchSemitones, tonalityLimit);

  if (preserveFormants != 0 && pitchSemitones != 0.0f) {
    // Keep the original formants while the pitch moves, so voices stay natural.
    stretch.setFormantFactor(1.0f, true);
    stretch.setFormantBase(
        std::isfinite(formantBaseHz) && formantBaseHz > 0.0f ? formantBaseHz : 0.0f);
  } else {
    stretch.setFormantFactor(1.0f, false);
    stretch.setFormantBase(0.0f);
  }

  // `exact()` needs enough input to build its pre-roll, otherwise it gives up and
  // returns silence. Padding short clips with silence keeps them renderable, and
  // the padding is trimmed back off afterwards.
  const double rate = static_cast<double>(inputFrames) / static_cast<double>(outputFrames);
  const int requiredFrames = stretch.outputSeekLength(static_cast<float>(rate));
  int padFrames = 0;
  if (inputFrames <= requiredFrames) {
    padFrames = (requiredFrames - inputFrames) / 2 + stretch.seekLength();
  }

  const int paddedInputFrames = inputFrames + 2 * padFrames;
  const int outputOffset = static_cast<int>(std::lround(padFrames / rate));
  const int paddedOutputFrames = outputFrames + 2 * outputOffset;

  PlanarBuffer inputBuffer(channels, paddedInputFrames);
  PlanarBuffer outputBuffer(channels, paddedOutputFrames);

  for (int channel = 0; channel < channels; ++channel) {
    float* dst = inputBuffer[channel] + padFrames;
    for (int frame = 0; frame < inputFrames; ++frame) {
      dst[frame] = input[frame * channels + channel];
    }
  }

  if (!stretch.exact(inputBuffer, paddedInputFrames, outputBuffer, paddedOutputFrames)) {
    return -6;
  }

  for (int channel = 0; channel < channels; ++channel) {
    const float* src = outputBuffer[channel] + outputOffset;
    for (int frame = 0; frame < outputFrames; ++frame) {
      output[frame * channels + channel] = src[frame];
    }
  }
  return 0;
}
