/// core/constants.dart
/// كل القيم الثابتة بالتطبيق بمكان واحد فقط — أي تعديل مستقبلي يبدأ من هنا.
library;

class AppConstants {
  // اكتشاف mDNS — يجب أن يطابق تماماً ما في فيرموير اللوحة (config.h)
  static const String mdnsServiceType = '_morad._tcp';
  static const int wsPort = 81;

  // مهلات زمنية (بالميلي ثانية)
  static const int localCommandTimeoutMs = 800; // قبل التحويل التلقائي للسحابة
  static const int mdnsScanDurationMs = 4000;
  static const int deviceOfflineThresholdMs = 15000; // أكثر من هذا = اللوحة Offline
  static const int localInstabilityWindowMs = 60000; // نافذة رصد عدم استقرار الاتصال المحلي
  static const int localInstabilityMaxFailures = 2;
  static const int pendingCommandExpiryMs = 120000; // أمر أقدم من هذا يُحذف من الطابور

  // مسارات RTDB — يجب أن تطابق تماماً بنية الفيرموير (cloud_sync.h)
  static String deviceBasePath(String deviceId) => 'devices/$deviceId';
  static String deviceStatusPath(String deviceId) => '${deviceBasePath(deviceId)}/status';
  static String deviceInfoPath(String deviceId) => '${deviceBasePath(deviceId)}/info';
  static String deviceCapabilitiesPath(String deviceId) => '${deviceBasePath(deviceId)}/capabilities';
  static String deviceCommandsPath(String deviceId) => '${deviceBasePath(deviceId)}/commands/relays';
  static String deviceStatePath(String deviceId) => '${deviceBasePath(deviceId)}/state';
  static String deviceRelayStatePath(String deviceId, int relayNumber) =>
      '${deviceStatePath(deviceId)}/relays/relay_$relayNumber';
  static String deviceConfigPath(String deviceId) => '${deviceBasePath(deviceId)}/config/relays';

  // الوضع الافتراضي عند غياب Capabilities من اللوحة
  static const int defaultRelayCount = 12;
}
