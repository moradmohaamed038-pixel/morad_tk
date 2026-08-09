/// screens/my_devices_screen.dart
library;

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/device_registry_service.dart';
import 'add_device_screen.dart';
import 'control_screen.dart';

class MyDevicesScreen extends StatefulWidget {
  const MyDevicesScreen({super.key});

  @override
  State<MyDevicesScreen> createState() => _MyDevicesScreenState();
}

class _MyDevicesScreenState extends State<MyDevicesScreen> {
  final _auth = AuthService();
  final _registry = DeviceRegistryService();

  Future<void> _openAddDevice() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddDeviceScreen()),
    );
    // لا حاجة لتحديث يدوي — myDeviceIdsStream بث حي يتحدّث تلقائياً بعد
    // نجاح claimDevice، added هنا فقط لعرض رسالة تأكيد اختيارية إن أردت
    if (added == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت إضافة اللوحة بنجاح')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحاتي — MORAD_TK'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _auth.signOut),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddDevice,
        icon: const Icon(Icons.add),
        label: const Text('إضافة لوحة'),
      ),
      body: StreamBuilder<List<String>>(
        stream: _registry.myDeviceIdsStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final deviceIds = snapshot.data!;
          if (deviceIds.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.developer_board, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('لا توجد لوحات بحسابك بعد'),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _openAddDevice, child: const Text('إضافة أول لوحة')),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: deviceIds.length,
            itemBuilder: (context, index) {
              final id = deviceIds[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.developer_board),
                  title: Text(id),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ControlScreen(deviceId: id)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
