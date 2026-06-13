import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/biometric_service.dart';

class LockScreen extends StatefulWidget {
  /// الشاشة التي تُفتح بعد نجاح التحقق
  final Widget destination;
  const LockScreen({super.key, required this.destination});
  @override State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen>
    with WidgetsBindingObserver {
  bool _verifying = false;
  bool _failed    = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _verify());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _failed && !_verifying) {
      _verify();
    }
  }

  Future<void> _verify() async {
    if (_verifying || !mounted) return;
    setState(() { _verifying = true; _failed = false; });

    final bio = context.read<BiometricService>();
    final ok  = await bio.authenticate();

    if (!mounted) return;

    if (ok) {
      // ✅ الانتقال مباشرة من context الـ LockScreen — دائماً صالح
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => widget.destination,
          transitionDuration: const Duration(milliseconds: 350),
          transitionsBuilder: (_, a, __, c) =>
              FadeTransition(opacity: a, child: c),
        ),
        (_) => false,
      );
    } else {
      setState(() { _verifying = false; _failed = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? WaColors.obsidian : WaColors.cream;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('وفرة', style: TextStyle(
                fontFamily    : 'PlayfairDisplay',
                fontSize      : 52,
                color         : WaColors.gold,
                fontWeight    : FontWeight.w700,
                shadows: [Shadow(color: WaColors.gold.withValues(alpha: 0.3),
                    blurRadius: 20)]))
                .animate().fadeIn(duration: 500.ms),

              const SizedBox(height: 6),
              Text('WAFRA FINANCE', style: TextStyle(
                fontSize: 11, letterSpacing: 4,
                color: WaColors.textMuted))
                .animate(delay: 200.ms).fadeIn(),

              const SizedBox(height: 60),

              GestureDetector(
                onTap: _failed ? _verify : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _verifying
                        ? WaColors.gold.withValues(alpha: 0.15)
                        : _failed
                            ? WaColors.danger.withValues(alpha: 0.10)
                            : WaColors.gold.withValues(alpha: 0.10),
                    border: Border.all(
                      color: _verifying ? WaColors.gold
                           : _failed    ? WaColors.danger
                           :              WaColors.border,
                      width: 2)),
                  child: Icon(
                    _failed ? Icons.lock_outline : Icons.fingerprint,
                    size : 36,
                    color: _failed ? WaColors.danger : WaColors.gold),
                )
                .animate(onPlay: (c) => _verifying ? c.repeat() : c.stop())
                .shimmer(duration: const Duration(milliseconds: 1200),
                    color: WaColors.gold.withValues(alpha: 0.3)),
              ),

              const SizedBox(height: 20),

              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(
                  _verifying
                      ? 'جارٍ التحقق...'
                      : _failed
                          ? 'اضغط للمحاولة مجدداً'
                          : 'مرحباً بك',
                  key: ValueKey('$_verifying$_failed'),
                  style: TextStyle(
                    fontSize: 14,
                    color: _failed
                        ? WaColors.danger : WaColors.textSecondary),
                ),
              ),

              const SizedBox(height: 32),

              AnimatedOpacity(
                opacity: _failed ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: ElevatedButton.icon(
                  onPressed: _failed ? _verify : null,
                  icon : const Icon(Icons.refresh, size: 18),
                  label: const Text('إعادة المحاولة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: WaColors.gold,
                    foregroundColor: WaColors.obsidian,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
