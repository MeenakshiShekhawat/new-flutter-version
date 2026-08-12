import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/constants/app_routes.dart';

/// Order Success screen — Welfog
///
/// Design: confetti bursts once from behind the success badge, animated
/// checkmark badge, centered title/subtitle, and Track Order / Continue
/// Shopping actions pinned near the bottom.
///
/// Behavior preserved from the previous implementation:
/// - Requires [orderId]
/// - Auto-redirects to Home after 2.5s unless the timer is cancelled
///   (via [OrderSuccessScreen.cancelActiveTimer] or a button tap)
/// - Blocks the system back button and instead routes to Home
class OrderSuccessScreen extends StatefulWidget {
  final String orderId;

  const OrderSuccessScreen({super.key, required this.orderId});

  static void cancelActiveTimer() {
    _OrderSuccessScreenState.activeState?._cancelTimer();
  }

  @override
  State<OrderSuccessScreen> createState() => _OrderSuccessScreenState();

  // ---- Welfog brand palette ----
  static const Color brand = Color(0xFFF47504);
  static const Color brandSoft = Color(0xFFFF8F2E);
  static const Color brandDeep = Color(0xFFD96503);
  static const Color teal = Color(0xFF1B757B);
  static const Color ink = Color(0xFF1A1A1A);
  static const Color inkMuted = Color(0xFF666666);
  static const Color inkFaint = Color(0xFF9A9A9A);
  static const Color line = Color(0x11000000);
}

