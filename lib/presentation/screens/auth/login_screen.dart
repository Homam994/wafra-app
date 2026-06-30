import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/auth_service.dart';
import '../../../providers/app_provider.dart';
import '../home/home_screen.dart';
import '../../../generated/l10n/app_localizations.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {

  // ── l10n getter (works in all methods) ───────────────
  AppLocalizations get _l10n => AppLocalizations.of(context);
  bool get _isAr => context.read<AppProvider>().locale.languageCode == 'ar';

  late TabController _tab;
  final _loginEmail = TextEditingController();
  final _loginPass  = TextEditingController();
  final _regName    = TextEditingController();
  final _regEmail   = TextEditingController();
  final _regPass    = TextEditingController();
  final _resetEmail = TextEditingController();
  String _currency  = 'SAR';
  bool   _loading   = false, _obscure = true, _showReset = false;
  String _error     = '';

  static const _currencies = [
    ('SAR','🇸🇦 ريال سعودي',   '🇸🇦 Saudi Riyal'),
    ('AED','🇦🇪 درهم إماراتي', '🇦🇪 UAE Dirham'),
    ('KWD','🇰🇼 دينار كويتي',  '🇰🇼 Kuwaiti Dinar'),
    ('BHD','🇧🇭 دينار بحريني', '🇧🇭 Bahraini Dinar'),
    ('QAR','🇶🇦 ريال قطري',    '🇶🇦 Qatari Riyal'),
    ('EGP','🇪🇬 جنيه مصري',   '🇪🇬 Egyptian Pound'),
    ('USD','🇺🇸 دولار أمريكي', '🇺🇸 US Dollar'),
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    _loginEmail.dispose(); _loginPass.dispose();
    _regName.dispose();    _regEmail.dispose();
    _regPass.dispose();    _resetEmail.dispose();
    super.dispose();
  }

  // ── Actions ───────────────────────────────────────────
  Future<void> _login() async {
    _setErr(''); _setLoading(true);
    try {
      final auth = context.read<AuthService>();
      final cred = await auth.signIn(_loginEmail.text.trim(), _loginPass.text);
      await context.read<AppProvider>().loadUser(cred.user!.uid);
      if (mounted) _goHome();
    } on FirebaseAuthException catch (e) {
      _setErr(AuthService.errMsg(e));
    } finally { _setLoading(false); }
  }

  Future<void> _register() async {
    final isAr = _isAr;
    if (_regName.text.trim().isEmpty) {
      _setErr(isAr ? 'أدخل اسمك الكامل' : 'Enter your full name'); return;
    }
    if (_regPass.text.length < 6) {
      _setErr(isAr ? 'كلمة المرور 6 أحرف على الأقل' : 'Password must be at least 6 characters'); return;
    }
    _setErr(''); _setLoading(true);
    try {
      final auth = context.read<AuthService>();
      final cred = await auth.register(_regEmail.text.trim(), _regPass.text);
      await auth.updateName(_regName.text.trim());
      await context.read<AppProvider>().loadUser(cred.user!.uid);
      await context.read<AppProvider>().updateCurrency(_currency);
      if (mounted) _goHome();
    } on FirebaseAuthException catch (e) {
      _setErr(AuthService.errMsg(e));
    } finally { _setLoading(false); }
  }

  Future<void> _resetPassword() async {
    final isAr = _isAr;
    if (_resetEmail.text.trim().isEmpty) {
      _setErr(isAr ? 'أدخل بريدك الإلكتروني' : 'Enter your email'); return;
    }
    _setErr(''); _setLoading(true);
    try {
      await context.read<AuthService>().resetPassword(_resetEmail.text.trim());
      _setErr(isAr ? '✅ تم الإرسال! تحقق من بريدك' : '✅ Sent! Check your inbox');
      await Future.delayed(2.5.seconds);
      if (mounted) setState(() { _showReset = false; _error = ''; });
    } on FirebaseAuthException catch (e) {
      _setErr(AuthService.errMsg(e));
    } finally { _setLoading(false); }
  }

  void _goHome() => Navigator.pushReplacement(
      context, MaterialPageRoute(builder: (_) => const HomeScreen()));
  void _setLoading(bool v) { if (mounted) setState(() => _loading = v); }
  void _setErr(String v)   { if (mounted) setState(() => _error = v); }

  // ── Toggle locale ─────────────────────────────────────
  void _toggleLocale() {
    final ap = context.read<AppProvider>();
    ap.setLocale(ap.locale.languageCode == 'ar'
        ? const Locale('en', 'US')
        : const Locale('ar', 'SA'));
  }

  // ── Build ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final ap     = context.watch<AppProvider>();
    final isAr   = ap.locale.languageCode == 'ar';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(children: [
        // ── Background deco ──
        Positioned(top: -120, right: -80,
          child: Container(width: 360, height: 360,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                WaColors.gold.withValues(alpha: 0.06), Colors.transparent])))),
        Positioned(bottom: -100, left: -60,
          child: Container(width: 280, height: 280,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                WaColors.info.withValues(alpha: 0.04), Colors.transparent])))),

        // ── Content ──
        SafeArea(child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(children: [
              Image.asset('assets/images/logo.png', height: 90)
                  .animate().fadeIn(duration: 500.ms).slideY(begin: -0.15),
              const SizedBox(height: 4),
              Text(_l10n.appTagline,
                style: const TextStyle(fontSize: 12, letterSpacing: 1, color: WaColors.textMuted))
                  .animate(delay: 200.ms).fadeIn(),
              const SizedBox(height: 32),
              Container(
                constraints: const BoxConstraints(maxWidth: 420),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: WaColors.border),
                ),
                child: Column(children: [
                  Container(height: 1, decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [
                      Colors.transparent, WaColors.goldLight, Colors.transparent]),
                    borderRadius: BorderRadius.circular(1))),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: _showReset ? _resetForm(isAr, isDark) : _authForm(isAr, isDark),
                  ),
                ]),
              ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.08),
            ]),
          ),
        )),

        // ── Language toggle button (top corner) ──
        SafeArea(
          child: Align(
            alignment: isAr ? Alignment.topLeft : Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: InkWell(
                onTap: _toggleLocale,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? WaColors.obsidian2.withValues(alpha: 0.9)
                        : Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: WaColors.goldDim.withValues(alpha: 0.6)),
                    boxShadow: [BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(isAr ? '🇺🇸' : '🇸🇦', style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(isAr ? 'English' : 'العربية',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600, color: WaColors.gold)),
                  ]),
                ),
              ).animate().fadeIn(delay: 400.ms),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Auth Form (login + register tabs) ────────────────
  Widget _authForm(bool isAr, bool isDark) {
    // ✅ Fix: use theme-aware colors instead of hardcoded obsidian
    final tabBg       = isDark ? WaColors.obsidian3         : const Color(0xFFEDE9E0);
    final tabActiveBg = isDark ? WaColors.obsidian4         : Colors.white;
    final tabShadow   = isDark ? Colors.black26             : Colors.black12;

    return Column(children: [
      Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: tabBg, borderRadius: BorderRadius.circular(10)),
        child: TabBar(
          controller: _tab,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            color: tabActiveBg,
            borderRadius: BorderRadius.circular(7),
            boxShadow: [BoxShadow(color: tabShadow, blurRadius: 4)]),
          labelColor: WaColors.gold,
          unselectedLabelColor: WaColors.textMuted,
          dividerColor: Colors.transparent,
          tabs: [
            Tab(text: isAr ? 'تسجيل الدخول' : 'Sign In'),
            Tab(text: isAr ? 'حساب جديد'    : 'Sign Up'),
          ],
        ),
      ),
      const SizedBox(height: 22),
      AnimatedCrossFade(
        duration: 220.ms,
        crossFadeState: _tab.index == 0
            ? CrossFadeState.showFirst : CrossFadeState.showSecond,
        firstChild : _loginForm(isAr),
        secondChild: _registerForm(isAr),
      ),
      if (_error.isNotEmpty) ...[
        const SizedBox(height: 10),
        Text(_error, textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13,
            color: _error.startsWith('✅') ? WaColors.success : WaColors.danger)),
      ],
    ]);
  }

  // ── Login Form ────────────────────────────────────────
  Widget _loginForm(bool isAr) => Column(mainAxisSize: MainAxisSize.min, children: [
    _field(
      ctrl: _loginEmail,
      hint: isAr ? 'البريد الإلكتروني' : 'Email address',
      icon: Icons.email_outlined,
      type: TextInputType.emailAddress),
    const SizedBox(height: 12),
    _field(
      ctrl: _loginPass,
      hint: isAr ? 'كلمة المرور' : 'Password',
      icon: Icons.lock_outline,
      obscure: _obscure,
      onToggle: () => setState(() => _obscure = !_obscure)),
    const SizedBox(height: 18),
    _goldBtn(isAr ? 'دخول' : 'Sign In', _login),
    const SizedBox(height: 10),
    TextButton(
      onPressed: () {
        _resetEmail.text = _loginEmail.text;
        setState(() { _showReset = true; _error = ''; });
      },
      child: Text(_l10n.forgotPassword,
        style: const TextStyle(color: WaColors.goldDim, fontSize: 13)),
    ),
  ]);

  // ── Register Form ─────────────────────────────────────
  Widget _registerForm(bool isAr) => Column(mainAxisSize: MainAxisSize.min, children: [
    _field(
      ctrl: _regName,
      hint: isAr ? 'الاسم الكامل' : 'Full name',
      icon: Icons.person_outline),
    const SizedBox(height: 12),
    _field(
      ctrl: _regEmail,
      hint: isAr ? 'البريد الإلكتروني' : 'Email address',
      icon: Icons.email_outlined,
      type: TextInputType.emailAddress),
    const SizedBox(height: 12),
    _field(
      ctrl: _regPass,
      hint: isAr ? '6 أحرف على الأقل' : 'At least 6 characters',
      icon: Icons.lock_outline,
      obscure: _obscure,
      onToggle: () => setState(() => _obscure = !_obscure)),
    const SizedBox(height: 12),
    DropdownButtonFormField<String>(
      value: _currency,
      dropdownColor: Theme.of(context).colorScheme.surface,
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.currency_exchange, color: WaColors.goldDim, size: 20)),
      items: _currencies.map((c) => DropdownMenuItem(
        value: c.$1,
        child: Text(isAr ? c.$2 : c.$3, style: const TextStyle(fontSize: 13)),
      )).toList(),
      onChanged: (v) => setState(() => _currency = v!),
    ),
    const SizedBox(height: 18),
    _goldBtn(isAr ? 'إنشاء الحساب' : 'Create Account', _register),
  ]);

  // ── Reset Password Form ───────────────────────────────
  Widget _resetForm(bool isAr, bool isDark) => Column(children: [
    const Text('🔑', style: TextStyle(fontSize: 42)),
    const SizedBox(height: 10),
    Text(_l10n.resetPassword,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
    const SizedBox(height: 6),
    Text(_l10n.resetPasswordSub,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 13, color: WaColors.textMuted)),
    const SizedBox(height: 20),
    _field(
      ctrl: _resetEmail,
      hint: isAr ? 'البريد الإلكتروني' : 'Email address',
      icon: Icons.email_outlined,
      type: TextInputType.emailAddress),
    const SizedBox(height: 16),
    _goldBtn(isAr ? 'إرسال رابط الاسترداد' : 'Send Recovery Link', _resetPassword),
    if (_error.isNotEmpty) ...[
      const SizedBox(height: 10),
      Text(_error, textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13,
          color: _error.startsWith('✅') ? WaColors.success : WaColors.danger)),
    ],
    const SizedBox(height: 10),
    TextButton(
      onPressed: () => setState(() { _showReset = false; _error = ''; }),
      child: Text(_l10n.backToLogin,
        style: const TextStyle(color: WaColors.textMuted, fontSize: 13)),
    ),
  ]);

  // ── Shared Widgets ────────────────────────────────────
  Widget _field({
    required TextEditingController ctrl,
    required String hint,
    required IconData icon,
    TextInputType type = TextInputType.text,
    bool obscure = false,
    VoidCallback? onToggle,
  }) => TextField(
    controller: ctrl, keyboardType: type,
    obscureText: obscure, textDirection: TextDirection.ltr,
    style: const TextStyle(fontSize: 15),
    onSubmitted: (_) => _tab.index == 0 ? _login() : null,
    decoration: InputDecoration(
      hintText  : hint,
      prefixIcon: Icon(icon, color: WaColors.goldDim, size: 20),
      suffixIcon: onToggle != null
          ? IconButton(
              icon: Icon(obscure ? Icons.visibility_off : Icons.visibility,
                  color: WaColors.textMuted, size: 18),
              onPressed: onToggle)
          : null,
    ),
  );

  Widget _goldBtn(String label, VoidCallback onPressed) => SizedBox(
    width: double.infinity, height: 50,
    child: ElevatedButton(
      onPressed: _loading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: WaColors.gold,
        foregroundColor: WaColors.obsidian,
        disabledBackgroundColor: WaColors.gold.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      child: _loading
          ? const SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: WaColors.obsidian))
          : Text(label, style: const TextStyle(
              fontWeight: FontWeight.w700, fontSize: 15, color: WaColors.obsidian)),
    ),
  );
}
