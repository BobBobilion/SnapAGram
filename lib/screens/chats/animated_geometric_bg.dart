import 'dart:math';
import 'package:flutter/material.dart';

class AnimatedGeometricBg extends StatefulWidget {
  final double shapeSize;
  final int shapeCount;
  final Color shapeColor;
  const AnimatedGeometricBg({
    super.key,
    this.shapeSize = 80,
    this.shapeCount = 10,
    this.shapeColor = const Color(0xFFB3E5FC), // Light blue
  });

  @override
  State<AnimatedGeometricBg> createState() => _AnimatedGeometricBgState();
}

class _AnimatedGeometricBgState extends State<AnimatedGeometricBg>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_ShapeData> _shapes;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60), // Very slow scroll
    )..repeat();
    _shapes = _generateShapes();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<_ShapeData> _generateShapes() {
    final random = Random();
    final shapes = <_ShapeData>[];
    const minDistance = 0.15; // Minimum relative distance between shapes (15% of screen)
    const maxAttempts = 50; // Maximum attempts to place each shape
    
    for (int i = 0; i < widget.shapeCount; i++) {
      _ShapeData? newShape;
      double bestDistance = 0;
      
      // Try multiple positions and pick the one with maximum distance from others
      for (int attempt = 0; attempt < maxAttempts; attempt++) {
        final candidateShape = _ShapeData(
          type: ShapeType.values[random.nextInt(ShapeType.values.length)],
          x: random.nextDouble(),
          y: -0.8 + random.nextDouble() * 0.3, // Spawn at top (-0.8 to -0.5)
          rotation: random.nextDouble() * 2 * pi,
          size: 70 + random.nextDouble() * 40,
        );
        
        // Calculate minimum distance to existing shapes
        double minDistanceToOthers = double.infinity;
        for (final existingShape in shapes) {
          final dx = candidateShape.x - existingShape.x;
          final dy = candidateShape.y - existingShape.y;
          final distance = sqrt(dx * dx + dy * dy);
          minDistanceToOthers = min(minDistanceToOthers, distance);
        }
        
        // If this position is better (farther from others), use it
        if (minDistanceToOthers > bestDistance) {
          bestDistance = minDistanceToOthers;
          newShape = candidateShape;
        }
        
        // If we found a position with sufficient distance, stop trying
        if (bestDistance >= minDistance) {
          break;
        }
      }
      
      // Add the best shape we found (or null if no good position was found)
      if (newShape != null && (shapes.isEmpty || bestDistance >= minDistance * 0.7)) {
        shapes.add(newShape);
      }
    }
    
    return shapes;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _GeometricBgPainter(
            shapes: _shapes,
            progress: _controller.value,
            shapeColor: widget.shapeColor,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

enum ShapeType { triangle, square, circle, pentagon, hexagon }

class _ShapeData {
  final ShapeType type;
  final double x; // 0..1 (relative to width)
  final double y; // 0..1 (relative to height)
  final double rotation;
  final double size;
  _ShapeData({
    required this.type,
    required this.x,
    required this.y,
    required this.rotation,
    required this.size,
  });
}

class _GeometricBgPainter extends CustomPainter {
  final List<_ShapeData> shapes;
  final double progress; // 0..1
  final Color shapeColor;

  _GeometricBgPainter({
    required this.shapes,
    required this.progress,
    required this.shapeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = shapeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final double scroll = progress * size.height;
    for (final s in shapes) {
      final double x = s.x * (size.width - s.size) + s.size / 2;
      double y = (s.y * (size.height + s.size * 3)) + scroll - s.size / 2;
      y = y % (size.height + s.size * 3); // Loop with much more space above
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(s.rotation);
      _drawShape(canvas, paint, s.type, s.size);
      canvas.restore();
    }
  }

  void _drawShape(Canvas canvas, Paint paint, ShapeType type, double size) {
    switch (type) {
      case ShapeType.triangle:
        _drawRoundedPolygon(canvas, paint, 3, size);
        break;
      case ShapeType.square:
        _drawRoundedPolygon(canvas, paint, 4, size);
        break;
      case ShapeType.circle:
        canvas.drawCircle(Offset.zero, size / 2, paint);
        break;
      case ShapeType.pentagon:
        _drawRoundedPolygon(canvas, paint, 5, size);
        break;
      case ShapeType.hexagon:
        _drawStar(canvas, paint, size);
        break;
    }
  }

  // Draws a regular polygon with mathematically correct rounded corners
  void _drawRoundedPolygon(Canvas canvas, Paint paint, int sides, double size) {
    final r = size / 2;
    final angle = 2 * pi / sides;
    final points = List.generate(sides, (i) {
      final x = r * cos(i * angle - pi / 2);
      final y = r * sin(i * angle - pi / 2);
      return Offset(x, y);
    });
    // Internal angle at each corner
    final internalAngle = pi - (2 * pi / sides);
    // Choose a roundness (distance along each edge from the corner)
    final roundness = size * 0.08; // Smaller rounded corners
    // Calculate the arc radius so that the arc subtends the internal angle
    final arcRadius = roundness * tan(internalAngle / 2);
    final path = Path();
    for (int i = 0; i < sides; i++) {
      final prev = points[(i - 1 + sides) % sides];
      final curr = points[i];
      final next = points[(i + 1) % sides];
      // Directions
      final dirToPrev = (prev - curr).direction;
      final dirToNext = (next - curr).direction;
      // Start/end points for the arc
      final start = curr + Offset.fromDirection(dirToPrev, roundness);
      final end = curr + Offset.fromDirection(dirToNext, roundness);
      if (i == 0) {
        path.moveTo(start.dx, start.dy);
      } else {
        path.lineTo(start.dx, start.dy);
      }
      // Draw arc at the corner
      path.arcToPoint(
        end,
        radius: Radius.circular(arcRadius.abs()),
        clockwise: true,
        largeArc: false,
      );
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  // Helper to draw a 5-pointed star
  void _drawStar(Canvas canvas, Paint paint, double size) {
    const int points = 5;
    final double rOuter = size / 2;
    final double rInner = rOuter * 0.45;
    final path = Path();
    for (int i = 0; i < points * 2; i++) {
      final isOuter = i.isEven;
      final r = isOuter ? rOuter : rInner;
      final angle = (pi / points) * i - pi / 2;
      final x = r * cos(angle);
      final y = r * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _GeometricBgPainter oldDelegate) => true;
} 