class _OrderSuccessScreenState extends State<OrderSuccessScreen>
    with TickerProviderStateMixin {
  static _OrderSuccessScreenState? activeState;

  late final AnimationController _entrance;
  late final AnimationController _ringCtrl;
  late final AnimationController _confettiCtrl;
  late final List<_Confetto> _confetti;

  final GlobalKey _stackKey = GlobalKey();
  final GlobalKey _badgeKey = GlobalKey();
  Offset? _badgeCenter;

  Timer? _redirectTimer;

  @override
  void initState() {
    super.initState();
    activeState = this;

    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();

    // One-shot burst — does NOT repeat.
    _confettiCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    final rnd = Random();
    const colors = [
      OrderSuccessScreen.brand,
      OrderSuccessScreen.brandSoft,
      OrderSuccessScreen.teal,
      Color(0xFF2A8F96),
      Color(0xFFFFD4A8),
    ];
    const count = 26;
    _confetti = List.generate(count, (i) {
      final angle = (i / count) * 2 * pi + (rnd.nextDouble() * 0.6 - 0.3);
      final distance = 90 + rnd.nextDouble() * 150;
      return _Confetto(
        tx: cos(angle) * distance,
        ty: sin(angle) * distance - 20, // slight upward bias
        rotation: rnd.nextDouble() * 360 - 180,
        delay: rnd.nextDouble() * 0.15, // 0..15% of the burst duration
        color: colors[i % colors.length],
        rounded: rnd.nextBool(),
      );
    });

    // Measure the badge's on-screen position once the first frame (and the
    // entrance layout) has settled, then fire the confetti burst from there.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureBadgeCenter();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _measureBadgeCenter();
          _confettiCtrl.forward();
        }
      });
    });

    _redirectTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) {
        _redirectTimer = null;
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.home,
          (route) => false,
        );
      }
    });
  }

  void _measureBadgeCenter() {
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final badgeBox = _badgeKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null || badgeBox == null) return;

    final topLeft = badgeBox.localToGlobal(Offset.zero, ancestor: stackBox);
    final center =
        topLeft + Offset(badgeBox.size.width / 2, badgeBox.size.height / 2);

    if (mounted) {
      setState(() => _badgeCenter = center);
    }
  }

  void _cancelTimer() {
    if (_redirectTimer != null) {
      debugPrint("🔔 OrderSuccessScreen redirect timer cancelled.");
      _redirectTimer?.cancel();
      _redirectTimer = null;
    }
  }

  @override
  void dispose() {
    if (activeState == this) {
      activeState = null;
    }
    _cancelTimer();
    _entrance.dispose();
    _ringCtrl.dispose();
    _confettiCtrl.dispose();
    super.dispose();
  }

  Animation<double> _fade(double startAt, {double span = 0.35}) {
    return CurvedAnimation(
      parent: _entrance,
      curve: Interval(startAt, (startAt + span).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _cancelTimer();
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.home,
          (route) => false,
        );
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          key: _stackKey,
          children: [
            // Soft brand-tinted background
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.9),
                    radius: 1.1,
                    colors: [
                      OrderSuccessScreen.brand.withOpacity(0.12),
                      Colors.white.withOpacity(0),
                    ],
                  ),
                ),
              ),
            ),

            // Confetti burst — fires once from behind the badge
            if (_badgeCenter != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _confettiCtrl,
                    builder: (context, _) {
                      return CustomPaint(
                        painter: _ConfettiPainter(
                          confetti: _confetti,
                          progress: _confettiCtrl.value,
                          origin: _badgeCenter!,
                        ),
                      );
                    },
                  ),
                ),
              ),

            SafeArea(
              child: Column(
                children: [
                  // ===== Centered hero =====
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildBadge(),
                          const SizedBox(height: 20),
                          FadeTransition(
                            opacity: _fade(0.15),
                            child: const Text(
                              'Order Placed Successfully!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: OrderSuccessScreen.ink,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          FadeTransition(
                            opacity: _fade(0.22),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 34),
                              child: const Text(
                                'Thank you for shopping with us.\nYour items will be delivered soon.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                  height: 1.55,
                                  color: OrderSuccessScreen.inkMuted,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ===== Bottom actions =====
                  FadeTransition(
                    opacity: _fade(0.42),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                      child: Column(
                        children: [
                          // Track Order — only when we actually have an ID
                          if (widget.orderId.isNotEmpty)
                            SizedBox(
                              width: double.infinity,
                              height: 46,
                              child: ElevatedButton(
                                onPressed: () {
                                  _cancelTimer();
                                  Navigator.of(context).pushNamedAndRemoveUntil(
                                    AppRoutes.home,
                                    (route) => false,
                                  );
                                  Navigator.of(context)
                                      .pushNamed(AppRoutes.orders);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: OrderSuccessScreen.brandSoft,
                                  foregroundColor: Colors.white,
                                  elevation: 3,
                                  shadowColor:
                                      OrderSuccessScreen.brand.withOpacity(0.3),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text(
                                  'Track Order',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          if (widget.orderId.isNotEmpty)
                            const SizedBox(height: 9),
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: OutlinedButton(
                              onPressed: () {
                                _cancelTimer();
                                Navigator.of(context).pushNamedAndRemoveUntil(
                                  AppRoutes.home,
                                  (route) => false,
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: OrderSuccessScreen.ink,
                                side: const BorderSide(
                                  color: OrderSuccessScreen.line,
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                'Continue Shopping',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          RichText(
                            text: const TextSpan(
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: OrderSuccessScreen.inkFaint,
                              ),
                              children: [
                                TextSpan(text: 'Need help? '),
                                TextSpan(
                                  text: 'Contact Support',
                                  style: TextStyle(
                                    color: OrderSuccessScreen.teal,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge() {
    return ScaleTransition(
      scale: CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOutBack),
      ),
      child: SizedBox(
        key: _badgeKey,
        width: 96,
        height: 96,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // dashed spinning ring
            AnimatedBuilder(
              animation: _ringCtrl,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _ringCtrl.value * 2 * pi,
                  child: child,
                );
              },
              child: CustomPaint(
                size: const Size(96, 96),
                painter: _DashedRingPainter(
                  color: OrderSuccessScreen.brand.withOpacity(0.35),
                ),
              ),
            ),
            // white outer disc
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: OrderSuccessScreen.brand.withOpacity(0.22),
                    blurRadius: 34,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
            ),
            // orange core with checkmark
            Container(
              width: 78,
              height: 78,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    OrderSuccessScreen.brand,
                    OrderSuccessScreen.brandSoft,
                  ],
                ),
              ),
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: _entrance,
                  curve: const Interval(0.45, 0.7, curve: Curves.easeOut),
                ),
                child: ScaleTransition(
                  scale: CurvedAnimation(
                    parent: _entrance,
                    curve:
                        const Interval(0.45, 0.75, curve: Curves.easeOutBack),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single confetti piece for the one-time burst.
class _Confetto {
  _Confetto({
    required this.tx,
    required this.ty,
    required this.rotation,
    required this.delay,
    required this.color,
    required this.rounded,
  });

  final double tx; // final x offset from the burst origin
  final double ty; // final y offset from the burst origin
  final double rotation; // final rotation in degrees
  final double delay; // 0..~0.15, fraction of the burst duration
  final Color color;
  final bool rounded;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({
    required this.confetti,
    required this.progress,
    required this.origin,
  });

  final List<_Confetto> confetti;
  final double progress; // 0..1, plays once (see _confettiCtrl)
  final Offset origin; // burst origin — badge center

  @override
  void paint(Canvas canvas, Size size) {
    for (final c in confetti) {
      // Local progress for this particle, offset by its own start delay.
      final t = ((progress - c.delay) / (1 - c.delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;

      final eased = Curves.easeOutCubic.transform(t);

      final opacity = t < 0.12 ? t / 0.12 : (1 - (t - 0.12) / 0.88);
      if (opacity <= 0) continue;

      final dx = origin.dx + eased * c.tx;
      final dy = origin.dy + eased * c.ty;
      final scale = 0.5 + eased * 0.5;
      final rotation = eased * c.rotation * pi / 180;

      final paint = Paint()..color = c.color.withOpacity(opacity.clamp(0, 1));

      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(rotation);
      canvas.scale(scale);
      final rect = Rect.fromCenter(center: Offset.zero, width: 7, height: 12);
      if (c.rounded) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(6)),
          paint,
        );
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2)),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.origin != origin;
}

class _DashedRingPainter extends CustomPainter {
  _DashedRingPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final rect = Rect.fromLTWH(1, 1, size.width - 2, size.height - 2);
    const dashLength = 5.0;
    const gapLength = 4.0;
    final path = Path()..addOval(rect);

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + dashLength;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRingPainter oldDelegate) => false;
}
