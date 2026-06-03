import 'dart:math';
import 'package:flutter/material.dart';

const Color slate800 = Color(0xFF1E293B);
const Color slate700 = Color(0xFF334155);
const Color slate500 = Color(0xFF64748B);


class DashboardChart extends StatefulWidget {
  final List<double> values;
  final List<String> labels;
  final List<Color> colors;

  const DashboardChart({
    super.key,
    required this.values,
    required this.labels,
    required this.colors,
  });

  @override
  State<DashboardChart> createState() => _DashboardChartState();
}

class _DashboardChartState extends State<DashboardChart> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _chartAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _chartAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.fastOutSlowIn),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? (isDark ? const Color(0xFF1E293B) : Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.withOpacity(0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.15 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Proporsi Distribusi Data',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : slate800,
                ),
              ),
              Icon(
                Icons.analytics_outlined,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              // Radial/Donut custom paint chart
              SizedBox(
                width: 140,
                height: 140,
                child: AnimatedBuilder(
                  animation: _chartAnimation,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: DonutChartPainter(
                        values: widget.values,
                        colors: widget.colors,
                        progress: _chartAnimation.value,
                        isDark: isDark,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 24),
              // Legend
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(widget.labels.length, (index) {
                    final total = widget.values.fold<double>(0, (sum, v) => sum + v);
                    final percentage = total > 0 
                        ? (widget.values[index] / total * 100).toStringAsFixed(1)
                        : '0.0';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: widget.colors[index],
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.labels[index],
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.grey.shade300 : slate700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '$percentage%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.grey.shade400 : slate500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DonutChartPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  final double progress;
  final bool isDark;

  DonutChartPainter({
    required this.values,
    required this.colors,
    required this.progress,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double total = values.fold(0, (sum, item) => sum + item);
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2);
    final strokeWidth = radius * 0.35;
    
    // Draw background tracks for rings
    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03);
    
    canvas.drawCircle(center, radius - strokeWidth / 2, bgPaint);

    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);
    double startAngle = -pi / 2;

    for (int i = 0; i < values.length; i++) {
      final sweepAngle = (values[i] / total) * 2 * pi * progress;
      
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = colors[i]
        ..strokeCap = StrokeCap.round;

      // Draw active segment
      canvas.drawArc(rect, startAngle + 0.05, sweepAngle - 0.08, false, paint);
      startAngle += (values[i] / total) * 2 * pi;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
