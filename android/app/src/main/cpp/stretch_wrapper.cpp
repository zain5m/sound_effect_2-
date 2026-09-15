#include "stretch_wrapper.h"

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <memory>
#include <vector>

#ifdef __ANDROID__
#include <jni.h>
#endif

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

extern "C" StretchProcessor* stretch_create(int channels, int sampleRate) try {
  if (channels < 1 || channels > 8 || sampleRate < 8000 || sampleRate > 192000) {
    return nullptr;
  }

  auto processor = std::make_unique<StretchProcessor>();
  processor->channels = channels;
  processor->sampleRate = sampleRate;
  // Full-quality preset. Split computation is not needed for offline export.
  processor->stretch.presetDefault(channels, static_cast<float>(sampleRate), false);
  return processor.release();
} catch (...) {
  return nullptr;
}

extern "C" void stretch_destroy(StretchProcessor* processor) { delete processor; }

extern "C" int stretch_reset(StretchProcessor* processor) {
  if (processor == nullptr) return -1;
  processor->stretch.reset();
  return 0;
}

#ifdef __ANDROID__
namespace {

constexpr int kRenderFrames = 512;

struct RealtimeStretch {
  signalsmith::stretch::SignalsmithStretch<float> stretch;
  PlanarBuffer source;
  PlanarBuffer output;
  const int channels;
  const int sampleRate;
  const int frames;
  int readFrame = 0;
  double fractionalInput = 0;
  double processingPosition = 0;
  double position = 0;
  double speed = 1;
  double pitch = 0;
  double targetSpeed = 1;
  double targetPitch = 0;
  int rampRemaining = 0;
  std::vector<double> positionDelay;
  size_t delayIndex = 0;
  std::array<float, kRenderFrames * 2> interleaved{};

  struct SourceView {
    const RealtimeStretch& owner;
    int offset;
    struct Channel {
      const float* data;
      int length;
      int offset;
      float operator[](int index) const {
        const auto frame = static_cast<int64_t>(offset) + index;
        return frame >= 0 && frame < length ? data[frame] : 0.0f;
      }
    };
    Channel operator[](int channel) const {
      return {owner.source[channel], owner.frames, offset};
    }
  };

  RealtimeStretch(int channelCount, int rate, int frameCount)
      : source(channelCount, frameCount), output(channelCount, kRenderFrames),
        channels(channelCount), sampleRate(rate), frames(frameCount) {
    stretch.presetDefault(channels, static_cast<float>(sampleRate), false);
    stretch.setFormantFactor(1.0f, false);
    positionDelay.resize(stretch.outputLatency());
  }

  void setParameters(double nextSpeed, double nextPitch) {
    if (nextSpeed == targetSpeed && nextPitch == targetPitch) return;
    targetSpeed = nextSpeed;
    targetPitch = nextPitch;
    rampRemaining = std::max(1, sampleRate / 50);
  }

  void seek(int frame) {
    frame = std::clamp(frame, 0, frames);
    speed = targetSpeed;
    pitch = targetPitch;
    rampRemaining = 0;
    stretch.setTransposeSemitones(static_cast<float>(pitch));
    const int preroll = stretch.outputSeekLength(static_cast<float>(speed));
    stretch.outputSeek(SourceView{*this, frame}, preroll);
    readFrame = frame + preroll;
    fractionalInput = stretch.inputLatency() + speed * stretch.outputLatency() - preroll;
    processingPosition = frame + speed * stretch.outputLatency();
    position = frame;
    delayIndex = 0;
    for (size_t i = 0; i < positionDelay.size(); ++i) {
      positionDelay[i] = frame + (i + 1) * speed;
    }
  }

