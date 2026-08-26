import 'dart:ffi';
import 'dart:io';

final DynamicLibrary nativeLib = Platform.isAndroid
    ? DynamicLibrary.open('libstretch.so')
    : DynamicLibrary.process();

typedef StretchTestNative = Int32 Function();
typedef StretchTestDart = int Function();

typedef StretchCreateNative =
    Pointer<Void> Function(Int32 channels, Int32 sampleRate);
typedef StretchCreateDart =
    Pointer<Void> Function(int channels, int sampleRate);

typedef StretchDestroyNative = Void Function(Pointer<Void> processor);
typedef StretchDestroyDart = void Function(Pointer<Void> processor);

typedef StretchResetNative = Int32 Function(Pointer<Void> processor);
typedef StretchResetDart = int Function(Pointer<Void> processor);

typedef StretchProcessNative =
    Int32 Function(
      Pointer<Void> processor,
      Pointer<Float> input,
      Int32 inputFrames,
      Pointer<Float> output,
      Int32 outputFrames,
      Float speed,
      Float pitchSemitones,
    );
typedef StretchProcessDart =
    int Function(
      Pointer<Void> processor,
      Pointer<Float> input,
      int inputFrames,
      Pointer<Float> output,
      int outputFrames,
      double speed,
      double pitchSemitones,
    );

final stretchTestConnection = nativeLib
    .lookupFunction<StretchTestNative, StretchTestDart>(
      'stretch_test_connection',
    );
final stretchCreate = nativeLib
    .lookupFunction<StretchCreateNative, StretchCreateDart>('stretch_create');
final stretchDestroy = nativeLib
    .lookupFunction<StretchDestroyNative, StretchDestroyDart>(
      'stretch_destroy',
    );
final stretchReset = nativeLib
    .lookupFunction<StretchResetNative, StretchResetDart>('stretch_reset');
final stretchProcess = nativeLib
    .lookupFunction<StretchProcessNative, StretchProcessDart>(
      'stretch_process',
    );
