import 'dart:io';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../main.dart';
import '../core/app_theme.dart';
import '../controllers/theme_controller.dart';
import '../services/user_subscription_service.dart';

// Production Ad Unit IDs
// CSV
const String _rewardedCsv90DaysUnitId =
    'ca-app-pub-4841708264723393/6480632807'; // verestrideallricsv1
const String _rewardedCsvAllTimeUnitId =
    'ca-app-pub-4841708264723393/2102038064'; // verestrideallricsv2
// Excel
const String _rewardedExcel90DaysUnitId =
    'ca-app-pub-4841708264723393/1535427883'; // vervestrideRlexcel1
const String _rewardedExcelAllTimeUnitId =
    'ca-app-pub-4841708264723393/5850512185'; // vervestrideRlexcel2
// Banner
const String _bannerAdUnitId1 =
    'ca-app-pub-4841708264723393/2756176065'; // vervestride1
const String _bannerAdUnitId2 =
    'ca-app-pub-4841708264723393/2573177389'; // vervestride2
const String _bannerAdUnitId3 =
    'ca-app-pub-4841708264723393/9430229771'; // vervestride3

// New Layout Specific IDs
const String _bannerAdUnitIdMeals =
    'ca-app-pub-4841708264723393/8469383771'; // Meals Bottom
const String _bannerAdUnitIdActivities =
    'ca-app-pub-4841708264723393/1367022445'; // Activities Bottom
// Note: User requested a 3rd unique one but only provided 2 screenshots.
// Reusing Activities ID for now or using a placeholder if they provide it later.
const String _bannerAdUnitIdWorkout =
    'ca-app-pub-4841708264723393/1367022445'; // Workout Bottom (Placeholder/Reused)

Future<bool> showRewardedAdForCsv90Days({
  required ScaffoldMessengerState messenger,
}) async {
  return await _showRewardedAd(
    messenger: messenger,
    feature: 'Last 90 Days CSV Export',
    unlockDuration: const Duration(hours: 24),
    adUnitId: _rewardedCsv90DaysUnitId,
  );
}

Future<bool> showRewardedAdForCsvAllTime({
  required ScaffoldMessengerState messenger,
}) async {
  return await _showRewardedAd(
    messenger: messenger,
    feature: 'All Data CSV Export',
    unlockDuration: const Duration(hours: 24),
    adUnitId: _rewardedCsvAllTimeUnitId,
  );
}

Future<bool> showRewardedAdForExcel90Days({
  required ScaffoldMessengerState messenger,
}) async {
  return await _showRewardedAd(
    messenger: messenger,
    feature: 'Last 90 Days Excel Export',
    unlockDuration: const Duration(hours: 24),
    adUnitId: _rewardedExcel90DaysUnitId,
  );
}

Future<bool> showRewardedAdForExcelAllTime({
  required ScaffoldMessengerState messenger,
}) async {
  return await _showRewardedAd(
    messenger: messenger,
    feature: 'All Data Excel Export',
    unlockDuration: const Duration(hours: 24),
    adUnitId: _rewardedExcelAllTimeUnitId,
  );
}

