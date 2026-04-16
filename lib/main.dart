import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/theme/app_colors.dart';
import 'features/auth/data/services/auth_service.dart';
import 'features/auth/presentation/pages/splash_page.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    // Web build cannot reliably serve hidden `.env` assets, but dotenv
    // must still be initialized before accessing dotenv.env.
    dotenv.testLoad(fileInput: '');
  } else {
    await dotenv.load(fileName: '.env', isOptional: true);
  }
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (kIsWeb) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
      webExperimentalForceLongPolling: true,
      webExperimentalAutoDetectLongPolling: true,
    );
  }
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _appLinks = AppLinks();
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  void _initDeepLinks() {
    // Listen for the link while the app is running or backgrounded.
    _appLinks.uriLinkStream.listen((uri) async {
      final link = uri.toString();
      final isEmailLink = _authService.isEmailLink(link);
      if (!isEmailLink || !_authService.hasPendingEmailForLink) {
        return;
      }

      await _authService.handleLink(
        link,
        email: _authService.pendingEmailForLink,
      );
      _authService.clearPendingEmailForLink();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Salon App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.main),
        scaffoldBackgroundColor: AppColors.mainLight,
      ),
      home: const SplashPage(),
    );
  }
}
