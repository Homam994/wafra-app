import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/app_theme.dart';
import 'data/repositories/firestore_repo.dart';
import 'data/services/auth_service.dart';
import 'data/services/biometric_service.dart';
import 'providers/app_provider.dart';
import 'providers/sms_provider.dart';
import 'data/services/sms_storage_service.dart';
import 'data/services/sms_parser.dart';
import 'presentation/screens/auth/splash_screen.dart';
import 'firebase_options.dart';

import 'data/services/notification_service.dart';

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
    // ── تهيئة الإشعارات بعد Firebase مباشرة ──
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
    final repo      = FirestoreRepo(FirebaseFirestore.instance);
    final auth      = AuthService(FirebaseAuth.instance);
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
        builder: (_, ap, __) => MaterialApp(
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
          themeMode                 : ap.isDark ? ThemeMode.dark : ThemeMode.light,

          locale: const Locale('ar', 'SA'),
          supportedLocales: const [
            Locale('ar', 'SA'),
            Locale('en', 'US'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],

          // RTL كـ wrapper عالمي
          builder: (ctx, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          ),

          home: const SplashScreen(),
        ),
      ),
    );
  }
}
