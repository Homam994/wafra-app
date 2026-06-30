import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/app_theme.dart';
import 'core/constants/categories.dart';
import 'data/repositories/firestore_repo.dart';
import 'data/services/auth_service.dart';
import 'data/services/biometric_service.dart';
import 'data/models/models.dart';
import 'providers/app_provider.dart';
import 'providers/sms_provider.dart';
import 'data/services/sms_storage_service.dart';
import 'data/services/sms_parser.dart';
import 'presentation/screens/auth/splash_screen.dart';
import 'firebase_options.dart';
import 'data/services/notification_service.dart';
import 'generated/l10n/app_localizations.dart';
import 'generated/l10n/app_localizations_ar.dart';
import 'generated/l10n/app_localizations_en.dart';

// ════════════════════════════════════════════════════════════
// MAIN APP ENTRY POINT
// ════════════════════════════════════════════════════════════
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes    : Settings.CACHE_SIZE_UNLIMITED,
    );
    await NotificationService.instance.init();
  } catch (e) {
    debugPrint('Firebase/Notifications init error: $e');
  }

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor         : Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const WafraApp());
}

class WafraApp extends StatelessWidget {
  const WafraApp({super.key});

  @override
  Widget build(BuildContext context) {
    final repo       = FirestoreRepo(FirebaseFirestore.instance);
    final auth       = AuthService(FirebaseAuth.instance);
    final biometric  = BiometricService();
    final smsStorage = SmsStorageService();
    final smsParser  = SmsParser();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AppProvider(repo, auth)..loadTheme(),
        ),
        Provider<AuthService>.value(value: auth),
        Provider<BiometricService>.value(value: biometric),
        ChangeNotifierProvider(
          create: (_) => SmsProvider(smsStorage, smsParser, repo),
        ),
      ],
      child: Consumer<AppProvider>(
        builder: (_, ap, __) {
          final isArabic = ap.locale.languageCode == 'ar';
          return MaterialApp(
            title                     : 'وفرة',
            debugShowCheckedModeBanner: false,
            theme    : WaTheme.light().copyWith(
              snackBarTheme: const SnackBarThemeData(
                behavior     : SnackBarBehavior.floating,
                insetPadding : EdgeInsets.fromLTRB(16, 0, 16, 16),
              ),
            ),
            darkTheme: WaTheme.dark().copyWith(
              snackBarTheme: const SnackBarThemeData(
                behavior     : SnackBarBehavior.floating,
                insetPadding : EdgeInsets.fromLTRB(16, 0, 16, 16),
              ),
            ),
            themeMode: ap.isDark ? ThemeMode.dark : ThemeMode.light,

            locale: ap.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],

            builder: (ctx, child) => Directionality(
              textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
              child: child!,
            ),

            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// QUICK ADD ENTRY POINT (مستقل تماماً — يُستدعى من QuickAddActivity)
// ════════════════════════════════════════════════════════════
@pragma('vm:entry-point')
void quickAddMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (_) {}

  // اجلب كل البيانات اللازمة قبل بناء أي widget — لا حاجة لشاشة loading
  // ولا لإعادة بناء MaterialApp بالكامل بعد ذلك
  final type   = await _quickGetType();
  final prefs  = await SharedPreferences.getInstance();
  final lang   = prefs.getString('language') ?? 'ar';
  final isDark = prefs.getBool('isDark') ?? true;

  runApp(QuickAddRoot(
    initialType: type,
    lang       : lang,
    isDark     : isDark,
  ));
}

const _quickStandaloneChannel = MethodChannel('com.wafra.wafra/quick_standalone');

Future<String> _quickGetType() async {
  try {
    return await _quickStandaloneChannel.invokeMethod<String>('getType') ?? 'expense';
  } catch (_) {
    return 'expense';
  }
}

void _quickCloseActivity() {
  try {
    _quickStandaloneChannel.invokeMethod('close');
  } catch (_) {}
}

class QuickAddRoot extends StatelessWidget {
  final String initialType;
  final String lang;
  final bool   isDark;
  const QuickAddRoot({
    super.key,
    required this.initialType,
    required this.lang,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = lang == 'en'
        ? AppLocalizationsEn() as AppLocalizations
        : AppLocalizationsAr() as AppLocalizations;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme    : WaTheme.light(),
      darkTheme: WaTheme.dark(),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      locale   : Locale(lang),
      home     : Directionality(
        textDirection: lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        child: QuickAddStandaloneScreen(
          initialType: initialType,
          lang       : lang,
          l10n       : l10n,
          isDark     : isDark,
          onClose    : _quickCloseActivity,
        ),
      ),
    );
  }
}

class QuickAddStandaloneScreen extends StatefulWidget {
  final String           initialType;
  final String           lang;
  final AppLocalizations l10n;
  final bool             isDark;
  final VoidCallback     onClose;
  const QuickAddStandaloneScreen({
    super.key,
    required this.initialType,
    required this.lang,
    required this.l10n,
    required this.isDark,
    required this.onClose,
  });
  @override
  State<QuickAddStandaloneScreen> createState() => _QuickAddStandaloneScreenState();
}

class _QuickAddStandaloneScreenState extends State<QuickAddStandaloneScreen> {
  late TxType _type;
  String? _cat;
  bool _saving  = false;
  bool _success = false;

  final _amountCtrl = TextEditingController();
  final _noteCtrl   = TextEditingController();
  final _focus      = FocusNode();

  @override
  void initState() {
    super.initState();
    _type = widget.initialType == 'income' ? TxType.income : TxType.expense;
    _forceShowKeyboard();
  }

  // محاولات متعددة لإجبار ظهور الكيبورد — Android أحياناً يحتاج أكثر من محاولة
  // لأن الـ window قد لا يملك focus بعد عند أول frame
  void _forceShowKeyboard() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      for (final delayMs in [50, 200, 400, 700]) {
        await Future.delayed(Duration(milliseconds: delayMs));
        if (!mounted) return;
        FocusScope.of(context).requestFocus(_focus);
        await SystemChannels.textInput.invokeMethod('TextInput.show');
      }
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<WaCategory> get _cats =>
      _type == TxType.expense ? kExpenseCategories : kIncomeCategories;

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _save() async {
    final isAr = widget.lang == 'ar';
    final amt  = double.tryParse(_amountCtrl.text.replaceAll(',', '.'));

    if (amt == null || amt <= 0) {
      _snack(isAr ? 'أدخل مبلغاً صحيحاً' : 'Enter a valid amount');
      return;
    }
    if (_cat == null) {
      _snack(isAr ? 'اختر التصنيف' : 'Choose a category');
      return;
    }

    setState(() => _saving = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (uid.isEmpty) {
        _snack(isAr ? 'غير مسجّل الدخول' : 'Not signed in');
        if (mounted) setState(() => _saving = false);
        return;
      }

      final tx = TxModel(
        id       : '',
        type     : _type,
        cat      : _cat!,
        sub      : '',
        amount   : amt,
        note     : _noteCtrl.text.trim(),
        date     : DateTime.now().toIso8601String().split('T').first,
        createdAt: DateTime.now(),
      );

      FirestoreRepo(FirebaseFirestore.instance).addTx(uid, tx);

      HapticFeedback.mediumImpact();
      if (!mounted) return;
      setState(() {
        _saving  = false;
        _success = true;
      });

      await Future.delayed(const Duration(milliseconds: 700));
      widget.onClose();
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      _snack('$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isExpense = _type == TxType.expense;
    final accent    = isExpense ? WaColors.danger : WaColors.success;
    final isDark    = widget.isDark;
    final isAr      = widget.lang == 'ar';
    final lang      = widget.lang;
    final fieldBg   = isDark ? WaColors.obsidian2 : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A2E);

    return Scaffold(
      backgroundColor: isDark ? WaColors.obsidian : const Color(0xFFF5F3EE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation      : 0,
        leading        : IconButton(
          icon     : Icon(Icons.close,
              color: isDark ? Colors.white70 : Colors.black54),
          onPressed: widget.onClose,
        ),
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            isExpense ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
            color: accent,
            size : 18,
          ),
          const SizedBox(width: 6),
          Text(
            isExpense
                ? (isAr ? 'مصروف سريع' : 'Quick Expense')
                : (isAr ? 'دخل سريع'    : 'Quick Income'),
            style: TextStyle(fontSize: 16, color: accent, fontWeight: FontWeight.w700),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => setState(() {
              _type = isExpense ? TxType.income : TxType.expense;
              _cat  = null;
            }),
            child: Text(
              isExpense
                  ? (isAr ? '← دخل'    : '← Income')
                  : (isAr ? '← مصروف'  : '← Expense'),
              style: const TextStyle(fontSize: 13, color: WaColors.textMuted),
            ),
          ),
        ],
      ),
      body: _success
          ? _buildSuccess(accent, isAr)
          : _buildForm(accent, fieldBg, textColor, lang, isAr),
    );
  }

  Widget _buildSuccess(Color accent, bool isAr) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.check_circle_rounded, color: accent, size: 80),
      const SizedBox(height: 16),
      Text(
        isAr ? 'تم الحفظ ✓' : 'Saved ✓',
        style: TextStyle(fontSize: 22, color: accent, fontWeight: FontWeight.w700),
      ),
    ]),
  );

  Widget _buildForm(
      Color accent, Color fieldBg, Color textColor, String lang, bool isAr) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color       : fieldBg,
              borderRadius: BorderRadius.circular(16),
              border      : Border.all(color: accent.withValues(alpha: 0.4), width: 2),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(children: [
              Text(widget.l10n.currency,
                  style: TextStyle(fontSize: 18, color: WaColors.textMuted)),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller  : _amountCtrl,
                  focusNode   : _focus,
                  autofocus   : true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign   : TextAlign.center,
                  style: TextStyle(
                      fontSize: 38, fontWeight: FontWeight.w700, color: accent),
                  decoration: InputDecoration(
                    border  : InputBorder.none,
                    hintText: '0',
                    hintStyle:
                        TextStyle(color: accent.withValues(alpha: 0.3), fontSize: 38),
                  ),
                ),
              ),
            ]),
          ),

          const SizedBox(height: 20),

          Text(
            isAr ? 'التصنيف' : 'Category',
            style: const TextStyle(
                fontSize: 12, color: WaColors.textMuted, letterSpacing: 1),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing  : 8,
            runSpacing: 8,
            children : _cats.map((cat) {
              final sel = _cat == cat.id;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _cat = sel ? null : cat.id);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color       : sel ? accent : fieldBg,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: sel ? accent : WaColors.border.withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                    boxShadow: sel
                        ? [BoxShadow(color: accent.withValues(alpha: 0.3), blurRadius: 8)]
                        : null,
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(cat.emoji, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 5),
                    Text(
                      cat.localizedLabel(lang),
                      style: TextStyle(
                        fontSize  : 13,
                        fontWeight: FontWeight.w600,
                        color     : sel ? Colors.white : textColor,
                      ),
                    ),
                  ]),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          TextField(
            controller: _noteCtrl,
            maxLines  : 2,
            style     : TextStyle(color: textColor),
            decoration: InputDecoration(
              hintText : isAr ? 'ملاحظة (اختياري)...' : 'Note (optional)...',
              hintStyle: TextStyle(color: WaColors.textMuted.withValues(alpha: 0.6)),
              filled   : true,
              fillColor: fieldBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide  : const BorderSide(color: WaColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide  : BorderSide(color: WaColors.border.withValues(alpha: 0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide  : BorderSide(color: accent, width: 2),
              ),
            ),
          ),

          const SizedBox(height: 28),

          SizedBox(
            height: 54,
            child : ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor       : accent,
                foregroundColor       : Colors.white,
                disabledBackgroundColor: accent.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 2,
              ),
              child: _saving
                  ? const SizedBox(
                      width : 24,
                      height: 24,
                      child : CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      isAr ? 'حفظ' : 'Save',
                      style:
                          const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
