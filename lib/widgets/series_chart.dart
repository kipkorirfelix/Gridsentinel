import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class SeriesChart extends StatelessWidget {
  const SeriesChart({
    super.key,
    required this.values,
    required this.color,
    this.highlight = const {},
    this.height = 260,
  });
  final List<double> values;
  final Color color;
  final Set<int> highlight;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) {
      return SizedBox(height: height, child: const Center(child: Text('Waiting for data...')));
    }
    final step = max(1, (values.length / 400).ceil());
    final spots = <FlSpot>[];
    for (var i = 0; i < values.length; i++) {
      if (i % step == 0 || highlight.contains(i)) spots.add(FlSpot(i.toDouble(), values[i]));
    }
    var lo = values.reduce(min);
    var hi = values.reduce(max);
    final pad = (hi - lo).abs() * 0.15 + 0.001;
    lo -= pad;
    hi += pad;
    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (values.length - 1).toDouble(),
          minY: lo,
          maxY: hi,
          gridData: FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 52)),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              color: color,
              barWidth: 2,
              dotData: FlDotData(
                show: highlight.isNotEmpty,
                checkToShowDot: (s, b) => highlight.contains(s.x.toInt()),
                getDotPainter: (s, p, b, i) =>
                    FlDotCirclePainter(radius: 4, color: Colors.redAccent, strokeWidth: 0),
              ),
              belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.12)),
            ),
          ],
        ),
      ),
    );
  }
}