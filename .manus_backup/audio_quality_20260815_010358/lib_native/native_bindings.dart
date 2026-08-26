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

typedef StretchDestroyNative = Void Function(Pointer<Void>);

typedef StretchDestroyDart = void Function(Pointer<Void>);

typedef StretchResetNative = Int32 Function(Pointer<Void>);

typedef StretchResetDart = int Function(Pointer<Void>);

typedef StretchProcessNative =
    Int32 Function(
      Pointer<Void>,
      Pointer<Float>,
      Int32,
      Pointer<Float>,
      Int32,
      Float,
    );

typedef StretchProcessDart =
    int Function(
      Pointer<Void>,
      Pointer<Float>,
      int,
      Pointer<Float>,
      int,
      double,
    );

typedef StretchFlushNative =
    Int32 Function(Pointer<Void>, Pointer<Float>, Int32);

typedef StretchFlushDart = int Function(Pointer<Void>, Pointer<Float>, int);

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

final stretchFlush = nativeLib
    .lookupFunction<StretchFlushNative, StretchFlushDart>('stretch_flush');
