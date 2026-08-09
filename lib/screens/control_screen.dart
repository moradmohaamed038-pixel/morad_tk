/// screens/control_screen.dart
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/control_item.dart';
import '../providers/device_provider.dart';
import '../widgets/status_bar.dart';
import '../widgets/relay_switch_card.dart';
import '../widgets/tank_widget.dart';
import '../widgets/grid_indicator.dart';
import '../widgets/relay_settings_sheet.dart';

class ControlScreen extends StatefulWidget {
  final String deviceId;

  const ControlScreen({super.key, required this.deviceId});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  late DeviceProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = DeviceProvider();
    _provider.initForDevice(widget.deviceId);
  }

  void _openSettings(ControlItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => RelaySettingsSheet(deviceId: widget.deviceId, item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Consumer<DeviceProvider>(
        builder: (context, provider, _) {
          return Scaffold(
            appBar: AppBar(title: Text('لوحة ${provider.deviceId}')),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: StatusBar(status: provider.status),
                ),
                if (provider.showLocalInstabilityWarning)
                  MaterialBanner(
                    content: const Text('الاتصال المحلي غير مستقر، التحكم يتم عبر السحابة حالياً'),
                    actions: [
                      TextButton(
                        onPressed: provider.dismissInstabilityWarning,
                        child: const Text('حسناً'),
                      ),
                    ],
                  ),
                Expanded(
                  child: provider.items.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.85,
                          ),
                          itemCount: provider.items.length,
                          itemBuilder: (context, index) {
                            final item = provider.items[index];
                            switch (item.type) {
                              case ControlItemType.relaySwitch:
                                return RelaySwitchCard(
                                  item: item,
                                  onToggle: (v) => provider.sendRelayCommand(item.relayIndex ?? 0, v),
                                  onSettingsTap: () => _openSettings(item),
                                );
                              case ControlItemType.tank:
                                return TankWidget(item: item, onSettingsTap: () => _openSettings(item));
                              case ControlItemType.indicator:
                                return GridIndicatorWidget(item: item, onSettingsTap: () => _openSettings(item));
                              default:
                                return const SizedBox.shrink();
                            }
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }
}
