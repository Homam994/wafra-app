import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/biometric_service.dart';
import '../../../providers/app_provider.dart';
import '../home/home_screen.dart';
import '../quick_add/quick_add_screen.dart';
import 'login_screen.dart';
import 'lock_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  static const _quickChannel =
      MethodChannel('com.wafra.wafra/quick_add');

  @override
  void initState() { super.initState(); _navigate(); }

  Future<void> _navigate() async {
    await Future.delayed(800.ms);
    if (!mounted) return;

    try {
      final auth = context.read<AuthService>();
      final bio  = context.read<BiometricService>();
      final ap   = context.read<AppProvider>();
      final user = auth.currentUser;

      if (user == null) { _go(const LoginScreen()); return; }

      await ap.loadUser(user.uid).timeout(
        const Duration(seconds: 8),
        onTimeout: () => debugPrint('loadUser timeout'),
      );
      if (!mounted) return;

      // ── هل جاء التطبيق من اختصار سريع؟ ─────────────
      String? quickType;
      try {
        quickType = await _quickChannel
            .invokeMethod<String>('getInitialQuickType');
      } catch (_) {}

      if (!mounted) return;

      if (quickType != null) {
        // ✅ افتح QuickAddScreen مباشرة — بدون HomeScreen وبدون قفل
        _go(QuickAddScreen(type: quickType, standalone: true));
        return;
      }

      // ── المسار الطبيعي ────────────────────────────────
      final method = await bio.getMethod();
      if (method == LockMethod.enabled) {
        _go(const LockScreen(destination: HomeScreen()));
      } else {
        _go(const HomeScreen());
      }
    } catch (e) {
      debugPrint('Splash error: $e');
      if (mounted) _go(const LoginScreen());
    }
  }

  void _go(Widget w) {
    if (!mounted) return;
    Navigator.pushReplacement(context, PageRouteBuilder(
      pageBuilder       : (_, __, ___) => w,
      transitionDuration: 350.ms,
      transitionsBuilder: (_, a, __, c) =>
          FadeTransition(opacity: a, child: c),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? WaColors.obsidian : WaColors.cream,
      body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Image.asset('assets/images/logo.png', height: 100)
          .animate().fadeIn(duration: 600.ms)
          .scale(begin: const Offset(0.85, 0.85)),
        const SizedBox(height: 8),
        const SizedBox(height: 48),
        SizedBox(width: 28, height: 28,
          child: CircularProgressIndicator(strokeWidth: 2,
            color: WaColors.gold.withValues(alpha: 0.7)))
          .animate(delay: 600.ms).fadeIn(duration: 400.ms),
      ])),
    );
  }
}
