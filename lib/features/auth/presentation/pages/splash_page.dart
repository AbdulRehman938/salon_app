import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/services/auth_service.dart';
import '../../../dashboard/presentation/pages/dashboard_page.dart';
import 'login_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  final _authService = AuthService();
  bool _openShutter = false;
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(seconds: 1), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _openShutter = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final authChild = StreamBuilder<Object?>(
      stream: _authService.authStateChanges(),
      builder: (context, snapshot) {
        return FutureBuilder<bool>(
          future: _authService.isCurrentUserAllowed(),
          builder: (context, allowedSnapshot) {
            if (allowedSnapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox.shrink();
            }

            final isAllowed = allowedSnapshot.data ?? false;
            if (isAllowed) {
              return const DashboardPage();
            }

            return const LoginPage();
          },
        );
      },
    );

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          authChild,
          if (_showSplash)
            IgnorePointer(
              child: AnimatedSlide(
                offset: _openShutter ? const Offset(0, -1) : Offset.zero,
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeInOutCubic,
                onEnd: () {
                  if (!_openShutter || !mounted) {
                    return;
                  }
                  setState(() {
                    _showSplash = false;
                  });
                },
                child: ColoredBox(
                  color: AppColors.main,
                  child: Center(
                    child: Image.asset('assets/logo.png', width: 200),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
