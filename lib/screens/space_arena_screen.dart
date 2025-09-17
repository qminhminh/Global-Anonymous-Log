import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/space_provider.dart';

class SpaceArenaScreen extends StatefulWidget {
  const SpaceArenaScreen({super.key});

  @override
  State<SpaceArenaScreen> createState() => _SpaceArenaScreenState();
}

class _SpaceArenaScreenState extends State<SpaceArenaScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _starsCtrl;
  final Random _rnd = Random();
  double _playerX = 0.5; // 0..1
  final List<Offset> _bullets = <Offset>[]; // 0..1 (x,y)
  final List<Offset> _meteors = <Offset>[]; // 0..1 (x,y)
  int _score = 0;
  bool _alive = true;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _starsCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
    _spawnInitial();
    _ticker = Timer.periodic(const Duration(milliseconds: 16), (_) => _tick());
  }

  void _spawnInitial() {
    _meteors.clear();
    for (int i = 0; i < 6; i++) {
      _meteors.add(Offset(_rnd.nextDouble(), _rnd.nextDouble() * 0.5));
    }
  }

  void _tick() {
    if (!_alive) return;
    // Move bullets up
    for (int i = 0; i < _bullets.length; i++) {
      final b = _bullets[i];
      _bullets[i] = Offset(b.dx, b.dy - 0.02);
    }
    _bullets.removeWhere((b) => b.dy < -0.05);

    // Move meteors down
    for (int i = 0; i < _meteors.length; i++) {
      final m = _meteors[i];
      _meteors[i] = Offset(m.dx, m.dy + 0.006 + (i % 3) * 0.002);
    }
    // Respawn meteors
    for (int i = _meteors.length - 1; i >= 0; i--) {
      if (_meteors[i].dy > 1.1) {
        _meteors[i] = Offset(_rnd.nextDouble(), -_rnd.nextDouble() * 0.3);
      }
    }

    // Collisions bullet-meteor
    for (int i = _meteors.length - 1; i >= 0; i--) {
      final m = _meteors[i];
      bool hit = false;
      for (int j = _bullets.length - 1; j >= 0; j--) {
        final b = _bullets[j];
        if ((b - m).distance < 0.05) { // hit radius
          _bullets.removeAt(j);
          hit = true;
          _score += 10;
          break;
        }
      }
      if (hit) {
        _meteors[i] = Offset(_rnd.nextDouble(), -0.2);
      }
    }

    // Collision meteor-player
    for (final m in _meteors) {
      if ((m - Offset(_playerX, 0.92)).distance < 0.07) {
        _alive = false;
        // submit score
        if (mounted) {
          final sp = context.read<SpaceProvider>();
          sp.submitScore(_score);
        }
        break;
      }
    }

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _starsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Space Arena')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (details) {
              final dx = (details.localPosition.dx / w).clamp(0.05, 0.95);
              setState(() { _playerX = dx; });
            },
            child: Stack(fit: StackFit.expand, children: [
            AnimatedBuilder(
              animation: _starsCtrl,
              builder: (_, __) => CustomPaint(painter: _StarFieldPainter(progress: _starsCtrl.value)),
            ),
            // Meteors
            ..._meteors.map((m) {
              return Positioned(
                left: m.dx * w - 14,
                top: m.dy * h - 14,
                child: const Icon(Icons.brightness_2, size: 28, color: Colors.white70),
              );
            }),
            // Bullets
            ..._bullets.map((b) => Positioned(
              left: b.dx * w - 2,
              top: b.dy * h - 8,
              child: Container(width: 4, height: 12, decoration: BoxDecoration(color: Colors.tealAccent, borderRadius: BorderRadius.circular(2))),
            )),
            // Player ship
            Positioned(
              left: _playerX * w - 28,
              bottom: 28,
              child: const Icon(Icons.flight, size: 56, color: Colors.tealAccent),
            ),
            // HUD
            Positioned(
              left: 16,
              top: 12,
              child: Text('Score: $_score', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            if (!_alive)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Game Over', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.replay),
                      label: const Text('Play again'),
                      onPressed: () {
                        setState(() { _alive = true; _score = 0; _bullets.clear(); _spawnInitial(); });
                      },
                    )
                  ],
                ),
              ),
            // Controls
            Positioned(
              left: 16,
              bottom: 16,
              child: _circleButton(Icons.chevron_left, () => setState(() { _playerX = max(0.05, _playerX - 0.05); })),
            ),
            Positioned(
              left: 76,
              bottom: 16,
              child: _circleButton(Icons.chevron_right, () => setState(() { _playerX = min(0.95, _playerX + 0.05); })),
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: _circleButton(Icons.whatshot, () {
                if (!_alive) return;
                _bullets.add(Offset(_playerX, 0.9));
              }),
            ),
            ]),
          );
        },
      ),
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon),
      ),
    );
  }
}

class _StarFieldPainter extends CustomPainter {
  final double progress;
  _StarFieldPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width.isNaN || size.height.isNaN || size.width <= 0 || size.height <= 0) {
      return;
    }
    final paint = Paint()..color = Colors.white.withOpacity(0.25);
    const numStars = 200;
    for (int i = 0; i < numStars; i++) {
      final dx = ((i * 37) % size.width);
      double dy = ((i * 91) % size.height);
      dy = (dy + progress * size.height) % size.height;
      final radius = 0.5 + (i % 3) * 0.4;
      canvas.drawCircle(Offset(dx.toDouble(), dy.toDouble()), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarFieldPainter oldDelegate) => oldDelegate.progress != progress;
}


