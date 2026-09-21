import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../theme/app_theme.dart';

/// Desktop / tablet splash loader: four wide feature images arranged like
/// seats on a round table, slowly orbiting while the whole ring "breathes".
class SplashFeatureOrbit extends StatefulWidget {
  const SplashFeatureOrbit({super.key});

  static const featureAssets = <String>[
    'assets/images/splash_feature_revision.png',
    'assets/images/splash_feature_routines.png',
    'assets/images/splash_feature_voice.png',
    'assets/images/splash_feature_progress.png',
  ];

  @override
  State<SplashFeatureOrbit> createState() => _SplashFeatureOrbitState();
}

class _SplashFeatureOrbitState extends State<SplashFeatureOrbit>
    with TickerProviderStateMixin {
  late final AnimationController _spin;
  late final AnimationController _breathe;

  @override
  void initState() {
    super.initState();
    // Slow full turn — calm, not carnival.
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 28),
    )..repeat();
    // Human-breath cadence: inhale ~1.6s, exhale ~1.6s.
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _spin.dispose();
    _breathe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.sizeOf(context);
    final cardW = (size.width * 0.20).clamp(168.0, 250.0);
    final cardH = cardW * 0.52; // long / wide tiles
    // Wider ring so the four feature cards never crowd each other.
    final radius = (math.min(size.width, size.height) * 0.30).clamp(160.0, 260.0);

    return ColoredBox(
      color: d ? AppColors.bgDark : AppColors.bgLight,
      child: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([_spin, _breathe]),
          builder: (_, __) {
            // Breathing: soft expand on inhale, ease back on exhale.
            final breath =
                Curves.easeInOutSine.transform(_breathe.value.clamp(0.0, 1.0));
            final scale = 0.92 + breath * 0.14; // 0.92 → 1.06
            final angle0 = _spin.value * 2 * math.pi;

            return Opacity(
              opacity: 0.55 + breath * 0.45,
              child: Transform.scale(
                scale: scale,
                child: SizedBox(
                  width: radius * 2 + cardW,
                  height: radius * 2 + cardH,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Same center mark as HTML boot (📚) — one loader, not two looks.
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: 0.16),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.35),
                          ),
                        ),
                        child: const Center(
                          child: Text('📚', style: TextStyle(fontSize: 28)),
                        ),
                      ),
                      for (var i = 0; i < SplashFeatureOrbit.featureAssets.length; i++)
                        _orbitCard(
                          index: i,
                          angle: angle0 + i * math.pi / 2,
                          radius: radius,
                          cardW: cardW,
                          cardH: cardH,
                          d: d,
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _orbitCard({
    required int index,
    required double angle,
    required double radius,
    required double cardW,
    required double cardH,
    required bool d,
  }) {
    final dx = math.cos(angle) * radius;
    final dy = math.sin(angle) * radius;
    return Transform.translate(
      offset: Offset(dx, dy),
      child: SizedBox(
        width: cardW,
        height: cardH,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1.2,
            ),
                      ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Image.asset(
              SplashFeatureOrbit.featureAssets[index],
              fit: BoxFit.cover,
              gaplessPlayback: true,
              // Bundled assets decode instantly — never wrap in Shimmer
              // (that paints a loader ON TOP of the photo).
              frameBuilder: (context, child, frame, wasSyncLoaded) {
                if (wasSyncLoaded || frame != null) return child;
                return Shimmer.fromColors(
                  baseColor: d
                      ? const Color(0xFF2D3140)
                      : const Color(0xFFE8ECF4),
                  highlightColor: d
                      ? const Color(0xFF3D4250)
                      : const Color(0xFFF5F7FB),
                  period: const Duration(milliseconds: 1200),
                  child: ColoredBox(
                    color: d ? const Color(0xFF2D3140) : const Color(0xFFE8ECF4),
                  ),
                );
              },
              errorBuilder: (_, __, ___) => ColoredBox(
                color: AppColors.primary.withValues(alpha: 0.2),
                child: const Center(
                  child:
                      Icon(Icons.auto_stories_rounded, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
