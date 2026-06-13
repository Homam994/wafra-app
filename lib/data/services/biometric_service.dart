import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

enum LockMethod { enabled, disabled }

class BiometricService {
  static const _s = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true, // ✅ مطلوب على Android 23+
    ),
  );
  static const _methodKey = 'wafra_lock_v3';
  final _la = LocalAuthentication();

  /// هل الجهاز يدعم أي نوع من المصادقة
  Future<bool> isAvailable() async {
    try {
      final supported = await _la.isDeviceSupported();
      if (!supported) return false;
      // تحقق إضافي: هل هناك بيانات مسجّلة فعلاً (بصمة أو PIN)
      final canCheck = await _la.canCheckBiometrics;
      // isDeviceSupported يكفي — يشمل PIN/Pattern/Password
      return supported;
    } catch (_) {
      return false;
    }
  }

  /// المصادقة الفعلية مع تسجيل الخطأ للتشخيص
  Future<({bool ok, String? errorCode})> authenticateWithDetails() async {
    try {
      final result = await _la.authenticate(
        localizedReason: 'التحقق للوصول إلى بيانات وفرة المالية',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          sensitiveTransaction: false, // ← false أكثر توافقاً
          useErrorDialogs: true,
        ),
      );
      return (ok: result, errorCode: null);
    } on PlatformException catch (e) {
      return (ok: false, errorCode: e.code);
    } catch (e) {
      return (ok: false, errorCode: 'unknown: $e');
    }
  }

  /// واجهة مبسّطة للاستخدام في lock_screen
  Future<bool> authenticate() async {
    final r = await authenticateWithDetails();
    return r.ok;
  }

  Future<LockMethod> getMethod() async {
    try {
      final v = await _s.read(key: _methodKey);
      return v == 'enabled' ? LockMethod.enabled : LockMethod.disabled;
    } catch (_) {
      return LockMethod.disabled;
    }
  }

  Future<bool> enable() async {
    try {
      await _s.write(key: _methodKey, value: 'enabled');
      // تحقق أن الكتابة نجحت فعلاً
      final v = await _s.read(key: _methodKey);
      return v == 'enabled';
    } catch (_) {
      return false;
    }
  }

  Future<void> disable() async {
    try { await _s.write(key: _methodKey, value: 'disabled'); } catch (_) {}
  }

  Future<void> clearAll() async {
    try { await _s.deleteAll(); } catch (_) {}
  }
}
