import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class PortfolioChart extends StatelessWidget {
  final Map<String, double> assetAllocation;

  const PortfolioChart({
    super.key,
    required this.assetAllocation,
  });

  @override
  Widget build(BuildContext context) {
    if (assetAllocation.isEmpty) {
      return const Center(
        child: Text('No data available'),
      );
    }

    final total = assetAllocation.values.fold(0.0, (sum, value) => sum + value);
    final sections = _createPieChartSections(context, total);

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 40,
              sectionsSpace: 2,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildLegend(context, total),
        ),
      ],
    );
  }

  List<PieChartSectionData> _createPieChartSections(BuildContext context, double total) {
    final colors = [
      Theme.of(context).colorScheme.primary,
      Theme.of(context).colorScheme.secondary,
      Theme.of(context).colorScheme.tertiary,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
    ];

    return assetAllocation.entries.map((entry) {
      final index = assetAllocation.keys.toList().indexOf(entry.key);
      final percentage = (entry.value / total) * 100;
      
      return PieChartSectionData(
        value: entry.value,
        title: '${percentage.toStringAsFixed(1)}%',
        color: colors[index % colors.length],
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Widget _buildLegend(BuildContext context, double total) {
    final colors = [
      Theme.of(context).colorScheme.primary,
      Theme.of(context).colorScheme.secondary,
      Theme.of(context).colorScheme.tertiary,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: assetAllocation.entries.map((entry) {
        final index = assetAllocation.keys.toList().indexOf(entry.key);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: colors[index % colors.length],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.key,
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
