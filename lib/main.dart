import 'package:colorize/colorize.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'ads/ads_provider.dart';
import 'l10n/app_localizations.dart';
import 'providers/audio_app_provider.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );
  runApp(const SoundEffectApp());
}

class SoundEffectApp extends StatelessWidget {
  const SoundEffectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AudioAppProvider()),

        ChangeNotifierProvider(create: (_) => AdsProvider()),
      ],
      child: MaterialApp(
        title: 'مقسم المقاطع الصوتية الذكي',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const InitializeScreen(),
      ),
    );
  }
}

////

class InitializeScreen extends StatefulWidget {
  const InitializeScreen({super.key});

  @override
  State<InitializeScreen> createState() => _InitializeScreenState();
}

class _InitializeScreenState extends State<InitializeScreen> {
  @override
  void initState() {
    super.initState();

    _initialize();
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));

  Future<void> _initialize() async {
    await context.read<AdsProvider>().initialize();

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }
}

class Dev {
  Dev._();

  static void hard(List<dynamic> list) {
    if (!kDebugMode) return;

    final callerInfo = _getCallerFileName();
    final Colorize fileInfo = Colorize("Called from: $callerInfo")
      ..apply(Styles.BOLD)
      ..apply(Styles.BLUE);

    _printDivider("START HARD");

    debugPrint(fileInfo.toString());

    for (var element in list) {
      _printElement(element);
    }

    _printDivider("END HARD");
  }

  static void console(List<dynamic> list) {
    if (!kDebugMode) return;

    final callerInfo = _getCallerFileName();
    final Colorize fileInfo = Colorize("Called from: $callerInfo")
      ..apply(Styles.BOLD)
      ..apply(Styles.BLUE);

    _printDivider("START");

    debugPrint(fileInfo.toString());

    for (var element in list) {
      _printElement(element);
    }

    _printDivider("END");
  }

  static void _printElement(dynamic element, [int depth = 0]) {
    final String prefix = " " * (depth * 2);
    if (element is List) {
      for (int i = 0; i < element.length; i++) {
        _printElement(element[i], depth + 1);
      }
    } else {
      debugPrint(
        prefix +
            Colorize("ELEMENT").apply(Styles.RED).bold().italic().initial +
            Colorize(" ==> ").apply(Styles.WHITE).bold().italic().initial +
            Colorize(
              element.toString(),
            ).apply(Styles.GREEN).bold().italic().initial,
      );
    }
  }

  static void _printDivider(String label) {
    debugPrint(
      Colorize(" $label ").bgLightRed().white().bold().italic().initial +
          Colorize(" ==> ").bgLightRed().white().bold().italic().initial +
          Colorize(
            "**********************************",
          ).apply(Styles.BLACK).bgWhite().bold().italic().initial,
    );
  }

  static void observerPrint(dynamic name, dynamic value, [dynamic additional]) {
    if (!kDebugMode) return;

    // Print the main name and value
    _printColoredInfo(name.toString(), value.toString());

    // If additional app_info is provided, process and print it
    if (additional != null) {
      // _printAdditionalInfo(additional);
    }
  }

  static void _printColoredInfo(String name, String value) {
    debugPrint(
      (Colorize(name)
                ..apply(Styles.BLUE)
                ..bgBlack()
                ..bold()
                ..italic()
                ..initial)
              .toString() + // Convert Colorize to string
          (Colorize(" ==> ")
                ..apply(Styles.BLUE)
                ..bgBlack()
                ..bold()
                ..italic()
                ..initial)
              .toString() + // Convert Colorize to string
          (Colorize(value)
                ..apply(Styles.YELLOW)
                ..bgDarkGray()
                ..bold()
                ..italic()
                ..initial)
              .toString(), // Convert Colorize to string
    );
  }

  static void _printAdditionalInfo(dynamic additional) {
    // Assuming the structure contains `currentState` and `nextState` as mentioned in comments
    try {
      final String additionalStr = additional.toString();
      final String currentState = _extractState(additionalStr, 'currentState');
      final String nextState = _extractState(additionalStr, 'nextState');

      // Print extracted states with color coding
      debugPrint(
        (Colorize("currentState :  $currentState")
              ..black()
              ..bold()
              ..italic()
              ..bgLightCyan()
              ..initial)
            .toString(), // Convert Colorize to string
      );
      debugPrint(
        (Colorize("nextState :  $nextState")
              ..black()
              ..bold()
              ..italic()
              ..bgLightCyan()
              ..initial)
            .toString(), // Convert Colorize to string
      );
    } catch (e) {
      debugPrint("Error processing additional app_info: $e");
    }
  }

