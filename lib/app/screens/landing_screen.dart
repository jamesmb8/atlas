// lib/app/screens/landing_screen.dart
import 'dart:math';

import 'package:atlas/features/auth/screens/signupnamescreen.dart';
import 'package:atlas/features/themes/atlas_theme.dart';
import 'package:flutter/material.dart';

import '../../features/auth/screens/loginscreen.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with SingleTickerProviderStateMixin {
  static const int _nodeCount = 22;
  static const int _routeCount = 28;

  late final AnimationController _t;
  late final List<_Node> _nodes;
  late final List<_Route> _routes;

  Offset _pointer = Offset.zero;
  bool _hasPointer = false;

  @override
  void initState() {
    super.initState();
    _t = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    final rand = Random(42);
    _nodes = _generateNodes(rand);
    _routes = _generateRoutes(_nodes, rand);
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final atlas = context.atlas;

    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanDown: (d) => _setPointer(d.localPosition, true),
        onPanUpdate: (d) => _setPointer(d.localPosition, true),
        onPanEnd: (_) => _setPointer(Offset.zero, false),
        onPanCancel: () => _setPointer(Offset.zero, false),
        onTapDown: (d) => _setPointer(d.localPosition, true),
        onTapUp: (_) => _setPointer(Offset.zero, false),
        onTapCancel: () => _setPointer(Offset.zero, false),
        child: Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _t,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: RouteNetworkPainter(
                        time: _t.value,
                        pointer: _pointer,
                        pointerActive: _hasPointer,
                        nodes: _nodes,
                        routes: _routes,
                        background: atlas.background,
                        accent: atlas.brandTertiary,
                        divider: atlas.border,
                      ),
                    );
                  },
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.topCenter,
                      child: Text('Atlas', style: tt.headlineLarge),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: Text(
                              'Shows the best ways to get there.',
                              textAlign: TextAlign.center,
                              style: tt.bodyLarge?.copyWith(
                                color: atlas.textPrimary.withOpacity(0.88),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: 240,
                            child: _PrimaryButton(
                              label: 'Sign up',
                              onPressed: _onSignUp,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Already have an account? ',
                                style: tt.bodyMedium,
                              ),
                              GestureDetector(
                                onTap: _onLogIn,
                                child: Text(
                                  'Log in',
                                  style: tt.bodyMedium?.copyWith(
                                    color: atlas.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('One tap. No noise.', style: tt.bodyMedium),
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
    );
  }

  void _setPointer(Offset p, bool active) {
    setState(() {
      _pointer = p;
      _hasPointer = active;
    });
  }

  void _onLogIn() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _onSignUp() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SignUpNameScreen()),
    );
  }

  List<_Node> _generateNodes(Random rand) {
    final nodes = <_Node>[];

    for (int i = 0; i < _nodeCount; i++) {
      nodes.add(
        _Node(
          x: rand.nextDouble().clamp(0.08, 0.92),
          y: rand.nextDouble().clamp(0.08, 0.92),
          dx: 0.6 + rand.nextDouble() * 1.2,
          dy: 0.6 + rand.nextDouble() * 1.2,
          phase: rand.nextDouble() * 2 * pi,
        ),
      );
    }

    return nodes;
  }

  List<_Route> _generateRoutes(List<_Node> nodes, Random rand) {
    final routes = <_Route>[];

    for (int i = 0; i < nodes.length; i++) {
      final dists = <({int j, double d})>[];

      for (int j = 0; j < nodes.length; j++) {
        if (i == j) continue;
        final dx = nodes[i].x - nodes[j].x;
        final dy = nodes[i].y - nodes[j].y;
        dists.add((j: j, d: dx * dx + dy * dy));
      }

      dists.sort((a, b) => a.d.compareTo(b.d));

      for (int k = 0; k < min(2, dists.length); k++) {
        routes.add(
          _Route(
            a: i,
            b: dists[k].j,
            phase: rand.nextDouble(),
          ),
        );
      }
    }

    while (routes.length < _routeCount) {
      final a = rand.nextInt(nodes.length);
      final b = rand.nextInt(nodes.length);
      if (a == b) continue;

      routes.add(
        _Route(
          a: a,
          b: b,
          phase: rand.nextDouble(),
        ),
      );
    }

    return routes;
  }
}

