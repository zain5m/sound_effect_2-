import 'package:flutter/foundation.dart';
import 'package:sound_effect_2/ads/ad_manager.dart';
import 'package:sound_effect_2/ads/banner/banner_controller.dart';
import 'package:sound_effect_2/ads/rewarded/rewarded_controller.dart';

class AdsProvider extends ChangeNotifier {
  AdsProvider() {
    bannerController.addListener(notifyListeners);
  }

  final BannerController bannerController = BannerController();

  final RewardedController rewardedController = RewardedController();
  Future<void> initialize() async {
    // await ConsentManager.instance.initialize(
    //   testDeviceIds: ['F2FC25BB08884EF8A68CDB547E8CA3B3'],
    // );
    // if (!ConsentManager.instance.canRequestAds) {
    //   return;
    // }

    await AdManager.instance.initialize();

    bannerController.load();

    rewardedController.load();
  }
}
