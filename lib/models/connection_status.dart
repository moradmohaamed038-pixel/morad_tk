/// models/connection_status.dart
/// الخانات الثلاث المستقلة تماماً كما اتفقنا:
///   1) isLocalConnected  — WebSocket مباشر مع اللوحة (نفس شبكة الراوتر)
///   2) isCloudConnected  — اتصال هاتف المستخدم بسيرفر Firebase (.info/connected)
///   3) isDeviceOnline    — هل اللوحة نفسها متصلة (يُحسب من last_seen + heartbeat)
/// كل خانة تُحدَّث من مصدر مختلف تماماً ولا تؤثر إحداها على الأخرى.
library;

class ConnectionStatus {
  final bool isLocalConnected;
  final bool isCloudConnected;
  final bool isDeviceOnline;

  const ConnectionStatus({
    this.isLocalConnected = false,
    this.isCloudConnected = false,
    this.isDeviceOnline = false,
  });

  ConnectionStatus copyWith({
    bool? isLocalConnected,
    bool? isCloudConnected,
    bool? isDeviceOnline,
  }) {
    return ConnectionStatus(
      isLocalConnected: isLocalConnected ?? this.isLocalConnected,
      isCloudConnected: isCloudConnected ?? this.isCloudConnected,
      isDeviceOnline: isDeviceOnline ?? this.isDeviceOnline,
    );
  }

  /// المسار الذي سيُستخدم فعلياً لإرسال الأوامر — القاعدة: المحلي دائماً أولاً
  bool get canSendCommands => isLocalConnected || isCloudConnected;
}
