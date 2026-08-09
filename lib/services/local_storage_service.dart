/// services/local_storage_service.dart
/// يحفظ بيانات آخر لوحة تم الاتصال بها محلياً بنجاح، حتى يستطيع المستخدم
/// إعادة الدخول للتحكم مباشرة دون إعادة مسح mDNS أو كتابة كلمة السر من جديد.
///
/// تنبيه أمني: كلمة سر WebSocket تُخزَّن هنا نصاً عادياً داخل SharedPreferences
/// (وهي بيانات خاصة بالتطبيق، غير قابلة للقراءة من تطبيقات أخرى على النظام
/// دون صلاحيات جذر). هذا مقبول لكلمة سر تحكم محلي منخفضة الحساسية نسبياً،
/// لكن لا يُستخدم لبيانات حساسة كبيانات تسجيل دخول مستخدم حقيقي.
library;

import 'package:shared_preferences/shared_preferences.dart';

class SavedDevice {
  final String deviceId;
  final String ip;
  final int port;
  final String wsPassword;

  SavedDevice({
    required this.deviceId,
    required this.ip,
    required this.port,
    required this.wsPassword,
  });
}

class LocalStorageService {
  static const _keyDeviceId = 'last_device_id';
  static const _keyIp = 'last_device_ip';
  static const _keyPort = 'last_device_port';
  static const _keyPassword = 'last_device_ws_password';

  Future<void> saveLastDevice(SavedDevice device) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDeviceId, device.deviceId);
    await prefs.setString(_keyIp, device.ip);
    await prefs.setInt(_keyPort, device.port);
    await prefs.setString(_keyPassword, device.wsPassword);
  }

  Future<SavedDevice?> loadLastDevice() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString(_keyDeviceId);
    final ip = prefs.getString(_keyIp);
    final port = prefs.getInt(_keyPort);
    final password = prefs.getString(_keyPassword);

    if (deviceId == null || ip == null || port == null || password == null) {
      return null;
    }
    return SavedDevice(deviceId: deviceId, ip: ip, port: port, wsPassword: password);
  }

  Future<void> clearLastDevice() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyDeviceId);
    await prefs.remove(_keyIp);
    await prefs.remove(_keyPort);
    await prefs.remove(_keyPassword);
  }
}
