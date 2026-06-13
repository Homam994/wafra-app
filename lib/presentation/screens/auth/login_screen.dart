import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/auth_service.dart';
import '../../../providers/app_provider.dart';
import '../home/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _loginEmail  = TextEditingController();
  final _loginPass   = TextEditingController();
  final _regName     = TextEditingController();
  final _regEmail    = TextEditingController();
  final _regPass     = TextEditingController();
  final _resetEmail  = TextEditingController();
  String _currency   = 'SAR';
  bool   _loading    = false, _obscure = true, _showReset = false;
  String _error      = '';

  static const _currencies = [
    ('SAR','🇸🇦 ريال سعودي'), ('AED','🇦🇪 درهم إماراتي'),
    ('KWD','🇰🇼 دينار كويتي'), ('BHD','🇧🇭 دينار بحريني'),
    ('QAR','🇶🇦 ريال قطري'),  ('EGP','🇪🇬 جنيه مصري'),
    ('USD','🇺🇸 دولار أمريكي'),
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
    _regName.dispose(); _regEmail.dispose(); _regPass.dispose();
    _resetEmail.dispose();
    super.dispose();
  }

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
    if (_regName.text.trim().isEmpty) { _setErr('أدخل اسمك الكامل'); return; }
    if (_regPass.text.length < 6)     { _setErr('كلمة المرور 6 أحرف على الأقل'); return; }
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
    if (_resetEmail.text.trim().isEmpty) { _setErr('أدخل بريدك الإلكتروني'); return; }
    _setErr(''); _setLoading(true);
    try {
      await context.read<AuthService>().resetPassword(_resetEmail.text.trim());
      _setErr('✅ تم الإرسال! تحقق من بريدك');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        // Background deco
        Positioned(top: -120, right: -80,
          child: Container(width: 360, height: 360,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                WaColors.gold.withOpacity(0.06), Colors.transparent])))),
        Positioned(bottom: -100, left: -60,
          child: Container(width: 280, height: 280,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                WaColors.info.withOpacity(0.04), Colors.transparent])))),
        // Content
        SafeArea(child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(children: [
              // Logo
              Image.asset('assets/images/logo.png', height: 90)
                .animate().fadeIn(duration: 500.ms).slideY(begin: -0.15),
              const SizedBox(height: 4),
              Text('إدارة مالية ذكية وأنيقة',
                style: TextStyle(fontSize: 12, letterSpacing: 1, color: WaColors.textMuted))
                .animate(delay: 200.ms).fadeIn(),
              const SizedBox(height: 32),

              // Card
              Container(
                constraints: const BoxConstraints(maxWidth: 420),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: WaColors.border),
                ),
                child: Column(children: [
                  // Top gold line
                  Container(height: 1, decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Colors.transparent, WaColors.goldLight, Colors.transparent]),
                    borderRadius: BorderRadius.circular(1))),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: _showReset ? _resetForm() : _authForm(),
                  ),
                ]),
              ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.08),
            ]),
          ),
        )),
      ]),
    );
  }

  Widget _authForm() => Column(children: [
    // Tabs
    Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: WaColors.obsidian3, borderRadius: BorderRadius.circular(10)),
      child: TabBar(
        controller: _tab,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: WaColors.obsidian4, borderRadius: BorderRadius.circular(7),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)]),
        labelColor: WaColors.gold,
        unselectedLabelColor: WaColors.textMuted,
        dividerColor: Colors.transparent,
        tabs: const [Tab(text: 'تسجيل الدخول'), Tab(text: 'حساب جديد')],
      ),
    ),
    const SizedBox(height: 22),

    AnimatedCrossFade(
      duration: 220.ms,
      crossFadeState: _tab.index == 0
          ? CrossFadeState.showFirst : CrossFadeState.showSecond,
      firstChild : _loginForm(),
      secondChild: _registerForm(),
    ),

    if (_error.isNotEmpty) ...[
      const SizedBox(height: 10),
      Text(_error, textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13,
          color: _error.startsWith('✅') ? WaColors.success : WaColors.danger)),
    ],
  ]);

  Widget _loginForm() => Column(mainAxisSize: MainAxisSize.min, children: [
    _field(ctrl: _loginEmail, hint: 'البريد الإلكتروني',
        icon: Icons.email_outlined, type: TextInputType.emailAddress),
    const SizedBox(height: 12),
    _field(ctrl: _loginPass, hint: 'كلمة المرور',
        icon: Icons.lock_outline, obscure: _obscure,
        onToggle: () => setState(() => _obscure = !_obscure)),
    const SizedBox(height: 18),
    _goldBtn('دخول', _login),
    const SizedBox(height: 10),
    TextButton(
      onPressed: () {
        _resetEmail.text = _loginEmail.text;
        setState(() { _showReset = true; _error = ''; });
      },
      child: Text('نسيت كلمة المرور؟',
        style: TextStyle(color: WaColors.goldDim, fontSize: 13)),
    ),
  ]);

  Widget _registerForm() => Column(mainAxisSize: MainAxisSize.min, children: [
    _field(ctrl: _regName, hint: 'الاسم الكامل', icon: Icons.person_outline),
    const SizedBox(height: 12),
    _field(ctrl: _regEmail, hint: 'البريد الإلكتروني',
        icon: Icons.email_outlined, type: TextInputType.emailAddress),
    const SizedBox(height: 12),
    _field(ctrl: _regPass, hint: '6 أحرف على الأقل',
        icon: Icons.lock_outline, obscure: _obscure,
        onToggle: () => setState(() => _obscure = !_obscure)),
    const SizedBox(height: 12),
    DropdownButtonFormField<String>(
      value: _currency, dropdownColor: WaColors.obsidian3,
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.currency_exchange, color: WaColors.goldDim, size: 20)),
      items: _currencies.map((c) => DropdownMenuItem(
        value: c.$1, child: Text(c.$2, style: const TextStyle(fontSize: 13)))).toList(),
      onChanged: (v) => setState(() => _currency = v!),
    ),
    const SizedBox(height: 18),
    _goldBtn('إنشاء الحساب', _register),
  ]);

  Widget _resetForm() => Column(children: [
    const Text('🔑', style: TextStyle(fontSize: 42)),
    const SizedBox(height: 10),
    const Text('إعادة تعيين كلمة المرور',
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
    const SizedBox(height: 6),
    Text('أدخل بريدك وسنرسل رابط الاسترداد',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 13, color: WaColors.textMuted)),
    const SizedBox(height: 20),
    _field(ctrl: _resetEmail, hint: 'البريد الإلكتروني',
        icon: Icons.email_outlined, type: TextInputType.emailAddress),
    const SizedBox(height: 16),
    _goldBtn('إرسال رابط الاسترداد', _resetPassword),
    if (_error.isNotEmpty) ...[
      const SizedBox(height: 10),
      Text(_error, textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13,
          color: _error.startsWith('✅') ? WaColors.success : WaColors.danger)),
    ],
    const SizedBox(height: 10),
    TextButton(
      onPressed: () => setState(() { _showReset = false; _error = ''; }),
      child: Text('← العودة لتسجيل الدخول',
        style: TextStyle(color: WaColors.textMuted, fontSize: 13)),
    ),
  ]);

  Widget _field({
    required TextEditingController ctrl,
    required String hint, required IconData icon,
    TextInputType type = TextInputType.text,
    bool obscure = false, VoidCallback? onToggle,
  }) => TextField(
    controller: ctrl, keyboardType: type,
    obscureText: obscure, textDirection: TextDirection.ltr,
    style: const TextStyle(fontSize: 15),
    onSubmitted: (_) => _tab.index == 0 ? _login() : null,
    decoration: InputDecoration(
      hintText  : hint,
      prefixIcon: Icon(icon, color: WaColors.goldDim, size: 20),
      suffixIcon: onToggle != null ? IconButton(
        icon: Icon(obscure ? Icons.visibility_off : Icons.visibility,
            color: WaColors.textMuted, size: 18),
        onPressed: onToggle) : null,
    ),
  );

  Widget _goldBtn(String label, VoidCallback onPressed) => SizedBox(
    width: double.infinity, height: 50,
    child: ElevatedButton(
      onPressed: _loading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: WaColors.gold,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      child: _loading
          ? const SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: WaColors.obsidian))
          : Text(label, style: const TextStyle(
              fontWeight: FontWeight.w700, fontSize: 15, color: WaColors.obsidian)),
    ),
  );
}
