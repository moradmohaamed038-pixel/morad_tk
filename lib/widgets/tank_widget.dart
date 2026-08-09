/// widgets/tank_widget.dart
library;

import 'package:flutter/material.dart';
import '../models/control_item.dart';

class TankWidget extends StatelessWidget {
  final ControlItem item;
  final VoidCallback onSettingsTap;

  const TankWidget({super.key, required this.item, required this.onSettingsTap});

  @override
  Widget build(BuildContext context) {
    final level = item.value.clamp(0, 100) / 100.0;
    final color = Color(item.colorValue);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
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
            const SizedBox(height: 8),
            SizedBox(
              width: 70,
              height: 110,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400, width: 2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: FractionallySizedBox(
                      heightFactor: level.toDouble(),
                      widthFactor: 1,
                      child: Container(color: color.withOpacity(0.75)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text('${item.value.toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
