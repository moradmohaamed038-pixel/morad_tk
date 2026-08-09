/// models/discovered_device.dart
/// يمثل لوحة تم اكتشافها محلياً عبر mDNS قبل الاتصال بها فعلياً.
class DiscoveredDevice {
  final String deviceId;   // مستخرج من اسم mDNS: morad-<deviceId>
  final String hostname;   // مثال: morad-a1b2c3d4e5f6.local
  final String ip;
  final int port;

  DiscoveredDevice({
    required this.deviceId,
    required this.hostname,
    required this.ip,
    required this.port,
  });

  @override
  String toString() => 'DiscoveredDevice($deviceId @ $ip:$port)';
}
