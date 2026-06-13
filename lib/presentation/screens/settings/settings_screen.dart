import '../home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/biometric_service.dart';
import '../../../data/services/notification_service.dart';
import '../../../providers/app_provider.dart';
import '../../widgets/common/wa_card.dart';
import '../auth/login_screen.dart';
import '../auth/lock_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override State<SettingsScreen> createState() => _SettingsScreenState();
}
class _SettingsScreenState extends State<SettingsScreen> {
  bool       _bioEnabled = false, _lockBg = false, _notifEnabled = true;
  LockMethod _method = LockMethod.disabled;

  static const _currencies = [
    ('SAR','🇸🇦 ريال سعودي'),('AED','🇦🇪 درهم إماراتي'),
    ('KWD','🇰🇼 دينار كويتي'),('BHD','🇧🇭 دينار بحريني'),
    ('QAR','🇶🇦 ريال قطري'), ('EGP','🇪🇬 جنيه مصري'),
    ('USD','🇺🇸 دولار أمريكي'),
  ];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final m = await context.read<BiometricService>().getMethod();
    setState(() {
      // ✅ مصدر واحد للحقيقة: BiometricService هو المرجع
      _method        = m;
      _bioEnabled    = (m == LockMethod.enabled);
      _lockBg        = p.getBool('lockBg') ?? false;
      _notifEnabled  = NotificationService.instance.isEnabled;
    });
  }

  Future<void> _setBio(bool v) async {
    final bio = context.read<BiometricService>();
    if (v) {
      // ── خطوة 1: تحقق من دعم الجهاز ───────────────
      final avail = await bio.isAvailable();
      if (!avail) {
        if (mounted) _showLockHint();
        return;
      }

      // ── خطوة 2: اطلب المصادقة مع تفاصيل الخطأ ───
      final result = await bio.authenticateWithDetails();

      if (!result.ok) {
        if (!mounted) return;
        // أظهر سبب الفشل للمستخدم
        final reason = switch (result.errorCode) {
          'notEnrolled'    => 'لا توجد بصمة أو PIN مُسجَّل على الجهاز',
          'notAvailable'   => 'المصادقة غير متاحة على هذا الجهاز',
          'passcodeNotSet' => 'يجب إعداد قفل الشاشة أولاً في إعدادات الجهاز',
          'lockedOut'      => 'تم تعطيل المصادقة مؤقتاً بسبب محاولات فاشلة',
          'permanentlyLockedOut' => 'تم تعطيل المصادقة. أعد تشغيل الجهاز',
          null             => 'تم الإلغاء',
          _                => 'فشل التحقق (${result.errorCode})',
        };
        _snack('❌ $reason');
        return;
      }

      // ── خطوة 3: احفظ الإعداد وتحقق من النجاح ────
      final saved = await bio.enable();
      if (!mounted) return;

      if (!saved) {
        _snack('❌ فشل حفظ الإعداد — تأكد أن الجهاز يدعم التخزين المشفّر');
        return;
      }

      setState(() { _bioEnabled = true; _method = LockMethod.enabled; });
      _snack('🔒 تم تفعيل القفل عند الفتح');

    } else {
      await bio.disable();
      if (mounted) setState(() { _bioEnabled = false; _method = LockMethod.disabled; });
      _snack('🔓 تم إيقاف القفل');
    }
  }

  void _showLockHint() {
    showDialog(context: context, builder: (_) => AlertDialog(
      title  : const Text('قفل الشاشة غير مفعّل'),
      content: const Text(
        'لتفعيل هذه الميزة، يجب إعداد قفل الشاشة على جهازك أولاً:\n\n'
        '1. افتح إعدادات الجهاز\n'
        '2. اذهب إلى "الأمان" أو "قفل الشاشة"\n'
        '3. أعدّ بصمة أو رمز PIN أو نمط\n'
        '4. عد وفعّل القفل هنا',
        style: TextStyle(height: 1.6)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('حسناً')),
      ],
    ));
  }

  Future<void> _setLockBg(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('lockBg', v);
    setState(() => _lockBg = v);
  }

  Future<void> _resetBio() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('lockBg');
    await context.read<BiometricService>().clearAll();
    setState(() { _method = LockMethod.disabled; _bioEnabled = false; _lockBg = false; });
    _snack('🔑 تم إعادة تعيين القفل بالكامل');
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(context: context,
      builder: (_) => AlertDialog(
        title  : const Text('تسجيل الخروج'),
        content: const Text('هل تريد الخروج؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: WaColors.danger),
            child: const Text('خروج')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<AppProvider>().clearUser();
    await context.read<AuthService>().signOut();
    if (mounted) Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final ap = context.watch<AppProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات'),
        leading: Builder(builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu), onPressed: () => MenuOpener.of(context)?.onMenu())),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('🔒 الأمان والخصوصية'),
          WaCard(child: Column(children: [
            _switchRow('التحقق الحيوي عند الفتح', 'بصمة / وجه / PIN الجهاز',
                _bioEnabled, _setBio),
            if (_bioEnabled) ...[
              const Divider(height: 1),
              _switchRow('القفل عند الخروج للخلفية',
                  'يقفل التلقائياً عند تصغير التطبيق', _lockBg, _setLockBg),
              const Divider(height: 1),
              _actionRow('إعادة تعيين طريقة القفل',
                  'الطريقة الحالية: ${_methodLabel()}',
                  Icons.refresh, _resetBio),
            ],
          ])).animate().fadeIn(duration: 300.ms),

          const SizedBox(height: 14),
          _section('🔔 الإشعارات'),
          WaCard(child: Column(children: [
            _switchRow(
              'إشعارات الميزانية',
              'تنبيه عند اقتراب أو تجاوز حد الإنفاق',
              _notifEnabled,
              (v) async {
                await NotificationService.instance.setEnabled(v);
                setState(() => _notifEnabled = v);
                _snack(v ? '🔔 تم تفعيل الإشعارات' : '🔕 تم إيقاف الإشعارات');
              },
            ),
            const Divider(height: 1),
            _actionRow(
              'اختبار إشعار',
              'أرسل إشعاراً تجريبياً الآن',
              Icons.notifications_active_outlined,
              () async {
                if (!_notifEnabled) {
                  _snack('⚠️ الإشعارات معطلة — فعّلها أولاً');
                  return;
                }
                await NotificationService.instance.showBudgetAlert(
                  categoryLabel: 'المطاعم',
                  spent: 950, limit: 1000,
                  currency: context.read<AppProvider>().currency,
                  isOver: false,
                );
                _snack('📨 تم إرسال إشعار تجريبي');
              },
            ),
          ])).animate(delay: 50.ms).fadeIn(duration: 300.ms),

          const SizedBox(height: 14),
          _section('🎨 العرض والمظهر'),
          WaCard(child: Column(children: [
            _switchRow('الوضع الليلي', 'خلفية داكنة تريح العين',
                ap.isDark, (_) => ap.toggleTheme()),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('العملة', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  Text('الحالية: ${ap.currency}',
                    style: TextStyle(fontSize: 12, color: WaColors.textMuted)),
                ])),
                DropdownButton<String>(
                  value: ap.currency, dropdownColor: WaColors.obsidian3,
                  underline: const SizedBox(),
                  items: _currencies.map((c) => DropdownMenuItem(
                    value: c.$1,
                    child: Text(c.$2, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (v) { if (v != null) ap.updateCurrency(v); },
                ),
              ]),
            ),
          ])).animate(delay: 50.ms).fadeIn(duration: 300.ms),

          const SizedBox(height: 14),
          _section('💾 البيانات'),
          WaCard(child: Column(children: [
            _actionRow('مزامنة البيانات', 'Firebase Firestore — مزامنة فورية',
                Icons.cloud_done_outlined, null, WaColors.success),
            const Divider(height: 1),
            _actionRow('تصدير CSV', 'يفتح في Excel أو Google Sheets',
                Icons.download_outlined, ap.exportCSV),
          ])).animate(delay: 100.ms).fadeIn(duration: 300.ms),

          const SizedBox(height: 14),
          _section('ℹ️ عن التطبيق'),
          WaCard(child: Column(children: [
            _infoRow('الإصدار', '1.0.0'),
            const Divider(height: 1),
            _infoRow('التطبيق', 'وفرة — إدارة مالية ذكية'),
            const Divider(height: 1),
            _infoRow('قاعدة البيانات', 'Firebase Firestore'),
          ])).animate(delay: 150.ms).fadeIn(duration: 300.ms),

          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _logout,
            icon : const Icon(Icons.logout, color: WaColors.danger),
            label: const Text('تسجيل الخروج',
                style: TextStyle(color: WaColors.danger, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: WaColors.danger),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ).animate(delay: 200.ms).fadeIn(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _section(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8, right: 4),
    child: Text(t, style: TextStyle(fontSize: 11, letterSpacing: 1.5, color: WaColors.textMuted)),
  );

  Widget _switchRow(String title, String sub, bool val, ValueChanged<bool> onChanged) =>
    Padding(padding: const EdgeInsets.symmetric(vertical: 11), child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        Text(sub, style: TextStyle(fontSize: 12, color: WaColors.textMuted)),
      ])),
      Switch.adaptive(value: val, onChanged: onChanged, activeColor: WaColors.gold),
    ]));

  Widget _actionRow(String title, String sub, IconData icon,
      VoidCallback? onTap, [Color? iconColor]) =>
    InkWell(onTap: onTap, child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          Text(sub, style: TextStyle(fontSize: 12, color: WaColors.textMuted)),
        ])),
        Icon(icon, color: iconColor ?? WaColors.textMuted, size: 20),
      ]),
    ));

  Widget _infoRow(String label, String val) =>
    Padding(padding: const EdgeInsets.symmetric(vertical: 11), child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        Text(val, style: TextStyle(fontSize: 13, color: WaColors.textMuted)),
      ],
    ));

  String _methodLabel() => const {
    'enabled': 'مفعّل ✅', 'disabled': 'موقوف',
  }[_method.name] ?? '—';
}
