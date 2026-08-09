/// widgets/relay_settings_sheet.dart
/// كل ما يُكتب هنا يذهب لمسار /config/relays/{id} في RTDB — منفصل تماماً
/// عن مسار /state (الحالة الفعلية) و/commands (أوامر التشغيل الفورية)،
/// تماماً كما اتفقنا في تصميم المؤقتات.
library;

import 'package:flutter/material.dart';
import '../models/control_item.dart';
import '../services/firebase_service.dart';

class RelaySettingsSheet extends StatefulWidget {
  final String deviceId;
  final ControlItem item;

  const RelaySettingsSheet({super.key, required this.deviceId, required this.item});

  @override
  State<RelaySettingsSheet> createState() => _RelaySettingsSheetState();
}

class _RelaySettingsSheetState extends State<RelaySettingsSheet> {
  late TextEditingController _nameController;
  late Color _selectedColor;
  final FirebaseService _firebase = FirebaseService();

  final List<Color> _palette = const [
    Color(0xFF2196F3), Color(0xFF4CAF50), Color(0xFFFF9800),
    Color(0xFFF44336), Color(0xFF9C27B0), Color(0xFF009688),
  ];

  // مثال مبسّط لجدول أسبوعي: تفعيل يوم + وقت تشغيل/إيقاف
  final Map<String, bool> _activeDays = {
    'SU': false, 'MO': false, 'TU': false, 'WE': false,
    'TH': false, 'FR': false, 'SA': false,
  };
  TimeOfDay _onTime = const TimeOfDay(hour: 18, minute: 0);
  TimeOfDay _offTime = const TimeOfDay(hour: 22, minute: 0);
  bool _scheduleEnabled = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.displayName);
    _selectedColor = Color(widget.item.colorValue);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('إعدادات ${widget.item.displayName}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            const Text('الاسم', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
            ),
            const SizedBox(height: 16),

            const Text('اللون', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              children: _palette.map((c) {
                final selected = c.value == _selectedColor.value;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = c),
                  child: CircleAvatar(
                    backgroundColor: c,
                    radius: selected ? 18 : 14,
                    child: selected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('تفعيل مؤقت أسبوعي', style: TextStyle(fontWeight: FontWeight.w600)),
              value: _scheduleEnabled,
              onChanged: (v) => setState(() => _scheduleEnabled = v),
            ),

            if (_scheduleEnabled) ...[
              Wrap(
                spacing: 6,
                children: _activeDays.keys.map((day) {
                  final active = _activeDays[day]!;
                  return FilterChip(
                    label: Text(_dayLabel(day)),
                    selected: active,
                    onSelected: (v) => setState(() => _activeDays[day] = v),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('وقت التشغيل'),
                      subtitle: Text(_onTime.format(context)),
                      onTap: () async {
                        final t = await showTimePicker(context: context, initialTime: _onTime);
                        if (t != null) setState(() => _onTime = t);
                      },
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('وقت الإيقاف'),
                      subtitle: Text(_offTime.format(context)),
                      onTap: () async {
                        final t = await showTimePicker(context: context, initialTime: _offTime);
                        if (t != null) setState(() => _offTime = t);
                      },
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 20),
            FilledButton(
              onPressed: _save,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('حفظ'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _dayLabel(String code) {
    const map = {
      'SU': 'أحد', 'MO': 'اثنين', 'TU': 'ثلاثاء', 'WE': 'أربعاء',
      'TH': 'خميس', 'FR': 'جمعة', 'SA': 'سبت',
    };
    return map[code] ?? code;
  }

  Future<void> _save() async {
    final relayNumber = (widget.item.relayIndex ?? 0) + 1;
    final activeDaysList = _activeDays.entries.where((e) => e.value).map((e) => e.key).toList();

    await _firebase.saveRelayConfig(widget.deviceId, relayNumber, {
      'name': _nameController.text.trim(),
      'color': _selectedColor.value,
      'schedule_enabled': _scheduleEnabled,
      'schedule_days': activeDaysList,
      'on_time': '${_onTime.hour.toString().padLeft(2, '0')}:${_onTime.minute.toString().padLeft(2, '0')}',
      'off_time': '${_offTime.hour.toString().padLeft(2, '0')}:${_offTime.minute.toString().padLeft(2, '0')}',
    });

    widget.item.displayName = _nameController.text.trim();
    widget.item.colorValue = _selectedColor.value;

    if (mounted) Navigator.of(context).pop();
  }
}
