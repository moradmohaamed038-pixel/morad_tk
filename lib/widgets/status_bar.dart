/// widgets/status_bar.dart
library;

import 'package:flutter/material.dart';
import '../models/connection_status.dart';

class StatusBar extends StatelessWidget {
  final ConnectionStatus status;
  const StatusBar({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _StatusChip(
          label: 'محلي',
          isOk: status.isLocalConnected,
          icon: Icons.wifi,
        ),
        _StatusChip(
          label: 'سحابة',
          isOk: status.isCloudConnected,
          icon: Icons.cloud_outlined,
        ),
        _StatusChip(
          label: 'اللوحة',
          isOk: status.isDeviceOnline,
          icon: Icons.developer_board,
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool isOk;
  final IconData icon;
  const _StatusChip({required this.label, required this.isOk, required this.icon});

  @override
  Widget build(BuildContext context) {
    final color = isOk ? Colors.green : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
