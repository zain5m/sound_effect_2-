import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sound_effect_2/main.dart';
import 'package:sound_effect_2/providers/audio_app_provider.dart';
import 'package:sound_effect_2/providers/ui_event_service.dart';

import '../ads/banner/banner_widget.dart';
import '../theme/app_theme.dart';
import '../widgets/actions_sheet.dart';
import '../widgets/app_header.dart';
import '../widgets/master_effects_panel.dart';
import '../widgets/player_bottom_bar.dart';
import '../widgets/segment_card.dart';
import '../widgets/upload_area.dart';
import '../widgets/waveform_section.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late StreamSubscription _toastSubscription;
  final _scrollController = ScrollController();
  final _effectsKey = GlobalKey();
  final _splitKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    _toastSubscription = UiEventService.instance.toastStream.listen((event) {
      Dev.console(['_toastSubscription']);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(event.message),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.small),
            side: BorderSide(
              color: event.isError ? AppColors.danger : AppColors.success,
            ),
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _toastSubscription.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollTo(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      alignment: 0.1,
    );
  }

  void _openActionsSheet() {
    ActionsSheet.show(
      context,
      onScrollToEffects: () => _scrollTo(_effectsKey),
      onScrollToSplit: () => _scrollTo(_splitKey),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      flexibleSpace: Container(
        decoration: BoxDecoration(gradient: AppDecorations.headerGradient),
      ),
      title: Text(
        'محرر الصوت الذكي',
        style: GoogleFonts.tajawal(fontWeight: FontWeight.w700, fontSize: 18),
      ),
      centerTitle: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.menu_rounded),
        onPressed: _openActionsSheet,
        tooltip: 'القائمة',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      bottomNavigationBar: const BannerWidget(),
      body: SafeArea(
        child: Selector<AudioAppProvider, bool>(
          selector: (context, provider) => provider.audioBuffer != null,
          builder: (context, isFile, child) {
            if (!isFile) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  Column(
                    children: [
                      const AppHeader(),
                      const Expanded(child: Center(child: UploadArea())),
                    ],
                  ),
                  const LoadingOverlay(),
                ],
              );
            }
            return Stack(
              children: [
                SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const UploadArea(),
                        KeyedSubtree(
                          key: _effectsKey,
                          child: const MasterEffectsPanel(),
                        ),
                        KeyedSubtree(
                          key: _splitKey,
                          child: const SplitSettingsPanel(),
                        ),
                        const SizedBox(height: 10),
                        const WaveformSection(),
                        const SizedBox(height: 20),
                        const SegmentsSection(),
                        SizedBox(height: 50),
                      ],
                    ),
                  ),
                ),
                const Align(
                  alignment: Alignment.bottomCenter,
                  child: PlayerBottomBar(),
                ),
                const LoadingOverlay(),
              ],
            );
          },
        ),
      ),
    );
  }
}

class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<AudioAppProvider, ({bool loading, String message})>(
      selector: (_, p) => (loading: p.isLoading, message: p.progressMessage),
      builder: (_, state, _) {
        if (!state.loading) return const SizedBox.shrink();

        return Positioned.fill(
          child: AbsorbPointer(
            child: ColoredBox(
              color: Colors.black38,
              child: Center(
                child: Container(
                  width: 320,
                  padding: const EdgeInsets.all(28),
                  decoration: AppDecorations.softCard(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 44,
                        height: 44,
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                          strokeWidth: 3,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        state.message.isEmpty
                            ? 'جاري تنفيذ العملية...'
                            : state.message,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.tajawal(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
