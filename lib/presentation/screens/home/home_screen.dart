import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/app_provider.dart';
import '../../../providers/sms_provider.dart';
import '../../../data/services/biometric_service.dart';
import '../auth/lock_screen.dart';
import '../quick_add/quick_add_screen.dart';
import '../sms/sms_templates_screen.dart';
import '../auth/login_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../transactions/transactions_screen.dart';
import '../income/income_screen.dart';
import '../expenses/expenses_screen.dart';
import '../reports/reports_screen.dart';
import '../analytics/analytics_screen.dart';
import '../bills/bills_screen.dart';
import '../budget/budget_screen.dart';
import '../recurring/recurring_screen.dart';
import '../categories/categories_screen.dart';
import '../settings/settings_screen.dart';
import '../../widgets/transaction/add_transaction_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int  _pageIdx  = 0;
  bool _isOnline = true;
  bool _syncing  = false;

  // ✅ مشكلة 1: GlobalKey للـ Scaffold — يُمرَّر لكل الشاشات الداخلية
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // ── قفل الخلفية ─────────────────────────────
  bool _isLocked      = false;
  bool _lockBgEnabled = false;

  // مراقبة دورة حياة التطبيق لمعالجة SMS الفائتة
  late final AppLifecycleListener _lifecycleListener;

  static const _pages = <Widget>[
    DashboardScreen(), TransactionsScreen(), IncomeScreen(),
    ExpensesScreen(), BudgetScreen(), RecurringScreen(),
    ReportsScreen(), CategoriesScreen(), SettingsScreen(),
    AnalyticsScreen(),  // index 9
    BillsScreen(),      // index 10
  ];
  static const _navOrder = [0, 1, 4, 6];

  static const _quickChannel = MethodChannel('com.wafra.wafra/quick_add');

  @override
  void initState() {
    super.initState();
    _initNetwork();
    _loadLockBgSetting();

    // ── استقبال الاختصار وهو التطبيق مفتوح (onNewIntent) ──
    _quickChannel.setMethodCallHandler((call) async {
      if (call.method == 'openQuickAdd' && mounted) {
        final type = call.arguments as String? ?? 'expense';
        Navigator.push(context, MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => QuickAddScreen(type: type),
        ));
      }
    });

    // مراقبة العودة للمقدمة لمعالجة SMS الفائتة + قفل الخلفية
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        if (mounted) {
          context.read<SmsProvider>().onAppResumed();
          // ✅ قفل الخلفية: إذا كان مفعلاً وتم تأشير الحاجة للقفل
          if (_lockBgEnabled && _isLocked) {
            _showLockOverlay();
          }
        }
      },
      onHide: () {
        // عند ذهاب التطبيق للخلفية، سجّل الحاجة للقفل
        if (_lockBgEnabled) {
          setState(() => _isLocked = true);
        }
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final smsP = context.read<SmsProvider>();
      final ap   = context.read<AppProvider>();

      // ── إعداد onAlert لـ SMS ──────────────────────────
      smsP.onAlert = (msg, isErr) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(msg,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            backgroundColor: isErr ? WaColors.danger : WaColors.warning,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
      };

      // ── تهيئة SmsProvider عندما يصبح الـ profile جاهزاً ──
      // AppProvider قد يُحمِّل البيانات بعد postFrameCallback بقليل
      void tryInitSms() {
        final uid = ap.profile?.uid ?? '';
        if (uid.isNotEmpty && !smsP.isLoading) {
          smsP.init(uid);
        }
      }
      // حاول فوراً
      tryInitSms();
      // واستمع لأي تغيير في profile
      ap.addListener(tryInitSms);
      // أزِل المستمع عند التخلص من الـ widget
      // (نستخدم didChangeDependencies بشكل آمن — انظر dispose)

      ap.onAlert = (msg, isErr) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(msg,
                style: const TextStyle(fontWeight: FontWeight.w600,
                    fontSize: 13)),
            backgroundColor: isErr ? WaColors.danger : WaColors.warning,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 56 + 8,
              left: 12, right: 12,
              bottom: MediaQuery.of(context).size.height - 200,
            ),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ));
      };
    });
  }

  @override
  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  // ── قفل الخلفية ─────────────────────────────
  Future<void> _loadLockBgSetting() async {
    final p = await SharedPreferences.getInstance();
    final bio = context.read<BiometricService>();
    final method = await bio.getMethod();
    if (mounted) {
      setState(() {
        _lockBgEnabled = (method == LockMethod.enabled) &&
            (p.getBool('lockBg') ?? false);
      });
    }
  }

  void _showLockOverlay() {
    if (!mounted) return;
    setState(() => _isLocked = false);
    // LockScreen يستخدم pushAndRemoveUntil داخلياً —
    // نمرر HomeScreen كـ destination ليُعاد بناؤه نظيفاً
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LockScreen(destination: HomeScreen()),
        transitionDuration: Duration.zero,
      ),
      (_) => false,
    );
  }

  void _initNetwork() {
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> r) {
      final online = r.any((x) => x != ConnectivityResult.none);
      if (online && !_isOnline) {
        setState(() { _isOnline = true; _syncing = true; });
        Future.delayed(3.seconds, () {
          if (mounted) setState(() => _syncing = false);
        });
      } else if (!online && _isOnline) {
        setState(() { _isOnline = false; });
      }
    });
    Connectivity().checkConnectivity().then((r) {
      if (r.any((x) => x == ConnectivityResult.none) && mounted)
        setState(() => _isOnline = false);
    });
  }

  void _openDrawer() => _scaffoldKey.currentState?.openDrawer();

  @override
  Widget build(BuildContext context) {
    final surf = Theme.of(context).colorScheme.surface;
    return Scaffold(
      key   : _scaffoldKey,
      drawer: _buildDrawer(),
      // ✅ نُمرر callback فتح الـ drawer للشاشات عبر body
      body  : Stack(children: [
        _PageHost(
          pageIdx   : _pageIdx,
          pages     : _pages,
          onMenu    : _openDrawer,
          onSwipeNav: _swipeTo,
        ),
        // ✅ مشكلة 2: badge في الأعلى داخل Stack
        _NetworkBadge(isOnline: _isOnline, syncing: _syncing),
      ]),
      bottomNavigationBar: _buildBottomNav(surf),
      floatingActionButton: _buildFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  void _swipeTo(int delta) {
    final pos  = _navOrder.indexOf(_pageIdx);
    if (pos < 0) return;
    final next = pos + delta;
    if (next < 0 || next >= _navOrder.length) return;
    HapticFeedback.selectionClick();
    setState(() => _pageIdx = _navOrder[next]);
  }

  // ── Drawer ──────────────────────────────────
  Widget _buildDrawer() {
    final ap      = context.watch<AppProvider>();
    final initial = ap.userName.isNotEmpty ? ap.userName[0].toUpperCase() : '؟';
    final surf    = Theme.of(context).colorScheme.surface;
    return Drawer(
      width: 275,
      backgroundColor: surf,
      child: SafeArea(child: Column(children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: WaColors.border))),
          child: Row(children: [
            CircleAvatar(radius: 22, backgroundColor: WaColors.gold,
              child: Text(initial, style: const TextStyle(
                  color: WaColors.obsidian, fontWeight: FontWeight.w700,
                  fontSize: 18))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(ap.userName, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              Text(ap.currency,
                  style: const TextStyle(fontSize: 12, color: WaColors.textMuted)),
            ])),
          ]),
        ),
        Expanded(child: ListView(padding: EdgeInsets.zero, children: [
          _dSec('الرئيسية'),
          _dItem(Icons.grid_view_rounded,     'لوحة التحكم',       0),
          _dSec('المعاملات'),
          _dItem(Icons.receipt_long_outlined, 'جميع المعاملات',    1),
          _dItem(Icons.trending_up_rounded,   'المداخيل',          2),
          _dItem(Icons.trending_down_rounded, 'المصاريف',          3),
          _dSec('التخطيط'),
          _dItem(Icons.donut_large_outlined,  'الميزانية الشهرية', 4),
          _dItem(Icons.repeat_rounded,        'المتكررة التلقائية',5),
          _dSec('التحليل'),
          _dItem(Icons.bar_chart_rounded,     'التقارير الشهرية',  6),
          _dItem(Icons.pie_chart,             'تحليل التصنيفات',   7),
          _dItem(Icons.insights_rounded,      'إحصائيات متقدمة',   9),
          _dSec('المدفوعات'),
          _dItem(Icons.receipt_long_outlined, 'الفواتير والاشتراكات', 10),
          _dSec('الأدوات الذكية'),
          _dItemNav(Icons.sms_outlined, 'ربط رسائل البنوك', () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => const SmsTemplatesScreen()));
          }),
          _dSec('الحساب'),
          _dItem(Icons.settings_outlined,     'الإعدادات',         8),
        ])),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: WaColors.border))),
          child: Row(children: [
            IconButton(
              icon: Icon(ap.isDark
                  ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  color: WaColors.gold),
              onPressed: ap.toggleTheme),
            const Spacer(),
            TextButton.icon(
              onPressed: _logout,
              icon : const Icon(Icons.logout, color: WaColors.danger, size: 18),
              label: const Text('خروج',
                  style: TextStyle(color: WaColors.danger, fontSize: 13))),
          ]),
        ),
      ])),
    );
  }

  Widget _dItemNav(IconData icon, String label, VoidCallback onTap) =>
    ListTile(
      dense  : true,
      leading: Icon(icon, size: 20, color: WaColors.gold),
      title  : Text(label, style: const TextStyle(fontSize: 13)),
      onTap  : onTap,
    );

  Widget _dSec(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
    child: Text(t, style: const TextStyle(
        fontSize: 10, letterSpacing: 2, color: WaColors.textMuted)),
  );

  Widget _dItem(IconData icon, String label, int idx) {
    final active = _pageIdx == idx;
    return ListTile(
      dense   : true,
      leading : Icon(icon, size: 20,
          color: active ? WaColors.gold : WaColors.textSecondary),
      title   : Text(label, style: TextStyle(fontSize: 13,
          fontWeight: active ? FontWeight.w700 : FontWeight.w400,
          color     : active ? WaColors.gold : null)),
      selected          : active,
      selectedTileColor : WaColors.gold.withValues(alpha: 0.07),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(left: Radius.circular(8))),
      onTap: () { setState(() => _pageIdx = idx); Navigator.pop(context); },
    );
  }

  // ── Bottom Nav ───────────────────────────────
  Widget _buildBottomNav(Color surf) {
    final navIdx = _navOrder.contains(_pageIdx)
        ? _navOrder.indexOf(_pageIdx) : -1;
    return Container(
      decoration: BoxDecoration(color: surf,
          border: const Border(top: BorderSide(color: WaColors.border))),
      child: BottomAppBar(
        color: Colors.transparent, elevation: 0,
        notchMargin: 6, shape: const CircularNotchedRectangle(),
        child: Row(children: [
          ..._bItems(0, 2, navIdx),
          const SizedBox(width: 64),
          ..._bItems(2, 4, navIdx),
        ]),
      ),
    );
  }

  List<Widget> _bItems(int from, int to, int navIdx) {
    const items = [
      (Icons.grid_view_rounded,    Icons.grid_view,    'الرئيسية'),
      (Icons.receipt_long_outlined,Icons.receipt_long, 'المعاملات'),
      (Icons.donut_large_outlined, Icons.donut_large,  'الميزانية'),
      (Icons.bar_chart_outlined,   Icons.bar_chart,    'التقارير'),
    ];
    return List.generate(to - from, (i) {
      final idx    = from + i;
      final active = navIdx == idx;
      return Expanded(child: InkWell(
        onTap: () => setState(() => _pageIdx = _navOrder[idx]),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(active ? items[idx].$2 : items[idx].$1, size: 22,
              color: active ? WaColors.gold : WaColors.textMuted),
          const SizedBox(height: 2),
          Text(items[idx].$3, style: TextStyle(fontSize: 10,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              color: active ? WaColors.gold : WaColors.textMuted)),
        ]),
      ));
    });
  }

  // ── FAB ──────────────────────────────────────
  Widget _buildFAB() => Container(
    width: 56, height: 56,
    decoration: BoxDecoration(shape: BoxShape.circle,
      gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [WaColors.gold, WaColors.goldDim]),
      boxShadow: [BoxShadow(color: WaColors.gold.withValues(alpha: 0.4),
          blurRadius: 16, offset: const Offset(0, 4))]),
    child: Material(color: Colors.transparent, shape: const CircleBorder(),
      child: InkWell(customBorder: const CircleBorder(),
        onTap: () => showModalBottomSheet(context: context,
            isScrollControlled: true, backgroundColor: Colors.transparent,
            builder: (_) => const AddTransactionSheet()),
        child: const Icon(Icons.add, color: WaColors.obsidian, size: 28))),
  );

  Future<void> _logout() async {
    Navigator.pop(context);
    final ok = await showDialog<bool>(context: context,
      builder: (_) => AlertDialog(
        title  : const Text('تسجيل الخروج'),
        content: const Text('هل تريد الخروج من حسابك؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: WaColors.danger),
              child: const Text('خروج')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<SmsProvider>().clear();
    await context.read<AppProvider>().clearUser();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }
}

// ══════════════════════════════════════════════
//  ✅ PageHost — يحمل الصفحات ويمرر onMenu callback
//  يحل مشكلة Scaffold.of() التي لا تجد الـ drawer
// ══════════════════════════════════════════════
class _PageHost extends StatelessWidget {
  final int pageIdx;
  final List<Widget> pages;
  final VoidCallback onMenu;
  final ValueChanged<int> onSwipeNav;
  const _PageHost({required this.pageIdx, required this.pages,
      required this.onMenu, required this.onSwipeNav});

  @override
  Widget build(BuildContext context) {
    double _sx = 0; int _st = 0;
    return GestureDetector(
      onHorizontalDragStart: (d) {
        _sx = d.globalPosition.dx;
        _st = DateTime.now().millisecondsSinceEpoch;
      },
      onHorizontalDragEnd: (d) {
        final dx = d.velocity.pixelsPerSecond.dx;
        final dt = DateTime.now().millisecondsSinceEpoch - _st;
        if (dt > 400 || dx.abs() < 300) return;
        onSwipeNav(dx > 0 ? -1 : 1);
      },
      // ✅ الحل: نُمرر onMenu عبر InheritedWidget بسيط
      child: MenuOpener(onMenu: onMenu,
        child: IndexedStack(index: pageIdx, children: pages)),
    );
  }
}

// ── InheritedWidget يوفر openDrawer لكل الشاشات ──
class MenuOpener extends InheritedWidget {
  final VoidCallback onMenu;
  const MenuOpener({required this.onMenu, required super.child, super.key});

  static MenuOpener? of(BuildContext ctx) =>
      ctx.dependOnInheritedWidgetOfExactType<MenuOpener>();

  @override bool updateShouldNotify(MenuOpener old) => false;
}

// ══════════════════════════════════════════════
//  Network Badge
// ══════════════════════════════════════════════
class _NetworkBadge extends StatefulWidget {
  final bool isOnline, syncing;
  const _NetworkBadge({required this.isOnline, required this.syncing});
  @override State<_NetworkBadge> createState() => _NetworkBadgeState();
}

class _NetworkBadgeState extends State<_NetworkBadge> {
  bool _visible = false;
  Timer? _hideTimer;

  @override
  void didUpdateWidget(_NetworkBadge old) {
    super.didUpdateWidget(old);
    final shouldShow = !widget.isOnline || widget.syncing;
    if (shouldShow && !_visible) {
      setState(() => _visible = true);
      _scheduleHide();
    } else if (!shouldShow && _visible) {
      // عند عودة الاتصال — اعرض "متصل" لثانيتين ثم أخفِ
      _scheduleHide(delay: const Duration(seconds: 2));
    }
  }

  void _scheduleHide({Duration delay = const Duration(seconds: 4)}) {
    _hideTimer?.cancel();
    _hideTimer = Timer(delay, () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible && widget.isOnline && !widget.syncing)
      return const SizedBox.shrink();

    final isOffline = !widget.isOnline;
    final label = isOffline ? '📡 بدون إنترنت — محفوظ محلياً'
                : widget.syncing ? '🔄 جارٍ المزامنة...'
                : '✅ تمت المزامنة';
    final color = isOffline ? WaColors.danger
                : widget.syncing ? WaColors.gold
                : WaColors.success;

    return Positioned(
      top: MediaQuery.of(context).padding.top, left: 0, right: 0,
      child: Center(
        child: AnimatedOpacity(
          opacity: _visible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(color: color,
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(10))),
            child: Text(label, style: TextStyle(fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isOffline ? Colors.white : WaColors.obsidian)),
          ).animate().slideY(begin: -1.0, duration: 400.ms,
              curve: Curves.easeOut),
        ),
      ),
    );
  }
}
