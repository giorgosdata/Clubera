import 'package:flutter/foundation.dart';

/// Feature switches that differ per platform.
///
/// Apple App Review (Oct 2026) rejected the iOS build because "simulated
/// gambling" features (spin wheel, scratch card, mystery box, prediction
/// coupons with points/prizes) are only allowed from organization developer
/// accounts. Until the App Store account is migrated to a company account,
/// these features are hidden on iOS only. Android and web are unchanged.
///
/// When the account becomes an organization account, set
/// [_allowChanceGamesOnIOS] to `true` and ship a new build.
class FeatureFlags {
  FeatureFlags._();

  static const bool _allowChanceGamesOnIOS = false;

  static bool get _isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Predictions, coupon, spin wheel, Play & Earn games, prizes/rewards.
  static bool get chanceGamesEnabled => !_isIOS || _allowChanceGamesOnIOS;
}
