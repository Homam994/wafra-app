import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _a;
  AuthService(this._a);

  User? get currentUser => _a.currentUser;
  Stream<User?> get stream => _a.authStateChanges();

  Future<UserCredential> signIn(String email, String pass) =>
      _a.signInWithEmailAndPassword(email: email, password: pass);
  Future<UserCredential> register(String email, String pass) =>
      _a.createUserWithEmailAndPassword(email: email, password: pass);
  Future<void> updateName(String n) => _a.currentUser!.updateDisplayName(n);
  Future<void> resetPassword(String e) => _a.sendPasswordResetEmail(email: e);
  Future<void> signOut() => _a.signOut();

  static String errMsg(FirebaseAuthException e) {
    const m = {
      'user-not-found'        : 'لا يوجد حساب بهذا البريد',
      'wrong-password'        : 'كلمة المرور غير صحيحة',
      'invalid-credential'    : 'البريد أو كلمة المرور غير صحيحة',
      'email-already-in-use'  : 'هذا البريد مسجل مسبقاً',
      'invalid-email'         : 'صيغة البريد غير صحيحة',
      'weak-password'         : 'كلمة المرور ضعيفة جداً',
      'too-many-requests'     : 'محاولات كثيرة، انتظر قليلاً',
      'network-request-failed': 'تحقق من اتصالك بالإنترنت',
    };
    return m[e.code] ?? 'خطأ: ${e.code}';
  }
}
