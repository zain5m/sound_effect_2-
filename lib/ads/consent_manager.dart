import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:sound_effect_2/main.dart';

class ConsentManager {
  ConsentManager._();

  static final ConsentManager instance = ConsentManager._();

  bool _canRequestAds = false;
  bool _isInitialized = false;
  bool _isInitializing = false;

  PrivacyOptionsRequirementStatus _privacyOptionsRequirementStatus =
      PrivacyOptionsRequirementStatus.notRequired;

  bool get canRequestAds => _canRequestAds;

  bool get isInitialized => _isInitialized;

  bool get isPrivacyOptionsRequired =>
      _privacyOptionsRequirementStatus ==
      PrivacyOptionsRequirementStatus.required;

  Future<void> initialize({
    bool isDebug = kDebugMode,
    List<String> testDeviceIds = const [],
  }) async {
    Dev.console(['initialize']);
    if (_isInitialized || _isInitializing) return;

    _isInitializing = true;

    try {
      final params = ConsentRequestParameters(
        consentDebugSettings: isDebug
            ? ConsentDebugSettings(
                debugGeography: DebugGeography.debugGeographyEea,
                testIdentifiers: testDeviceIds,
              )
            : null,
      );

      // await _requestConsentInfo(params);
      try {
        await _requestConsentInfo(params);
      } on FormError catch (e) {
        Dev.console(['requestConsentInfoUpdate', e.message]);
        _canRequestAds = true;
        return;
      }
      try {
        await _loadAndShowConsentFormIfRequired();
      } catch (e) {
        Dev.console(['Consent form error: $e']);
      }
      // await _loadAndShowConsentFormIfRequired();

      await _refreshState();

      _isInitialized = true;
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> _requestConsentInfo(ConsentRequestParameters params) {
    final completer = Completer<void>();
    Dev.console(['_requestConsentInfo']);
    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () => completer.complete(),
      (FormError error) {
        Dev.console(['_requestConsentInfo', error.message]);
        completer.completeError(error);
      },
    );

    return completer.future;
  }

  Future<void> _loadAndShowConsentFormIfRequired() {
    final completer = Completer<void>();

    ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
      if (error != null) {
        completer.completeError(error);
        return;
      }

      completer.complete();
    });

    return completer.future;
  }

  Future<void> _refreshState() async {
    _canRequestAds = await ConsentInformation.instance.canRequestAds();

    _privacyOptionsRequirementStatus = await ConsentInformation.instance
        .getPrivacyOptionsRequirementStatus();
  }

  Future<void> showPrivacyOptionsForm() async {
    final completer = Completer<void>();

    ConsentForm.showPrivacyOptionsForm((FormError? error) {
      if (error != null) {
        completer.completeError(error);
        return;
      }

      completer.complete();
    });

    await completer.future;

    await _refreshState();
  }
}
