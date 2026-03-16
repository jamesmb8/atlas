// lib/main.dart
import 'dart:math';
import 'dart:ui';

import 'package:atlas/features/auth/screens/signupnamescreen.dart';
import 'package:flutter/material.dart';

import '../../features/auth/screens/loginscreen.dart';

void main() => runApp(const AtlasApp());

@immutable
class AtlasPalette {
  static const background = Color(0xFFF7F6F2);
  static const primaryText = Color(0xFF1F1F1F);
  static const secondaryText = Color(0xFF6B6E6A);
  static const accent = Color(0xFF9FC8B2);
  static const divider = Color(0xFFE3E4DE);
}

class AtlasApp extends StatelessWidget {
  const AtlasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Atlas',
      theme: _theme(),
      home: const LandingScreen(),
    );
  }

  ThemeData _theme() {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.light);

    return base.copyWith(
      scaffoldBackgroundColor: AtlasPalette.background,
      textTheme: base.textTheme.copyWith(
        headlineLarge: const TextStyle(
          fontFamily: 'LINESeedJP',
          fontWeight: FontWeight.w400,
          fontSize: 44,
          height: 1.00,
          color: AtlasPalette.primaryText,
          letterSpacing: -0.2,
        ),
        bodyLarge: const TextStyle(
          fontFamily: 'LINESeedJP',
          fontWeight: FontWeight.w400,
          fontSize: 16,
          height: 1.35,
          color: AtlasPalette.primaryText,
        ),
        bodyMedium: const TextStyle(
          fontFamily: 'LINESeedJP',
          fontWeight: FontWeight.w400,
          fontSize: 14,
          height: 1.35,
          color: AtlasPalette.secondaryText,
        ),
        labelLarge: const TextStyle(
          fontFamily: 'LINESeedJP',
          fontWeight: FontWeight.w400,
          fontSize: 16,
          height: 1.1,
        ),
      ),
    );
  }
}

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t;
  Offset _pointer = Offset.zero;
  bool _hasPointer = false;

  @override
  void initState() {
    super.initState();
    _t = AnimationController(vsync: this, duration: const Duration(seconds: 10))
      ..repeat();
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanDown: (d) => _setPointer(d.localPosition, true),
        onPanUpdate: (d) => _setPointer(d.localPosition, true),
        onPanEnd: (_) => _setPointer(Offset.zero, false),
        onTapDown: (d) => _setPointer(d.localPosition, true),
        onTapUp: (_) => _setPointer(Offset.zero, false),
        onTapCancel: () => _setPointer(Offset.zero, false),
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _t,
                builder: (context, _) {
                  return CustomPaint(
                    painter: RouteNetworkPainter(
                      time: _t.value,
                      pointer: _pointer,
                      pointerActive: _hasPointer,
                    ),
                  );
                },
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
                                color:
                                AtlasPalette.primaryText.withOpacity(0.88),
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
                                    color: AtlasPalette.primaryText,
                                    fontWeight: FontWeight.w400,
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
      MaterialPageRoute(builder: (_) => const SignUpNameScreen())
    );
  }
}

