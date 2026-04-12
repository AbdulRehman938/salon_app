import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.mainLight,
        title: const Text('Dashboard'),
      ),
      body: Center(
        child: Text(
          'Dashboard is ready',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(color: AppColors.dark1),
        ),
      ),
    );
  }
}
