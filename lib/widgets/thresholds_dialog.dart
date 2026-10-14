import 'package:flutter/material.dart';
import '../app_state.dart';

class ThresholdsDialog extends StatefulWidget {
  const ThresholdsDialog({super.key});

  @override
  State<ThresholdsDialog> createState() => _ThresholdsDialogState();
}

class _ThresholdsDialogState extends State<ThresholdsDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.settings),
          SizedBox(width: 8),
          Text('Settings & Channel Rules'),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...appState.channelBounds.asMap().entries.map((entry) {
                final rule = entry.value;
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${rule.name} (${rule.unit})',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Switch(
                              value: rule.enabled,
                              onChanged: (v) {
                                setState(() => rule.enabled = v);
                                appState.saveChannelBounds();
                              },
                            ),
                          ],
                        ),
                        if (rule.enabled) ...[
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  decoration: const InputDecoration(labelText: 'Min Limit'),
                                  keyboardType: TextInputType.number,
                                  controller: TextEditingController(text: rule.minVal.toString()),
                                  onChanged: (v) {
                                    final num = double.tryParse(v);
                                    if (num != null) {
                                      rule.minVal = num;
                                      appState.saveChannelBounds();
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  decoration: const InputDecoration(labelText: 'Max Limit'),
                                  keyboardType: TextInputType.number,
                                  controller: TextEditingController(text: rule.maxVal.toString()),
                                  onChanged: (v) {
                                    final num = double.tryParse(v);
                                    if (num != null) {
                                      rule.maxVal = num;
                                      appState.saveChannelBounds();
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              // Footer Section
              Column(
                children: [
                  const Text(
                    'Developed by Verikey Technologies',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade400, width: 1),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.android, size: 18, color: Colors.green),
                            SizedBox(width: 5),
                            Text('Android APK', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade400, width: 1),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.desktop_windows, size: 18, color: Colors.blue),
                            SizedBox(width: 5),
                            Text('Windows EXE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