Future<bool> _showRewardedAd({
  required ScaffoldMessengerState messenger,
  required String feature,
  required Duration unlockDuration,
  required String adUnitId,
}) async {
  debugPrint('🎯 Starting rewarded ad for feature: $feature');
  debugPrint('🎯 Using ad unit ID: $adUnitId');
  debugPrint('🎯 Platform: ${defaultTargetPlatform.toString()}');
  debugPrint('🎯 Is debug mode: $kDebugMode');

  if (kIsWeb) {
    debugPrint('ℹ️ Simulating rewarded ad for web...');
    // Show a dialog to make it feel like something is happening
    final bool? proceed = await showDialog<bool>(
      context: messenger.context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Simulated Ad (Web)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_circle_outline, size: 48, color: AppColors.primary),
            const SizedBox(height: 16),
            Text('Watching ad to unlock $feature...'),
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Complete Simulation'),
          ),
        ],
      ),
    );

    if (proceed == true) {
      messenger.showSnackBar(
        SnackBar(
            content:
                Text('$feature unlocked for ${unlockDuration.inHours} hours!')),
      );
      return true;
    }
    return false;
  }

  // Check if we're on a supported platform
  if (!Platform.isAndroid && !Platform.isIOS) {
    debugPrint('❌ Ads not supported on this platform: $defaultTargetPlatform');
    return false;
  }

  Completer<bool> completer = Completer<bool>();

  void tryLoadingRewardedInterstitial() {
    debugPrint('🎯 Attempting fallback: Loading rewarded interstitial ad...');
    RewardedInterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (RewardedInterstitialAd ad) {
          debugPrint('✅ Rewarded interstitial ad loaded successfully');
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (RewardedInterstitialAd ad) {
              debugPrint('📺 Rewarded interstitial ad showed on screen');
            },
            onAdDismissedFullScreenContent: (RewardedInterstitialAd ad) {
              debugPrint('❌ Rewarded interstitial ad dismissed');
              ad.dispose();
              if (!completer.isCompleted) completer.complete(false);
            },
            onAdFailedToShowFullScreenContent:
                (RewardedInterstitialAd ad, AdError error) {
              debugPrint('❌ Rewarded interstitial ad failed to show: $error');
              messenger.showSnackBar(
                SnackBar(content: Text('Ad failed to show: ${error.message}')),
              );
              ad.dispose();
              if (!completer.isCompleted) completer.complete(false);
            },
          );

          debugPrint('🎯 Showing rewarded interstitial ad...');
          ad.show(
            onUserEarnedReward: (ad, reward) {
              debugPrint(
                  '🎉 User earned reward from interstitial: ${reward.amount}');
              messenger.showSnackBar(
                SnackBar(
                    content: Text(
                        '$feature unlocked for ${unlockDuration.inHours} hours!')),
              );
              if (!completer.isCompleted) completer.complete(true);
            },
          );
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('❌ Failed to load rewarded interstitial ad: $error');
          messenger.showSnackBar(
            SnackBar(content: Text('Ad failed to load: ${error.message}')),
          );
          if (!completer.isCompleted) completer.complete(false);
        },
      ),
    );
  }

  try {
    debugPrint('🎯 Loading rewarded ad...');
    await RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          debugPrint('✅ Rewarded ad loaded successfully');
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (RewardedAd ad) {
              debugPrint('📺 Rewarded ad showed on screen');
            },
            onAdDismissedFullScreenContent: (RewardedAd ad) {
              debugPrint('❌ Rewarded ad dismissed without reward');
              ad.dispose();
              if (!completer.isCompleted) {
                completer.complete(false);
              }
            },
            onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
              debugPrint('❌ Rewarded ad failed to show: $error');
              messenger.showSnackBar(
                SnackBar(content: Text('Ad failed to show: ${error.message}')),
              );
              ad.dispose();
              if (!completer.isCompleted) {
                completer.complete(false);
              }
            },
          );

          debugPrint('🎯 Showing rewarded ad...');
          ad.show(
            onUserEarnedReward: (ad, reward) {
              debugPrint(
                  '🎉 User earned reward: ${reward.amount} ${reward.type}');
              messenger.showSnackBar(
                SnackBar(
                    content: Text(
                        '$feature unlocked for ${unlockDuration.inHours} hours!')),
              );
              if (!completer.isCompleted) {
                completer.complete(true);
              }
            },
          );
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint(
              '❌ Failed to load rewarded ad (Code: ${error.code}): $error');
          // Error code 3 (Internal Error/No Fill) or similar might indicate a type mismatch in some SDK versions,
          // but specifically for our case, we'll try the interstitial fallback regardless of the error code if loading fails.
          tryLoadingRewardedInterstitial();
        },
      ),
    );
  } catch (e) {
    debugPrint('❌ Exception in rewarded ad load attempt: $e');
    tryLoadingRewardedInterstitial();
  }

  return completer.future;
}

class AdBannerWidget extends StatefulWidget {
  final String? adUnitId;

  const AdBannerWidget({
    super.key,
    this.adUnitId,
  });

  static const String banner1Id = _bannerAdUnitId1;
  static const String banner2Id = _bannerAdUnitId2;
  static const String banner3Id = _bannerAdUnitId3;
  static const String bannerMealsId = _bannerAdUnitIdMeals;
  static const String bannerActivitiesId = _bannerAdUnitIdActivities;
  static const String bannerWorkoutId = _bannerAdUnitIdWorkout;

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  Timer? _initRetryTimer;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
    _startInitRetryLoop();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ThemeController.instance.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _initRetryTimer?.cancel();
    _bannerAd?.dispose();
    ThemeController.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _loadBannerAd() {
    if (kIsWeb) return;

    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    if (!isAndroid && !isIOS) return;
    if (_isLoaded || _isLoading) return;
    if (!isAdsInitialized) {
      debugPrint('AdBannerWidget: Ads not initialized yet, skipping load');
      return;
    }

    _isLoading = true;

    _bannerAd?.dispose();
    _bannerAd = null;
    _isLoaded = false;

    _bannerAd = BannerAd(
      adUnitId: widget.adUnitId ?? AdBannerWidget.banner1Id,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _isLoaded = true;
            _isLoading = false;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('BannerAd failed to load: $error');
          ad.dispose();
          if (mounted) {
            setState(() {
              _isLoading = false;
              _isLoaded = false;
              _bannerAd = null;
            });
          }
        },
      ),
    );
    _bannerAd?.load();
  }

  void _startInitRetryLoop() {
    if (kIsWeb) return;
    _initRetryTimer?.cancel();
    var ticks = 0;
    _initRetryTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (!mounted) return;
      if (_isLoaded || _isLoading) return;
      ticks++;
      if (isAdsInitialized) {
        _loadBannerAd();
        return;
      }
      if (ticks >= 25) {
        _initRetryTimer?.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Check if user has purchased ad-free
    if (UserSubscriptionService.instance.isAdFree) {
      debugPrint('AdBannerWidget: User has premium, hiding banner');
      return const SizedBox.shrink();
    }

    if (!_isLoaded || _bannerAd == null) {
      return SizedBox(
        width: AdSize.banner.width.toDouble(),
        height: AdSize.banner.height.toDouble(),
      );
    }
    return SizedBox(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
