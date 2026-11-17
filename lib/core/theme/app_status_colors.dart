import 'package:flutter/material.dart';

import '../constants/escom.dart';

/// Estados de presentación; conserva los estados persistidos de los reportes.
enum ItemVisualState { lost, seen, found, delivered }

@immutable
class BadgeColors {
  const BadgeColors(this.foreground, this.background);

  final Color foreground;
  final Color background;

  BadgeColors lerp(BadgeColors other, double t) => BadgeColors(
    Color.lerp(foreground, other.foreground, t)!,
    Color.lerp(background, other.background, t)!,
  );
}

@immutable
class AppStatusColors extends ThemeExtension<AppStatusColors> {
  const AppStatusColors({
    required this.lost,
    required this.seen,
    required this.found,
    required this.delivered,
  });

  final BadgeColors lost;
  final BadgeColors seen;
  final BadgeColors found;
  final BadgeColors delivered;

  static const light = AppStatusColors(
    lost: BadgeColors(Color(0xFFC62828), Color(0xFFFFEBEE)),
    seen: BadgeColors(Color(0xFFB45309), Color(0xFFFEF3C7)),
    found: BadgeColors(Color(0xFF15803D), Color(0xFFDCFCE7)),
    delivered: BadgeColors(Color(0xFF475569), Color(0xFFF1F5F9)),
  );
  static const dark = AppStatusColors(
    lost: BadgeColors(Color(0xFFFF8A80), Color(0xFF4E1418)),
    seen: BadgeColors(Color(0xFFFCD34D), Color(0xFF452A06)),
    found: BadgeColors(Color(0xFF4ADE80), Color(0xFF0D3B1E)),
    delivered: BadgeColors(Color(0xFF94A3B8), Color(0xFF1E293B)),
  );

  static AppStatusColors of(BuildContext context) =>
      Theme.of(context).extension<AppStatusColors>()!;

  BadgeColors forType(ReportType type) =>
      type == ReportType.lost ? lost : found;

  BadgeColors forState(ItemVisualState state) => switch (state) {
    ItemVisualState.lost => lost,
    ItemVisualState.seen => seen,
    ItemVisualState.found => found,
    ItemVisualState.delivered => delivered,
  };

  @override
  AppStatusColors copyWith({
    BadgeColors? lost,
    BadgeColors? seen,
    BadgeColors? found,
    BadgeColors? delivered,
  }) => AppStatusColors(
    lost: lost ?? this.lost,
    seen: seen ?? this.seen,
    found: found ?? this.found,
    delivered: delivered ?? this.delivered,
  );

  @override
  AppStatusColors lerp(covariant AppStatusColors? other, double t) {
    if (other == null) return this;
    return AppStatusColors(
      lost: lost.lerp(other.lost, t),
      seen: seen.lerp(other.seen, t),
      found: found.lerp(other.found, t),
      delivered: delivered.lerp(other.delivered, t),
    );
  }
}
