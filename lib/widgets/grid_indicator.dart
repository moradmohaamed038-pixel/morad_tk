/// widgets/grid_indicator.dart
library;

import 'package:flutter/material.dart';
import '../models/control_item.dart';

class GridIndicatorWidget extends StatelessWidget {
  final ControlItem item;
  final VoidCallback onSettingsTap;

  const GridIndicatorWidget({super.key, required this.item, required this.onSettingsTap});

  @override
  Widget build(BuildContext context) {
    final isOk = item.boolValue;
    final color = isOk ? Colors.green : Colors.red;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(item.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                IconButton(
                  icon: const Icon(Icons.tune, size: 18),
                  onPressed: onSettingsTap,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Icon(Icons.bolt, size: 40, color: color),
            const SizedBox(height: 4),
            Text(isOk ? 'متوفر' : 'مقطوع', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
