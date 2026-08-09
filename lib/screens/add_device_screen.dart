/// screens/add_device_screen.dart
library;

import 'package:flutter/material.dart';
import '../services/mdns_discovery_service.dart';
import '../services/device_registry_service.dart';
import '../models/discovered_device.dart';

class AddDeviceScreen extends StatefulWidget {
  const AddDeviceScreen({super.key});

  @override
  State<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  final _discovery = MdnsDiscoveryService();
  final _registry = DeviceRegistryService();

  final _deviceIdController = TextEditingController();
  final _pinController = TextEditingController();

  List<DiscoveredDevice> _nearby = [];
  bool _scanning = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scanNearby();
  }

  Future<void> _scanNearby() async {
    setState(() => _scanning = true);
    try {
      final results = await _discovery.scan();
      setState(() => _nearby = results);
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _submit() async {
    final deviceId = _deviceIdController.text.trim();
    final pin = _pinController.text.trim();

    if (deviceId.isEmpty || pin.isEmpty) {
      setState(() => _error = 'يجب إدخال معرّف اللوحة ورمز الإقران معاً.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final error = await _registry.claimDevice(deviceId, pin);

    if (!mounted) return;
    setState(() => _submitting = false);

    if (error == null) {
      Navigator.of(context).pop(true); // نجاح — أخبر الشاشة السابقة لتُحدّث القائمة
    } else {
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إضافة لوحة جديدة')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'رمز الإقران (PIN) مكوّن من 6 أرقام يظهر مرة واحدة فقط في شاشة إعداد '
            'اللوحة الأولى (Serial Monitor أو ملصق اللوحة). أدخله هنا لإثبات أنك '
            'تملك اللوحة فعلياً.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),

          TextField(
            controller: _deviceIdController,
            decoration: const InputDecoration(
              labelText: 'معرّف اللوحة (Device ID)',
              hintText: 'morad-a1b2c3d4e5f6',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'رمز الإقران (PIN)',
              border: OutlineInputBorder(),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],

          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: _submitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('ربط اللوحة بحسابي'),
            ),
          ),

          const SizedBox(height: 32),
          Row(
            children: [
              const Text('لوحات على نفس الشبكة الآن', style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(
                icon: _scanning
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh),
                onPressed: _scanning ? null : _scanNearby,
              ),
            ],
          ),
          const Text(
            'اختيارية فقط لتعبئة المعرّف تلقائياً — لا تُغني عن إدخال رمز الإقران.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          ..._nearby.map((d) => Card(
                child: ListTile(
                  leading: const Icon(Icons.developer_board),
                  title: Text(d.deviceId),
                  subtitle: Text(d.ip),
                  onTap: () => setState(() => _deviceIdController.text = d.deviceId),
                ),
              )),
        ],
      ),
    );
  }
}