class _PrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;

  const _PrimaryButton({
    required this.label,
    required this.onPressed,
  });

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final atlas = context.atlas;

    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: atlas.brandTertiary,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                blurRadius: 14,
                offset: const Offset(0, 8),
                color: atlas.brandTertiary.withOpacity(0.28),
              ),
              BoxShadow(
                blurRadius: 18,
                offset: const Offset(0, 10),
                color: Colors.black.withOpacity(0.06),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onPressed,
              borderRadius: BorderRadius.circular(18),
              splashColor: Colors.white.withOpacity(0.16),
              highlightColor: Colors.white.withOpacity(0.06),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.label,
                      style: tt.labelLarge?.copyWith(
                        color: atlas.textPrimary,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: atlas.textPrimary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RouteNetworkPainter extends CustomPainter {
  final double time;
  final Offset pointer;
  final bool pointerActive;
  final List<_Node> nodes;
  final List<_Route> routes;
  final Color background;
  final Color accent;
  final Color divider;

  const RouteNetworkPainter({
    required this.time,
    required this.pointer,
    required this.pointerActive,
    required this.nodes,
    required this.routes,
    required this.background,
    required this.accent,
    required this.divider,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = background,
    );

    final p = pointerActive ? pointer : size.center(Offset.zero);
    final pull = pointerActive ? 1.0 : 0.25;
    final t = time * 2 * pi;

    final quietLinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = divider.withOpacity(0.7);

    final nodeFill = Paint()
      ..style = PaintingStyle.fill
      ..color = accent.withOpacity(0.20);

    final nodeRing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = accent.withOpacity(0.35);

    final traveler = Paint()
      ..style = PaintingStyle.fill
      ..color = accent.withOpacity(0.85);

    final glow = Paint()
      ..style = PaintingStyle.fill
      ..color = accent.withOpacity(0.10);

    final warped = <Offset>[];
    for (final n in nodes) {
      final base = Offset(n.x * size.width, n.y * size.height);

      final drift = Offset(
        sin(t * n.dx + n.phase) * 10,
        cos(t * n.dy + n.phase) * 10,
      );

      final toPointer = p - base;
      final d = max(1.0, toPointer.distance);
      final attract = toPointer / d * (140 / d) * 18 * pull;

      warped.add(base + drift + attract);
    }

    for (int i = 0; i < 3; i++) {
      final center = Offset(
        size.width * (0.25 + i * 0.28) + sin(t + i) * 10,
        size.height * (0.20 + i * 0.22) + cos(t + i) * 10,
      );
      canvas.drawCircle(center, 120 + i * 24, glow);
    }

    for (int i = 0; i < routes.length; i++) {
      final r = routes[i];
      final a = warped[r.a];
      final b = warped[r.b];

      final mid = (a + b) / 2;
      final bend = Offset(
        sin(t * 0.8 + r.phase) * 14,
        cos(t * 0.8 + r.phase) * 14,
      );

      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(mid.dx + bend.dx, mid.dy + bend.dy, b.dx, b.dy);

      final pulse = (sin(t * 1.2 + r.phase) + 1) / 2;
      final linePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = i.isEven
            ? accent.withOpacity(0.28 + 0.20 * pulse)
            : quietLinePaint.color;

      canvas.drawPath(path, linePaint);

      if (i.isEven) {
        final travelerT = (time + r.phase) % 1.0;
        final pos = _pointOnQuadratic(a, mid + bend, b, travelerT);
        canvas.drawCircle(pos, 2.2 + pulse * 0.8, traveler);
      }
    }

    for (int i = 0; i < warped.length; i++) {
      final pos = warped[i];
      final radius = 5.2 + (sin(t + nodes[i].phase) + 1) * 0.8;
      canvas.drawCircle(pos, radius, nodeFill);
      canvas.drawCircle(pos, radius + 3.0, nodeRing);
    }

    final vignette = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          background.withOpacity(0.55),
        ],
        stops: const [0.55, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Offset.zero & size, vignette);
  }

  Offset _pointOnQuadratic(Offset p0, Offset p1, Offset p2, double t) {
    final u = 1 - t;
    return (p0 * (u * u)) + (p1 * (2 * u * t)) + (p2 * (t * t));
  }

  @override
  bool shouldRepaint(covariant RouteNetworkPainter oldDelegate) {
    return oldDelegate.time != time ||
        oldDelegate.pointer != pointer ||
        oldDelegate.pointerActive != pointerActive ||
        oldDelegate.nodes != nodes ||
        oldDelegate.routes != routes ||
        oldDelegate.background != background ||
        oldDelegate.accent != accent ||
        oldDelegate.divider != divider;
  }
}

@immutable
class _Node {
  final double x;
  final double y;
  final double dx;
  final double dy;
  final double phase;

  const _Node({
    required this.x,
    required this.y,
    required this.dx,
    required this.dy,
    required this.phase,
  });
}

@immutable
class _Route {
  final int a;
  final int b;
  final double phase;

  const _Route({
    required this.a,
    required this.b,
    required this.phase,
  });
}