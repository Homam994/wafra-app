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
import '../../../generated/l10n/app_localizations.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override State<SettingsScreen> createState() => _SettingsScreenState();
}
class _SettingsScreenState extends State<SettingsScreen> {
  bool       _bioEnabled = false, _lockBg = false, _notifEnabled = true;
  LockMethod _method = LockMethod.disabled;

  static const _currencies = [
    ('SAR', '🇸🇦 ريال سعودي', '🇸🇦 Saudi Riyal'),
    ('AED', '🇦🇪 درهم إماراتي', '🇦🇪 UAE Dirham'),
    ('KWD', '🇰🇼 دينار كويتي', '🇰🇼 Kuwaiti Dinar'),
    ('BHD', '🇧🇭 دينار بحريني', '🇧🇭 Bahraini Dinar'),
    ('QAR', '🇶🇦 ريال قطري', '🇶🇦 Qatari Riyal'),
    ('OMR', '🇴🇲 ريال عُماني', '🇴🇲 Omani Rial'),
    ('JOD', '🇯🇴 دينار أردني', '🇯🇴 Jordanian Dinar'),
    ('IQD', '🇮🇶 دينار عراقي', '🇮🇶 Iraqi Dinar'),
    ('SYP', '🇸🇾 ليرة سورية', '🇸🇾 Syrian Pound'),
    ('LBP', '🇱🇧 ليرة لبنانية', '🇱🇧 Lebanese Pound'),
    ('EGP', '🇪🇬 جنيه مصري', '🇪🇬 Egyptian Pound'),
    ('LYD', '🇱🇾 دينار ليبي', '🇱🇾 Libyan Dinar'),
    ('TND', '🇹🇳 دينار تونسي', '🇹🇳 Tunisian Dinar'),
    ('DZD', '🇩🇿 دينار جزائري', '🇩🇿 Algerian Dinar'),
    ('MAD', '🇲🇦 درهم مغربي', '🇲🇦 Moroccan Dirham'),
    ('SDG', '🇸🇩 جنيه سوداني', '🇸🇩 Sudanese Pound'),
    ('YER', '🇾🇪 ريال يمني', '🇾🇪 Yemeni Rial'),
    ('MRU', '🇲🇷 أوقية موريتانية', '🇲🇷 Mauritanian Ouguiya'),
    ('SOS', '🇸🇴 شلن صومالي', '🇸🇴 Somali Shilling'),
    ('DJF', '🇩🇯 فرنك جيبوتي', '🇩🇯 Djiboutian Franc'),
    ('KMF', '🇰🇲 فرنك قمري', '🇰🇲 Comorian Franc'),
    ('USD', '🇺🇸 دولار أمريكي', '🇺🇸 US Dollar'),
    ('EUR', '🇪🇺 يورو', '🇪🇺 Euro'),
    ('GBP', '🇬🇧 جنيه إسترليني', '🇬🇧 British Pound'),
  ];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final m = await context.read<BiometricService>().getMethod();
    setState(() {
      _method       = m;
      _bioEnabled   = (m == LockMethod.enabled);
      _lockBg       = p.getBool('lockBg') ?? false;
      _notifEnabled = NotificationService.instance.isEnabled;
    });
  }

  Future<void> _setBio(bool v) async {
    final l10n = AppLocalizations.of(context);
    final bio  = context.read<BiometricService>();
    if (v) {
      final avail = await bio.isAvailable();
      if (!avail) { if (mounted) _showLockHint(); return; }
      final result = await bio.authenticateWithDetails();
      if (!result.ok) {
        if (!mounted) return;
        final reason = switch (result.errorCode) {
          'notEnrolled'          => l10n.bioNotEnrolled,
          'notAvailable'         => l10n.bioNotAvailable,
          'passcodeNotSet'       => l10n.bioPasscodeNotSet,
          'lockedOut'            => l10n.bioLockedOut,
          'permanentlyLockedOut' => l10n.bioPermanentlyLockedOut,
          null                   => l10n.bioCancelled,
          _                      => l10n.bioFailed(result.errorCode ?? ''),
        };
        _snack('❌ $reason');
        return;
      }
      final saved = await bio.enable();
      if (!mounted) return;
      if (!saved) { _snack(l10n.lockSaveFailed); return; }
      setState(() { _bioEnabled = true; _method = LockMethod.enabled; });
      _snack(l10n.lockEnabled);
    } else {
      await bio.disable();
      if (mounted) setState(() { _bioEnabled = false; _method = LockMethod.disabled; });
      _snack(AppLocalizations.of(context).lockDisabled);
    }
  }

  void _showLockHint() {
    final l10n = AppLocalizations.of(context);
    showDialog(context: context, builder: (_) => AlertDialog(
      title  : Text(l10n.lockNotEnabled),
      content: Text(l10n.lockNotEnabledBody, style: const TextStyle(height: 1.6)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.ok)),
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
    _snack(AppLocalizations.of(context).lockResetDone);
  }

  Future<void> _logout() async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(context: context,
      builder: (_) => AlertDialog(
        title  : Text(l10n.logoutConfirmTitle),
        content: Text(l10n.logoutConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: WaColors.danger),
            child: Text(l10n.logout)),
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
    final ap   = context.watch<AppProvider>();
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
        leading: Builder(builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu), onPressed: () => MenuOpener.of(context)?.onMenu())),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section(l10n.securityAndPrivacy),
          WaCard(child: Column(children: [
            _switchRow(l10n.biometricLock, l10n.biometricSub, _bioEnabled, _setBio),
            if (_bioEnabled) ...[
              const Divider(height: 1),
              _switchRow(l10n.lockOnBackground, l10n.lockOnBackgroundSub, _lockBg, _setLockBg),
              const Divider(height: 1),
              _actionRow(l10n.resetLockMethod,
                  l10n.currentMethod(_methodLabel(l10n)),
                  Icons.refresh, _resetBio),
            ],
          ])).animate().fadeIn(duration: 300.ms),

          const SizedBox(height: 14),
          _section(l10n.notifications),
          WaCard(child: Column(children: [
            _switchRow(
              l10n.budgetNotifications,
              l10n.budgetNotificationsSub,
              _notifEnabled,
              (v) async {
                await NotificationService.instance.setEnabled(v);
                setState(() => _notifEnabled = v);
                _snack(v ? l10n.notifEnabled : l10n.notifDisabled);
              },
            ),
            const Divider(height: 1),
            _actionRow(
              l10n.testNotification, l10n.testNotificationSub,
              Icons.notifications_active_outlined,
              () async {
                if (!_notifEnabled) { _snack(l10n.notifDisabledWarning); return; }
                await NotificationService.instance.showBudgetAlert(
                  categoryLabel: 'المطاعم',
                  spent: 950, limit: 1000,
                  currency: ap.currency,
                  isOver: false,
                );
                _snack(l10n.testNotifSent);
              },
            ),
          ])).animate(delay: 50.ms).fadeIn(duration: 300.ms),

          const SizedBox(height: 14),
          _section(l10n.displayAndTheme),
          WaCard(child: Column(children: [
            _switchRow(l10n.darkMode, l10n.darkModeSub, ap.isDark, (_) => ap.toggleTheme()),
            const Divider(height: 1),
            // ── Language picker ──
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l10n.language, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                ])),
                DropdownButton<String>(
                  value: ap.locale.languageCode,
                  dropdownColor: Theme.of(context).colorScheme.surface,
                  underline: const SizedBox(),
                  items: [
                    DropdownMenuItem(value: 'ar', child: Text(l10n.languageArabic, style: const TextStyle(fontSize: 13))),
                    DropdownMenuItem(value: 'en', child: Text(l10n.languageEnglish, style: const TextStyle(fontSize: 13))),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    ap.setLocale(v == 'en' ? const Locale('en','US') : const Locale('ar','SA'));
                  },
                ),
              ]),
            ),
            const Divider(height: 1),
            // ── Currency picker ──
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l10n.currency, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  Text(l10n.currentCurrency(ap.currency),
                    style: TextStyle(fontSize: 12, color: WaColors.textMuted)),
                ])),
                DropdownButton<String>(
                  value: ap.currency, dropdownColor: Theme.of(context).colorScheme.surface,
                  underline: const SizedBox(),
                  items: _currencies.map((c) => DropdownMenuItem(
                    value: c.$1,
                    child: Text(ap.locale.languageCode == 'en' ? c.$3 : c.$2,
                      style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (v) { if (v != null) ap.updateCurrency(v); },
                ),
              ]),
            ),
          ])).animate(delay: 50.ms).fadeIn(duration: 300.ms),

          const SizedBox(height: 14),
          _section(l10n.data),
          WaCard(child: Column(children: [
            _actionRow(l10n.syncData, l10n.syncDataSub,
                Icons.cloud_done_outlined, null, WaColors.success),
            const Divider(height: 1),
            _actionRow(l10n.exportCSV, l10n.exportCSVSub,
                Icons.download_outlined, ap.exportCSV),
          ])).animate(delay: 100.ms).fadeIn(duration: 300.ms),

          const SizedBox(height: 14),
          _section(l10n.aboutApp),
          WaCard(child: Column(children: [
            _infoRow(l10n.version, '1.0.0'),
            const Divider(height: 1),
            _infoRow(l10n.appName, l10n.appFullName),
            const Divider(height: 1),
            _infoRow(l10n.database, 'Firebase Firestore'),
          ])).animate(delay: 150.ms).fadeIn(duration: 300.ms),

          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _logout,
            icon : const Icon(Icons.logout, color: WaColors.danger),
            label: Text(l10n.logout,
                style: const TextStyle(color: WaColors.danger, fontWeight: FontWeight.w600)),
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

  String _methodLabel(AppLocalizations l10n) => _method == LockMethod.enabled
      ? l10n.lockMethodEnabled : l10n.lockMethodDisabled;
}
