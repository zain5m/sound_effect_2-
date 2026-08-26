import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../ad_request_provider.dart';
import '../ad_units.dart';

class BannerController extends ChangeNotifier {
  BannerAd? _bannerAd;

  bool _isLoaded = false;
  bool _isLoading = false;

  BannerAd? get bannerAd => _bannerAd;

  bool get isLoaded => _isLoaded;

  Future<void> load({AdSize size = AdSize.banner}) async {
    if (_isLoading || _isLoaded) return;

    _isLoading = true;

    final banner = BannerAd(
      adUnitId: AdUnits.banner,
      request: AdRequestProvider.request,
      size: size,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          _bannerAd = ad as BannerAd;

          _isLoaded = true;
          _isLoading = false;

          notifyListeners();
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();

          _bannerAd = null;
          _isLoaded = false;
          _isLoading = false;

          notifyListeners();
        },
      ),
    );

    await banner.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }
}
