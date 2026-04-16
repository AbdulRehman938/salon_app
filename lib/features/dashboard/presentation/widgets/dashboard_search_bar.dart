import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class DashboardSearchBar extends StatelessWidget {
  const DashboardSearchBar({super.key, required this.onTap, this.searchText});

  final VoidCallback onTap;
  final String? searchText;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFECECEC),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: AppColors.gray1),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Enter address or city name',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.gray1,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
