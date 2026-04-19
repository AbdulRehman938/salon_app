import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/services/salon_data_service.dart';
import '../models/salon_card_data.dart';
import '../widgets/dashboard_bottom_nav.dart';
import '../widgets/salon_card.dart';
import 'bookings_page.dart';
import 'dashboard_page.dart';
import 'profile_page.dart';
import 'salon_detail_page.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final SalonDataService _salonDataService = SalonDataService();

  bool _isLoading = true;
  List<SalonCardData> _favoriteSalons = <SalonCardData>[];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final favorites = await _salonDataService
          .fetchFavoriteSalonsForCurrentUser();
      if (!mounted) {
        return;
      }
      setState(() {
        _favoriteSalons = favorites;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _favoriteSalons = <SalonCardData>[];
        _isLoading = false;
      });
    }
  }

  Future<void> _openSalonDetail(SalonCardData salon) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SalonDetailPage(salonId: salon.salonId),
      ),
    );

    if (!mounted) {
      return;
    }
    await _loadFavorites();
  }

  void _onBottomNavChanged(int index) {
    if (index == 2) {
      return;
    }

    if (index == 0) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DashboardPage()),
        (route) => false,
      );
      return;
    }

    if (index == 1) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const BookingsPage()),
        (route) => false,
      );
      return;
    }

    if (index == 3) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ProfilePage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Row(
                children: const [
                  Icon(Icons.favorite_rounded, color: AppColors.main),
                  SizedBox(width: 8),
                  Text(
                    'My Favourites',
                    style: TextStyle(
                      color: AppColors.dark1,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadFavorites,
                      child: _favoriteSalons.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                40,
                                20,
                                100,
                              ),
                              children: const [
                                Icon(
                                  Icons.favorite_border_rounded,
                                  size: 54,
                                  color: AppColors.gray2,
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'No favourites yet',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.dark1,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Tap the heart on any salon detail page to add it here.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.gray1,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            )
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                              children: _favoriteSalons
                                  .map(
                                    (salon) => SalonCard(
                                      salon: salon,
                                      onTap: () => _openSalonDetail(salon),
                                    ),
                                  )
                                  .toList(),
                            ),
                    ),
            ),
            DashboardBottomNav(
              selectedIndex: 2,
              onChanged: _onBottomNavChanged,
            ),
          ],
        ),
      ),
    );
  }
}
