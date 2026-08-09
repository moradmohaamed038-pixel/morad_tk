/// widgets/relay_switch_card.dart
library;

import 'package:flutter/material.dart';
import '../models/control_item.dart';

class RelaySwitchCard extends StatelessWidget {
  final ControlItem item;
  final ValueChanged<bool> onToggle;
  final VoidCallback onSettingsTap;

  const RelaySwitchCard({
    super.key,
    required this.item,
    required this.onToggle,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(item.colorValue);
    final isOn = item.boolValue;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => onToggle(!isOn),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.tune, size: 18),
                    onPressed: onSettingsTap,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'إعدادات السويتش',
                  ),
                ],
              ),
              const Spacer(),
              Icon(
                Icons.power_settings_new,
                size: 32,
                color: isOn ? color : Colors.grey.shade400,
              ),
              const SizedBox(height: 8),
              Text(
                item.displayName,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Switch(
                  value: isOn,
                  activeColor: color,
                  onChanged: onToggle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
