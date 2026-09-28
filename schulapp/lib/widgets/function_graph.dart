import 'dart:math' as math;
import 'package:flutter/material.dart';

class FunctionGraphPainter extends CustomPainter {
  final String graphType;
  final List<dynamic>? graphPoints;
  final List<dynamic>? graphLines;
  final Color lineColor;
  FunctionGraphPainter({required this.graphType, this.graphPoints, this.graphLines, this.lineColor = Colors.blue});
  List<math.Point<double>> _parsePoints(dynamic rawPoints) {
    if (rawPoints is! List) return [];
    return rawPoints
        .whereType<List<dynamic>>()
        .where((point) => point.length >= 2)
        .map((point) => math.Point<double>(
              (point[0] as num).toDouble(),
              (point[1] as num).toDouble(),
            ))
        .toList();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final axisPaint = Paint()
      ..color = Colors.grey.shade600
      ..strokeWidth = 1;
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    canvas.drawLine(Offset(0, centerY), Offset(size.width, centerY), axisPaint);
    canvas.drawLine(Offset(centerX, 0), Offset(centerX, size.height), axisPaint);

    if (graphLines != null && graphLines!.isNotEmpty) {
      final lines = graphLines!.map(_parsePoints).where((line) => line.isNotEmpty).toList();
      if (lines.isEmpty) return;
      final allPoints = lines.expand((line) => line).toList();
      final minX = allPoints.map((point) => point.x).reduce(math.min);
      final maxX = allPoints.map((point) => point.x).reduce(math.max);
      final minY = allPoints.map((point) => point.y).reduce(math.min);
      final maxY = allPoints.map((point) => point.y).reduce(math.max);
      final xRange = math.max(maxX - minX, 1).toDouble();
      final yRange = math.max(maxY - minY, 1).toDouble();
      final colors = [Colors.blue, Colors.red];
      for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
        final line = lines[lineIndex];
        final linePath = Path();
        final linePaint = Paint()
          ..color = colors[lineIndex % colors.length]
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke;
        for (var pointIndex = 0; pointIndex < line.length; pointIndex++) {
          final point = line[pointIndex];
          final displayX = (point.x - minX) / xRange * size.width;
          final displayY = size.height - (point.y - minY) / yRange * size.height;
          if (pointIndex == 0) {
            linePath.moveTo(displayX, displayY);
          } else {
            linePath.lineTo(displayX, displayY);
          }
        }
        canvas.drawPath(linePath, linePaint);
      }
      return;
    }
    if (graphPoints != null && graphPoints!.isNotEmpty) {
      final points = graphPoints!
          .whereType<List<dynamic>>()
          .where((point) => point.length >= 2)
          .map((point) => math.Point<double>(
                (point[0] as num).toDouble(),
                (point[1] as num).toDouble(),
              ))
          .toList();
      if (points.isEmpty) return;
      final minX = points.map((point) => point.x).reduce(math.min);
      final maxX = points.map((point) => point.x).reduce(math.max);
      final minY = points.map((point) => point.y).reduce(math.min);
      final maxY = points.map((point) => point.y).reduce(math.max);
      final xRange = math.max(maxX - minX, 1).toDouble();
      final yRange = math.max(maxY - minY, 1).toDouble();
      final pointPaint = Paint()
        ..color = lineColor
        ..style = PaintingStyle.fill;
      final pointPath = Path();
      for (var index = 0; index < points.length; index++) {
        final point = points[index];
        final displayX = (point.x - minX) / xRange * size.width;
        final displayY = size.height - (point.y - minY) / yRange * size.height;
        if (index == 0) {
          pointPath.moveTo(displayX, displayY);
        } else {
          pointPath.lineTo(displayX, displayY);
        }
        canvas.drawCircle(Offset(displayX, displayY), 4, pointPaint);
      }
      canvas.drawPath(pointPath, paint);
      return;
    }
    final path = Path();
    final scale = size.width / 10; 
    for (double x = -5; x <= 5; x += 0.1) {
      double y;
      switch (graphType) {
        case 'linear':
          y = x;
          break;
        case 'parabola':
          y = x * x / 5;
          break;
        case 'hyperbola':
          y = x == 0 ? 0 : 1 / x;
          break;
        case 'sine':
          y = math.sin(x) * 2;
          break;
        case 'exponential':
          y = math.exp(x / 3) - 1;
          break;
        default:
          y = x;
      }
      final displayX = centerX + x * scale;
      final displayY = centerY - y * scale; 
      if (x == -5) {
        path.moveTo(displayX, displayY);
      } else {
        path.lineTo(displayX, displayY);
      }
    }
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
class FunctionGraph extends StatelessWidget {
  final String graphType;
  final List<dynamic>? graphPoints;
  final List<dynamic>? graphLines;
  final double size;
  final bool isSelected;
  const FunctionGraph({
    super.key,
    required this.graphType,
    this.graphPoints,
    this.graphLines,
    this.size = 120,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? Colors.cyan : Colors.grey.shade300,
          width: isSelected ? 4 : 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CustomPaint(
          painter: FunctionGraphPainter(
            graphType: graphType,
            graphPoints: graphPoints,
            graphLines: graphLines,
          ),
        ),
      ),
    );
  }
}