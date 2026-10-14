import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models.dart';

const channelColors = [
  Color(0xFF58A6FF),
  Color(0xFFFFB454),
  Color(0xFFFF6B6B),
  Color(0xFF3DDC97),
];

Color severityColor(String s) {
  switch (s) {
    case 'Critical':
      return Colors.red.shade400;
    case 'High':
      return Colors.orange.shade400;
    default:
      return Colors.amber.shade400;
  }
}

String fmtValue(int ch, double v) => v.toStringAsFixed(ch == 1 ? 0 : (ch == 2 ? 2 : 1));

void toast(BuildContext c, String m) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

Future<void> confirmClearAlerts(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Clear alert history?'),
      content: const Text('This cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Clear')),
      ],
    ),
  );
  if (ok == true) await appState.clearAlerts();
}

class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.label, required this.value, this.color, this.width = 170});
  final String label;
  final String value;
  final Color? color;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 6),
              Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

class ChannelChips extends StatelessWidget {
  const ChannelChips({super.key, required this.selected, required this.onSelected});
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        for (var i = 0; i < 4; i++)
          ChoiceChip(
            label: Text(channelShort[i]),
            selected: selected == i,
            onSelected: (_) => onSelected(i),
          ),
      ],
    );
  }
}