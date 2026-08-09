/// models/control_item.dart
/// تمثيل موحّد لأي عنصر تحكم على الشاشة (سويتش، خزان، مؤشر جهد).
/// يُبنى تلقائياً من مصفوفة "items" التي ترسلها اللوحة (Auto-UI Protocol)،
/// أو يُبنى افتراضياً (12 سويتش + خزان + مؤشر) إن لم ترسل اللوحة شيئاً.
library;

enum ControlItemType { relaySwitch, tank, indicator, unknown }

ControlItemType parseItemType(String raw) {
  switch (raw) {
    case 'switch':
    case 'relay':
      return ControlItemType.relaySwitch;
    case 'tank':
      return ControlItemType.tank;
    case 'indicator':
      return ControlItemType.indicator;
    default:
      return ControlItemType.unknown;
  }
}

class ControlItem {
  final String id;          // مثال: relay_1
  final ControlItemType type;
  final int? relayIndex;    // فقط للسويتشات (0-based) — يُستخدم بالأوامر
  num value;                // true/false كـ 1/0 للسويتش، نسبة % للخزان، إلخ
  final num? updatedAt;

  // إعدادات قابلة للتخصيص من المستخدم (تُخزَّن في RTDB منفصلة عن الحالة)
  String displayName;
  int colorValue; // ARGB كرقم — لتفادي الاعتماد على نوع Color مباشرة بالنموذج

  ControlItem({
    required this.id,
    required this.type,
    this.relayIndex,
    required this.value,
    this.updatedAt,
    required this.displayName,
    required this.colorValue,
  });

  bool get boolValue => value == 1 || value == true;

  factory ControlItem.fromCapabilityJson(Map<String, dynamic> json) {
    final type = parseItemType(json['type'] as String? ?? '');
    final id = json['id'] as String? ?? '';
    return ControlItem(
      id: id,
      type: type,
      relayIndex: json['index'] as int?,
      value: (json['value'] ?? json['state'] ?? 0) as num,
      displayName: _defaultNameFor(id, type),
      colorValue: 0xFF2196F3, // أزرق افتراضي
    );
  }

  static String _defaultNameFor(String id, ControlItemType type) {
    switch (type) {
      case ControlItemType.tank:
        return 'خزان المياه';
      case ControlItemType.indicator:
        return 'جهد الشبكة';
      case ControlItemType.relaySwitch:
        final n = id.replaceAll('relay_', '');
        return 'سويتش $n';
      default:
        return id;
    }
  }
}
