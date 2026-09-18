import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdManager {
  AdManager._();

  static final AdManager instance = AdManager._();

  bool _initialized = false;
  Future<void>? _initialization;

  bool get isInitialized => _initialized;

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    try {
      await MobileAds.instance.initialize();
      _initialized = true;
    } catch (_) {
      _initialization = null;
      rethrow;
    }
  }
}
