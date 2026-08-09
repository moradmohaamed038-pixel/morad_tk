/// services/firebase_service.dart
/// يطابق تماماً مسارات RTDB في cloud_sync.h (الفيرموير).
library;

import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../core/constants.dart';

class FirebaseService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  /// خانة "اتصال السحابة" — حالة اتصال *هاتف المستخدم* بسيرفر Firebase،
  /// لا علاقة لها إطلاقاً باللوحة. مسار خاص موفر من كل SDK لـ RTDB.
  Stream<bool> get cloudConnectionStream {
    return _db.ref('.info/connected').onValue.map((event) {
      return event.snapshot.value == true;
    });
  }

  /// خانة "حالة اللوحة" — تُحسب من last_seen وليس من قيمة device_online فقط،
  /// لأن اللوحة قد تنقطع فجأة دون أن تكتب device_online=false بنفسها
  /// (نمط Heartbeat المتفق عليه بدل onDisconnect غير الموثوقة في الفيرموير).
  Stream<bool> deviceOnlineStream(String deviceId) {
    final path = AppConstants.deviceStatusPath(deviceId);
    return _db.ref(path).onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null || data is! Map) return false;
      final lastSeen = data['last_seen'];
      if (lastSeen == null) return false;
      final lastSeenMs = (lastSeen as num).toInt();
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      return (nowMs - lastSeenMs) < AppConstants.deviceOfflineThresholdMs;
    });
  }

  /// بنية اللوحة الكاملة (لبناء الواجهة تلقائياً حتى سحابياً بدون WebSocket)
  Future<Map<String, dynamic>?> fetchCapabilities(String deviceId) async {
    final snap = await _db.ref(AppConstants.deviceCapabilitiesPath(deviceId)).get();
    if (!snap.exists) return null;
    return Map<String, dynamic>.from(snap.value as Map);
  }

  /// كلمة سر التحكم المحلي — تُقرأ فقط من قِبل مالك اللوحة (تفرضها RTDB Rules)،
  /// تُستخدم للاتصال المحلي التلقائي دون طلب إدخالها يدوياً من المستخدم.
  Future<String?> fetchWsPassword(String deviceId) async {
    final snap = await _db.ref('${AppConstants.deviceInfoPath(deviceId)}/ws_password').get();
    if (!snap.exists) return null;
    return snap.value as String?;
  }

  /// استماع فوري لحالة كل الريليهات (state وليس commands)
  Stream<Map<String, dynamic>> relayStateStream(String deviceId) {
    final path = '${AppConstants.deviceStatePath(deviceId)}/relays';
    return _db.ref(path).onValue.map((event) {
      if (event.snapshot.value == null) return <String, dynamic>{};
      return Map<String, dynamic>.from(event.snapshot.value as Map);
    });
  }

  Stream<Map<String, dynamic>> sensorStateStream(String deviceId) {
    final path = '${AppConstants.deviceStatePath(deviceId)}/sensors';
    return _db.ref(path).onValue.map((event) {
      if (event.snapshot.value == null) return <String, dynamic>{};
      return Map<String, dynamic>.from(event.snapshot.value as Map);
    });
  }

  /// كتابة أمر سحابي — التطبيق يكتب هنا فقط، ولا يكتب أبداً في state مباشرة
  Future<void> sendCommand(String deviceId, int relayNumber, bool state) async {
    final path = '${AppConstants.deviceCommandsPath(deviceId)}/relay_$relayNumber';
    await _db.ref(path).set({
      'value': state,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// إعدادات المستخدم لكل سويتش (اسم/لون/جدول) — منفصلة عن الحالة الفعلية
  Future<void> saveRelayConfig(
    String deviceId,
    int relayNumber,
    Map<String, dynamic> config,
  ) async {
    final path = '${AppConstants.deviceConfigPath(deviceId)}/relay_$relayNumber';
    await _db.ref(path).update(config);
  }

  Stream<Map<String, dynamic>> relayConfigStream(String deviceId, int relayNumber) {
    final path = '${AppConstants.deviceConfigPath(deviceId)}/relay_$relayNumber';
    return _db.ref(path).onValue.map((event) {
      if (event.snapshot.value == null) return <String, dynamic>{};
      return Map<String, dynamic>.from(event.snapshot.value as Map);
    });
  }
}