  static String _extractState(String input, String state) {
    final regex = RegExp('$state : (.*?),');
    final match = regex.firstMatch(input);
    return match != null ? match.group(1) ?? 'N/A' : 'N/A';
  }

  //

  static void networkPrint(dynamic name, dynamic value) {
    final fileName = _getCallerFileName();

    if (kDebugMode) {
      debugPrint(
        Colorize(
              name.toString(),
            ).apply(Styles.BLACK).bgWhite().bold().italic().initial +
            Colorize(
              " ==> ",
            ).apply(Styles.BLACK).bgWhite().bold().italic().initial +
            Colorize(
              value.toString(),
            ).apply(Styles.YELLOW).bold().italic().initial,
      );
    }
  }

  static String _getCallerFileName() {
    final traceLines = StackTrace.current.toString().split("\n");
    // if (traceLines.length > 1) {
    //   final regExp = RegExp(r'\(([^)]+)\)');
    //   final match = regExp.firstMatch(traceLines[1]);
    //   if (match != null && match.groupCount >= 1) {
    //     return match.group(1)!;
    //   }
    // }
    if (traceLines.length > 2) {
      final regExp = RegExp(r'\(([^)]+)\)');
      final match = regExp.firstMatch(traceLines[2]);

      if (match != null && match.groupCount >= 1) {
        return match.group(1)!;
      }
    }
    return "Unknown";
  }
}

// class AdRepository {
//   static ConsentStatus? fullStatus;
//   static AdRequest getAdRequest() {
//     bool nonPersonalized = false;
//
//     if (fullStatus == ConsentStatus.obtained) {
//       // وافق المستخدم = إعلان مخصص
//       nonPersonalized = false;
//       Dev.console(['User consented: show personalized ads']);
//     } else {
//       // رفض أو لم يوافق = إعلان غير مخصص
//       nonPersonalized = true;
//       Dev.console(['User did not consent: show non-personalized ads']);
//     }
//     return AdRequest(nonPersonalizedAds: nonPersonalized);
//   }
//
//   static Future<InitializationStatus> initGoogleMobileAds() {
//     Dev.console(['[initGoogleMobileAds] called']);
//     return MobileAds.instance.initialize().then((status) {
//       Dev.console(['[initGoogleMobileAds] initialized', status]);
//       return status;
//     });
//   }
//
//   static void showConsentUMP() {
//     final params = ConsentRequestParameters(
//       consentDebugSettings: ConsentDebugSettings(
//         debugGeography: DebugGeography.debugGeographyEea,
//         testIdentifiers: ['433048E7456848C19EAED45EAB7B7E05'],
//       ),
//     );
//     Dev.console([
//       '[showConsentUMP] called',
//       'tagForUnderAgeOfConsent: ${params.tagForUnderAgeOfConsent}',
//       'consentDebugSettings: ${params.consentDebugSettings}',
//     ]);
//
//     ConsentInformation.instance.requestConsentInfoUpdate(
//       params,
//       () async {
//         Dev.console(['[showConsentUMP] Consent info updated']);
//         final available = await ConsentInformation.instance
//             .isConsentFormAvailable();
//         Dev.console(['[showConsentUMP] isConsentFormAvailable', available]);
//         if (available) {
//           loadForm();
//         } else {
//           fullStatus = await ConsentInformation.instance.getConsentStatus();
//           Dev.console(['[showConsentUMP] Consent form is not available']);
//         }
//       },
//       (FormError error) {
//         Dev.console(['[showConsentUMP] Error:', error.message]);
//       },
//     );
//   }
//
//   static void loadForm() {
//     Dev.console(['[loadForm] called']);
//     ConsentForm.loadConsentForm(
//       (ConsentForm consentForm) async {
//         Dev.console(['[loadForm] Consent form loaded']);
//         var status = await ConsentInformation.instance.getConsentStatus();
//         Dev.console(['[loadForm] Consent status:', status]);
//         if (status == ConsentStatus.required) {
//           consentForm.show((FormError? formError) async {
//             Dev.console(['[loadForm] Consent form shown']);
//             if (formError != null) {
//               Dev.console([
//                 '[loadForm] Error when showing consent form:',
//                 formError.message,
//               ]);
//             }
//             fullStatus = await ConsentInformation.instance.getConsentStatus();
//             Dev.console([
//               '[loadForm] Consent form closed, new status:',
//               fullStatus,
//             ]);
//             // loadForm();
//           });
//         }
//         //
//         else {
//           fullStatus = status;
//           Dev.console(['[loadForm] Consent not required or already given']);
//         }
//       },
//       (formError) {
//         Dev.console([
//           '[loadForm] Error loading consent form:',
//           formError.message,
//         ]);
//       },
//     );
//   }
// }
