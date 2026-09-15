import 'dart:io';

class AdUnits {
  AdUnits._();

  // =========================
  // Android
  // =========================

  // static const String _androidBanner = 'ca-app-pub-3903841634751211/9136468037';
  static const String _androidBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const String _androidRewarded =
      'ca-app-pub-3940256099942544/5224354917';

  // =========================
  // iOS
  // =========================

  static const String _iosBanner = 'ca-app-pub-3903841634751211/9136468037';
  static const String _iosRewarded = 'ca-app-pub-3903841634751211/5443836274';

  // =========================
  // Banner
  // =========================

  static String get banner {
    if (Platform.isAndroid) return _androidBanner;
    if (Platform.isIOS) return _iosBanner;

    throw UnsupportedError('Unsupported platform');
  }

  // =========================
  // Rewarded
  // =========================

  static String get rewarded {
    if (Platform.isAndroid) return _androidRewarded;
    if (Platform.isIOS) return _iosRewarded;

    throw UnsupportedError('Unsupported platform');
  }
}
