import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:sound_effect_2/ads/ads_provider.dart';

class BannerWidget extends StatelessWidget {
  const BannerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Consumer<AdsProvider>(
        builder: (context, ads, _) {
          final banner = ads.bannerController;
          if (!banner.isLoaded || banner.bannerAd == null) {
            return const SizedBox.shrink();
          }

          return SizedBox(
            width: banner.bannerAd!.size.width.toDouble(),
            height: banner.bannerAd!.size.height.toDouble(),
            child: AdWidget(ad: banner.bannerAd!),
          );
        },
      ),
    );
  }
}
