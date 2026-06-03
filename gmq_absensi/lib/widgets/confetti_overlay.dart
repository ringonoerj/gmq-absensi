import 'dart:math';
import 'package:flutter/material.dart';

class ConfettiParticle {
  double x;
  double y;
  double vx;
  double vy;
  double rotation;
  double rotationSpeed;
  Color color;
  double size;
  int shape; // 0: rectangle, 1: circle, 2: triangle

  ConfettiParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.rotation,
    required this.rotationSpeed,
    required this.color,
    required this.size,
    required this.shape,
  });
}

class ConfettiOverlay extends StatefulWidget {
  final Widget child;

  const ConfettiOverlay({super.key, required this.child});

  static _ConfettiOverlayState? of(BuildContext context) {
    return context.findAncestorStateOfType<_ConfettiOverlayState>();
  }

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<ConfettiParticle> _particles = [];
  final Random _random = Random();
  bool _isPlaying = false;

  final List<Color> _colors = [
    Colors.redAccent,
    Colors.blueAccent,
    Colors.greenAccent,
    Colors.orangeAccent,
    Colors.purpleAccent,
    Colors.yellowAccent,
    Colors.pinkAccent,
    Colors.tealAccent,
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..addListener(() {
        if (_isPlaying) {
          _updateParticles();
        }
      })..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            _isPlaying = false;
            _particles.clear();
          });
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void play() {
    if (_isPlaying) {
      _controller.stop();
      _particles.clear();
    }
    
    // Generate particles bursting from top-left and top-right
    final width = MediaQuery.of(context).size.width;
    
    // Burst left
    for (int i = 0; i < 60; i++) {
      _particles.add(_createParticle(0.1 * width, 0.0, true));
    }

    // Burst right
    for (int i = 0; i < 60; i++) {
      _particles.add(_createParticle(0.9 * width, 0.0, false));
    }

    setState(() {
      _isPlaying = true;
    });
    _controller.forward(from: 0.0);
  }

  ConfettiParticle _createParticle(double startX, double startY, bool directionRight) {
    final angle = directionRight 
        ? (_random.nextDouble() * 45 + 15) * pi / 180  // angle 15 to 60 degrees down-right
        : (_random.nextDouble() * 45 + 120) * pi / 180; // angle 120 to 165 degrees down-left
    
    final speed = _random.nextDouble() * 12 + 6;
    
    return ConfettiParticle(
      x: startX,
      y: startY,
      vx: cos(angle) * speed,
      vy: sin(angle) * speed + 5, // make sure they fall down
      rotation: _random.nextDouble() * 2 * pi,
      rotationSpeed: (_random.nextDouble() - 0.5) * 0.2,
      color: _colors[_random.nextInt(_colors.length)],
      size: _random.nextDouble() * 8 + 6,
      shape: _random.nextInt(3),
    );
  }

  void _updateParticles() {
    final height = MediaQuery.of(context).size.height;
    setState(() {
      for (var p in _particles) {
        p.x += p.vx;
        p.y += p.vy;
        p.vy += 0.2; // gravity effect
        p.vx *= 0.98; // air resistance
        p.rotation += p.rotationSpeed;
      }
      // Remove particles off screen to save resources
      _particles.removeWhere((p) => p.y > height);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isPlaying)
          IgnorePointer(
            child: CustomPaint(
              size: Size.infinite,
              painter: ConfettiPainter(particles: _particles),
            ),
          ),
      ],
    );
  }
}

class ConfettiPainter extends CustomPainter {
  final List<ConfettiParticle> particles;

  ConfettiPainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (var p in particles) {
      paint.color = p.color;
      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rotation);

      if (p.shape == 0) {
        // Rectangle
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: p.size * 1.5, height: p.size),
          paint,
        );
      } else if (p.shape == 1) {
        // Circle
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        // Triangle
        final path = Path()
          ..moveTo(0, -p.size / 2)
          ..lineTo(p.size / 2, p.size / 2)
          ..lineTo(-p.size / 2, p.size / 2)
          ..close();
        canvas.drawPath(path, paint);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