  int render(double* timing) {
    timing[0] = timing[1] = position;
    if (position >= frames) return 0;
    const double oldSpeed = speed;
    if (rampRemaining > 0) {
      const int step = std::min(kRenderFrames, rampRemaining);
      const double fraction = static_cast<double>(step) / rampRemaining;
      speed += (targetSpeed - speed) * fraction;
      pitch += (targetPitch - pitch) * fraction;
      rampRemaining -= step;
    }
    const double blockSpeed = (oldSpeed + speed) * 0.5;
    stretch.setTransposeSemitones(static_cast<float>(pitch));
    const double inputCount = fractionalInput + kRenderFrames * blockSpeed;
    const int inputFrames = static_cast<int>(std::floor(inputCount));
    fractionalInput = inputCount - inputFrames;
    stretch.process(SourceView{*this, readFrame}, inputFrames, output, kRenderFrames);
    readFrame += inputFrames;

    int count = 0;
    for (int i = 0; i < kRenderFrames; ++i) {
      processingPosition += blockSpeed;
      // Parameter timing follows the same synthesis delay as the audio.
      const double nextPosition = positionDelay[delayIndex];
      positionDelay[delayIndex] = processingPosition;
      delayIndex = (delayIndex + 1) % positionDelay.size();
      if (position >= frames) continue;
      for (int c = 0; c < channels; ++c) {
        const float value = output[c][i];
        interleaved[count * channels + c] =
            std::isfinite(value) ? std::clamp(value, -1.0f, 1.0f) : 0.0f;
      }
      ++count;
      position = std::min<double>(frames, nextPosition);
    }
    timing[1] = position;
    return count;
  }
};

void throwAudioError(JNIEnv* env, const char* message) {
  const auto type = env->FindClass("java/lang/IllegalStateException");
  if (type) env->ThrowNew(type, message);
}

}

extern "C" JNIEXPORT jlong JNICALL
Java_com_example_sound_1effect_12_RealtimeAudioPlayer_nativeCreate(
    JNIEnv* env, jobject, jobjectArray channelData, jint sampleRate, jint frames,
    jdouble speed, jdouble pitch) {
  try {
    const int channels = env->GetArrayLength(channelData);
    if (channels < 1 || channels > 2 || frames <= 0 || frames > INT32_MAX / 4 ||
        sampleRate < 8000 || sampleRate > 192000 || !std::isfinite(speed) ||
        speed < 0.5 || speed > 2 || !std::isfinite(pitch) || pitch < -12 || pitch > 12) {
      throwAudioError(env, "Invalid audio format or parameters");
      return 0;
    }
    auto processor = std::make_unique<RealtimeStretch>(channels, sampleRate, frames);
    for (int c = 0; c < channels; ++c) {
      const auto bytes = static_cast<jbyteArray>(env->GetObjectArrayElement(channelData, c));
      if (!bytes || env->GetArrayLength(bytes) != frames * 4) {
        throwAudioError(env, "Invalid PCM channel length");
        return 0;
      }
      env->GetByteArrayRegion(bytes, 0, frames * 4,
                             reinterpret_cast<jbyte*>(processor->source[c]));
      env->DeleteLocalRef(bytes);
      if (env->ExceptionCheck()) return 0;
    }
    processor->setParameters(speed, pitch);
    processor->seek(0);
    return reinterpret_cast<jlong>(processor.release());
  } catch (const std::exception& error) {
    throwAudioError(env, error.what());
    return 0;
  }
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_sound_1effect_12_RealtimeAudioPlayer_nativeDestroy(
    JNIEnv*, jobject, jlong handle) {
  delete reinterpret_cast<RealtimeStretch*>(handle);
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_sound_1effect_12_RealtimeAudioPlayer_nativeSetParameters(
    JNIEnv*, jobject, jlong handle, jdouble speed, jdouble pitch) {
  if (handle && std::isfinite(speed) && speed >= 0.5 && speed <= 2 &&
      std::isfinite(pitch) && pitch >= -12 && pitch <= 12) {
    reinterpret_cast<RealtimeStretch*>(handle)->setParameters(speed, pitch);
  }
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_sound_1effect_12_RealtimeAudioPlayer_nativeSeek(
    JNIEnv* env, jobject, jlong handle, jint frame) {
  try {
    if (handle) reinterpret_cast<RealtimeStretch*>(handle)->seek(frame);
  } catch (const std::exception& error) {
    throwAudioError(env, error.what());
  }
}

extern "C" JNIEXPORT jint JNICALL
Java_com_example_sound_1effect_12_RealtimeAudioPlayer_nativeRender(
    JNIEnv* env, jobject, jlong handle, jfloatArray output, jdoubleArray timing) {
  try {
    auto* processor = reinterpret_cast<RealtimeStretch*>(handle);
    if (!processor) return 0;
    if (env->GetArrayLength(output) < kRenderFrames * processor->channels ||
        env->GetArrayLength(timing) < 2) {
      throwAudioError(env, "Invalid render buffer");
      return 0;
    }
    double positions[2];
    const int count = processor->render(positions);
    env->SetFloatArrayRegion(output, 0, count * processor->channels, processor->interleaved.data());
    env->SetDoubleArrayRegion(timing, 0, 2, positions);
    return count;
  } catch (const std::exception& error) {
    throwAudioError(env, error.what());
    return 0;
  }
}
#endif

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
    float formantBaseHz) try {
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
} catch (...) {
  return -7;
}
