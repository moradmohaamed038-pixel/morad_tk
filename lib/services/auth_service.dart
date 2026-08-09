/// services/auth_service.dart
/// طبقة رقيقة فوق Firebase Auth — بريد إلكتروني وكلمة سر فقط (أبسط نقطة بداية،
/// يمكن إضافة Google/Apple Sign-In لاحقاً دون تغيير بقية التطبيق).
library;

import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<String?> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null; // لا خطأ
    } on FirebaseAuthException catch (e) {
      return _arabicError(e.code);
    }
  }

  Future<String?> signUp(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return _arabicError(e.code);
    }
  }

  Future<void> signOut() => _auth.signOut();

  String _arabicError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'لا يوجد حساب بهذا البريد الإلكتروني.';
      case 'wrong-password':
        return 'كلمة السر غير صحيحة.';
      case 'email-already-in-use':
        return 'هذا البريد مستخدم بالفعل — جرّب تسجيل الدخول بدلاً من إنشاء حساب.';
      case 'weak-password':
        return 'كلمة السر ضعيفة جداً (6 أحرف على الأقل).';
      case 'invalid-email':
        return 'صيغة البريد الإلكتروني غير صحيحة.';
      default:
        return 'حدث خطأ غير متوقع (${code}).';
    }
  }
}
