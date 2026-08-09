/// services/command_queue_service.dart
/// أوامر لم تُرسل بنجاح (لا محلي ولا سحابة) تُخزَّن هنا مؤقتاً في ذاكرة
/// التطبيق (وليس اللوحة)، وتُعاد المحاولة تلقائياً فور عودة أي اتصال.
/// أي أمر يتجاوز عمره MAX الزمني يُحذف ولا يُرسل (لأسباب أمان — راجع النقاش).
library;

import '../core/constants.dart';

class PendingCommand {
  final int relayNumber;
  final bool state;
  final DateTime timestamp;

  PendingCommand({
    required this.relayNumber,
    required this.state,
    required this.timestamp,
  });

  bool get isExpired =>
      DateTime.now().difference(timestamp).inMilliseconds >
      AppConstants.pendingCommandExpiryMs;
}

class CommandQueueService {
  final List<PendingCommand> _queue = [];

  void enqueue(int relayNumber, bool state) {
    // لو كان هناك أمر معلّق سابق لنفس الريلاي، يُستبدل بالأحدث فقط
    // (لا معنى لتنفيذ أمرين متتاليين قديمين لنفس السويتش)
    _queue.removeWhere((c) => c.relayNumber == relayNumber);
    _queue.add(PendingCommand(
      relayNumber: relayNumber,
      state: state,
      timestamp: DateTime.now(),
    ));
  }

  /// يُنظّف الطابور من الأوامر منتهية الصلاحية، ويُرجع الصالحة للتنفيذ الآن
  List<PendingCommand> drainValid() {
    _queue.removeWhere((c) => c.isExpired);
    final valid = List<PendingCommand>.from(_queue);
    _queue.clear();
    return valid;
  }

  bool get isEmpty => _queue.isEmpty;
  int get length => _queue.length;
}