class _PrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  const _PrimaryButton({required this.label, required this.onPressed});

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

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
            color: AtlasPalette.accent,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                blurRadius: 14,
                offset: const Offset(0, 8),
                color: AtlasPalette.accent.withOpacity(0.28),
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
                padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.label,
                      style: tt.labelLarge?.copyWith(
                        color: AtlasPalette.primaryText,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded,
                        size: 18, color: AtlasPalette.primaryText),
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
  final double time; // 0..1 repeating
  final Offset pointer;
  final bool pointerActive;

  RouteNetworkPainter({
    required this.time,
    required this.pointer,
    required this.pointerActive,
  });

  static const int _nodeCount = 22;
  static const int _routeCount = 28;

  final _rand = Random(42);

  List<_Node>? _nodesCache;
  List<_Route>? _routesCache;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = AtlasPalette.background,
    );

    final nodes = _nodes(size);
    final routes = _routes(nodes);

    final p = pointerActive ? pointer : size.center(Offset.zero);
    final pull = pointerActive ? 1.0 : 0.25;

    final t = time * 2 * pi;

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = AtlasPalette.accent.withOpacity(0.38);

    final quietLinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = AtlasPalette.divider.withOpacity(0.7);

    final nodeFill = Paint()
      ..style = PaintingStyle.fill
      ..color = AtlasPalette.accent.withOpacity(0.20);

    final nodeRing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = AtlasPalette.accent.withOpacity(0.35);

    final traveler = Paint()
      ..style = PaintingStyle.fill
      ..color = AtlasPalette.accent.withOpacity(0.85);

    final glow = Paint()
      ..style = PaintingStyle.fill
      ..color = AtlasPalette.accent.withOpacity(0.10);

    final warped = <Offset>[];
    for (final n in nodes) {
      final base = Offset(n.x * size.width, n.y * size.height);

      final drift = Offset(
        sin(t * n.dx + n.phase) * 10,
        cos(t * n.dy + n.phase) * 10,
      );

      final toPointer = (p - base);
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
      final paint = (i % 3 == 0)
          ? (linePaint
        ..color = AtlasPalette.accent.withOpacity(0.28 + 0.20 * pulse))
          : quietLinePaint;

      canvas.drawPath(path, paint);

      if (i % 2 == 0) {
        final tt = (time + r.phase) % 1.0;
        final pos = _pointOnQuadratic(a, mid + bend, b, tt);
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
          AtlasPalette.background.withOpacity(0.55),
        ],
        stops: const [0.55, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Offset.zero & size, vignette);
  }

  List<_Node> _nodes(Size size) {
    if (_nodesCache != null) return _nodesCache!;
    final nodes = <_Node>[];

    for (int i = 0; i < _nodeCount; i++) {
      nodes.add(
        _Node(
          x: _rand.nextDouble(),
          y: _rand.nextDouble(),
          dx: 0.6 + _rand.nextDouble() * 1.2,
          dy: 0.6 + _rand.nextDouble() * 1.2,
          phase: _rand.nextDouble() * 2 * pi,
        ),
      );
    }

    for (int i = 0; i < nodes.length; i++) {
      nodes[i] = nodes[i].clamped(0.08, 0.92);
    }

    _nodesCache = nodes;
    return nodes;
  }

  List<_Route> _routes(List<_Node> nodes) {
    if (_routesCache != null) return _routesCache!;

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

      final neighbors = min(2, dists.length);
      for (int k = 0; k < neighbors; k++) {
        routes.add(_Route(a: i, b: dists[k].j, phase: _rand.nextDouble()));
      }
    }

    while (routes.length < _routeCount) {
      final a = _rand.nextInt(nodes.length);
      final b = _rand.nextInt(nodes.length);
      if (a == b) continue;
      routes.add(_Route(a: a, b: b, phase: _rand.nextDouble()));
    }

    _routesCache = routes;
    return routes;
  }

  Offset _pointOnQuadratic(Offset p0, Offset p1, Offset p2, double t) {
    final u = 1 - t;
    return (p0 * (u * u)) + (p1 * (2 * u * t)) + (p2 * (t * t));
  }

  @override
  bool shouldRepaint(covariant RouteNetworkPainter oldDelegate) {
    return oldDelegate.time != time ||
        oldDelegate.pointer != pointer ||
        oldDelegate.pointerActive != pointerActive;
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

  _Node clamped(double min, double max) {
    return _Node(
      x: x.clamp(min, max),
      y: y.clamp(min, max),
      dx: dx,
      dy: dy,
      phase: phase,
    );
  }
}

@immutable
class _Route {
  final int a;
  final int b;
  final double phase; // 0..1

  const _Route({required this.a, required this.b, required this.phase});
}
