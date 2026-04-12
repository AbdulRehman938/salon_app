import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';

import 'core/theme/app_colors.dart';
import 'features/auth/data/services/auth_service.dart';
import 'features/auth/presentation/pages/splash_page.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
    _appLinks.uriLinkStream.listen((uri) {
      _authService.handleLink(uri.toString());
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
