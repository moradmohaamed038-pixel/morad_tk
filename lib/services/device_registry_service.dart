/// services/device_registry_service.dart
/// يستدعي Cloud Functions (functions/index.js في مشروع morad_tk_backend)
/// ويقرأ فهرس /users/{uid}/devices من RTDB لعرض لوحات المستخدم المملوكة.
library;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class DeviceRegistryService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  /// يربط لوحة بالمستخدم الحالي — يتطلب deviceId + claim_pin المطبوع على
  /// اللوحة أو الظاهر بـ Serial Monitor عند أول إقلاع (راجع cloud_sync.h).
  Future<String?> claimDevice(String deviceId, String pin) async {
    try {
      final callable = _functions.httpsCallable('claimDevice');
      await callable.call({'deviceId': deviceId, 'pin': pin});
      return null; // نجاح
    } on FirebaseFunctionsException catch (e) {
      return _arabicError(e.code, e.message);
    }
  }

  Future<String?> releaseDevice(String deviceId) async {
    try {
      final callable = _functions.httpsCallable('releaseDevice');
      await callable.call({'deviceId': deviceId});
      return null;
    } on FirebaseFunctionsException catch (e) {
      return _arabicError(e.code, e.message);
    }
  }

  /// قائمة معرّفات اللوحات المملوكة للمستخدم الحالي (بث حي — يتحدّث تلقائياً
  /// فور إضافة/إزالة لوحة من أي جهاز آخر لنفس الحساب)
  Stream<List<String>> myDeviceIdsStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    return _db.ref('users/$uid/devices').onValue.map((event) {
      if (event.snapshot.value == null) return <String>[];
      final map = Map<String, dynamic>.from(event.snapshot.value as Map);
      return map.keys.toList();
    });
  }

  String _arabicError(String? code, String? message) {
    switch (code) {
      case 'not-found':
        return 'لا توجد لوحة بهذا المعرّف. تأكد أنها اتصلت بالإنترنت مرة واحدة على الأقل.';
      case 'already-exists':
        return 'هذه اللوحة مرتبطة بالفعل بحساب آخر.';
      case 'permission-denied':
        return 'رمز الإقران (PIN) غير صحيح.';
      case 'unauthenticated':
        return 'يجب تسجيل الدخول أولاً.';
      default:
        return message ?? 'حدث خطأ غير متوقع.';
    }
  }
}
