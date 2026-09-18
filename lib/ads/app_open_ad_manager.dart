import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:sound_effect_2/ads/ad_units.dart';
import 'package:sound_effect_2/main.dart';

class AppLifecycleReactor {
  final AppOpenAdManager appOpenAdManager;
  StreamSubscription<AppState>? _subscription;
  Future<void>? _listening;
  bool _disposed = false;

  AppLifecycleReactor({required this.appOpenAdManager});

  Future<void> listenToAppStateChanges() => _listening ??= _startListening();

  Future<void> _startListening() async {
    if (_disposed) return;
    await AppStateEventNotifier.startListening();
    if (_disposed) return;
    _subscription = AppStateEventNotifier.appStateStream.listen(
      appOpenAdManager.onAppStateChanged,
      onError: (Object error) {
        Dev.console(['App state listener failed: $error']);
      },
    );

    // The initial foreground event may have happened before we subscribed.
    final state = WidgetsBinding.instance.lifecycleState;
    appOpenAdManager.onAppStateChanged(
      state == AppLifecycleState.resumed || state == AppLifecycleState.inactive
          ? AppState.foreground
          : AppState.background,
    );
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      await _listening;
    } catch (error) {
      Dev.console(['App state listener startup failed: $error']);
    }
    try {
      if (_listening != null) await AppStateEventNotifier.stopListening();
    } catch (error) {
      Dev.console(['App state listener cleanup failed: $error']);
    }
    try {
      await _subscription?.cancel();
    } catch (error) {
      Dev.console(['App state subscription cleanup failed: $error']);
    }
  }
}

class AppOpenAdManager {
  final Duration maxCacheDuration = const Duration(hours: 4);

  DateTime? _appOpenLoadTime;
  AppOpenAd? _appOpenAd;
  Timer? _retryTimer;
  bool _isLoadingAd = false;
  bool _isShowingAd = false;
  bool _isForeground = false;
  bool _showWhenLoaded = false;
  bool _skipNextForeground = false;
  int _adSuppressionCount = 0;
  bool _disposed = false;

  Future<T> runWithoutAppOpenAd<T>(Future<T> Function() action) async {
    _adSuppressionCount++;
    // Cancel any pending cold-start display while the user picks a file.
    _showWhenLoaded = false;
    try {
      return await action();
    } finally {
      _adSuppressionCount--;
    }
  }

  bool get isAdAvailable {
    final loadedAt = _appOpenLoadTime;
    if (_appOpenAd == null || loadedAt == null) return false;
    final age = DateTime.now().difference(loadedAt);
    return !age.isNegative && age < maxCacheDuration;
  }

  void onAppStateChanged(AppState state) {
    if (_disposed) return;
    final isForeground = state == AppState.foreground;
    if (!isForeground) {
      // Keep this until foreground arrives, even if the picker finishes first.
      _skipNextForeground =
          _skipNextForeground || _isShowingAd || _adSuppressionCount > 0;
    }
    if (_isForeground == isForeground) return;
    _isForeground = isForeground;
    Dev.console(['New AppState state: $state']);
    if (!isForeground) {
      _showWhenLoaded = false;
      _retryTimer?.cancel();
    } else if (_skipNextForeground || _adSuppressionCount > 0) {
      _skipNextForeground = false;
      unawaited(loadAd());
    } else {
      unawaited(showAdIfAvailable());
    }
  }

  Future<void> loadAd() async {
    if (_disposed || _isLoadingAd || _isShowingAd || isAdAvailable) return;
    _isLoadingAd = true;
    _retryTimer?.cancel();

    final previousAd = _appOpenAd;
    _appOpenAd = null;
    _appOpenLoadTime = null;
    if (previousAd != null) unawaited(_disposeAd(previousAd));

    try {
      await AppOpenAd.load(
        adUnitId: AdUnits.openApp,
        request: AdRepository.getAdRequest(),
        adLoadCallback: AppOpenAdLoadCallback(
          onAdLoaded: (ad) {
            _isLoadingAd = false;
            if (_disposed) {
              unawaited(_disposeAd(ad));
              return;
            }
            Dev.console(['$ad loadAd']);
            _appOpenLoadTime = DateTime.now();
            _appOpenAd = ad;
            if (_showWhenLoaded && _isForeground) {
              unawaited(showAdIfAvailable());
            }
          },
          onAdFailedToLoad: _onLoadFailed,
        ),
      );
    } catch (error) {
      _onLoadFailed(error);
    }
  }

  void _onLoadFailed(Object error) {
    if (_disposed) return;
    _isLoadingAd = false;
    // A delayed retry only replenishes the cache; it must not interrupt use.
    _showWhenLoaded = false;
    Dev.console(['AppOpenAd failed to load: $error']);
    _retryTimer?.cancel();
    if (_isForeground) {
      _retryTimer = Timer(const Duration(seconds: 30), () {
        unawaited(loadAd());
      });
    }
  }

  Future<void> showAdIfAvailable() async {
    if (_disposed ||
        !_isForeground ||
        _isShowingAd ||
        _adSuppressionCount > 0) {
      return;
    }
    if (!isAdAvailable) {
      // Retain the request so a cold start does not depend on a second event.
      _showWhenLoaded = true;
      unawaited(loadAd());
      return;
    }

    final ad = _appOpenAd;
    if (ad == null) return;
    _showWhenLoaded = false;
    // Lock before show(), since native callbacks arrive asynchronously.
    _isShowingAd = true;
    ad.fullScreenContentCallback = FullScreenContentCallback<AppOpenAd>(
      onAdShowedFullScreenContent: (ad) {
        Dev.console(['$ad onAdShowedFullScreenContent']);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        Dev.console(['$ad onAdFailedToShowFullScreenContent: $error']);
        _finishAd(ad);
      },
      onAdDismissedFullScreenContent: (ad) {
        Dev.console(['$ad onAdDismissedFullScreenContent']);
        _finishAd(ad);
      },
    );
    try {
      await ad.show();
    } catch (error) {
      Dev.console(['AppOpenAd show failed: $error']);
      _finishAd(ad);
    }
  }

  void _finishAd(AppOpenAd ad) {
    if (!identical(_appOpenAd, ad)) return;
    _appOpenAd = null;
    _appOpenLoadTime = null;
    _isShowingAd = false;
    unawaited(_disposeAd(ad));
    unawaited(loadAd());
  }

  Future<void> _disposeAd(AppOpenAd ad) async {
    try {
      await ad.dispose();
    } catch (error) {
      Dev.console(['AppOpenAd disposal failed: $error']);
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _showWhenLoaded = false;
    _retryTimer?.cancel();
    final ad = _appOpenAd;
    _appOpenAd = null;
    _appOpenLoadTime = null;
    if (ad != null) unawaited(_disposeAd(ad));
  }
}
