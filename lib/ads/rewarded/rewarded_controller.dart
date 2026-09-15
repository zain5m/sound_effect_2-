import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../ad_request_provider.dart';
import '../ad_units.dart';

class RewardedController {
  RewardedAd? _rewardedAd;

  bool _isLoading = false;
  bool _isShowing = false;
  bool _earnedReward = false;

  VoidCallback? _onRewarded;

  bool get isLoaded => _rewardedAd != null;

  Future<void> load() async {
    if (_isLoading || isLoaded) return;

    _isLoading = true;

    await RewardedAd.load(
      adUnitId: AdUnits.rewarded,
      request: AdRequestProvider.request,
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isLoading = false;

          _setCallbacks(ad);
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          _isLoading = false;

          debugPrint('RewardedAd failed to load: $error');
        },
      ),
    );
  }

  Future<bool> show({required VoidCallback onRewarded}) async {
    if (_rewardedAd == null || _isShowing) {
      return false;
    }

    _isShowing = true;
    _earnedReward = false;
    _onRewarded = onRewarded;

    _rewardedAd!.show(
      onUserEarnedReward: (_, __) {
        _earnedReward = true;
      },
    );

    return true;
  }

  void _setCallbacks(RewardedAd ad) {
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        if (_earnedReward) {
          _onRewarded?.call();
        }

        _reset(ad);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('RewardedAd failed to show: $error');

        _reset(ad);
      },
    );
  }

  void _reset(RewardedAd ad) {
    ad.dispose();

    _rewardedAd = null;
    _isShowing = false;
    _earnedReward = false;
    _onRewarded = null;

    load();
  }

  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _onRewarded = null;
  }
}
