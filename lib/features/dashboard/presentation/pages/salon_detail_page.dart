import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/services/booking_selection_service.dart';
import '../../data/services/salon_data_service.dart';
import '../models/salon_detail_data.dart';
import '../models/salon_sub_service_data.dart';
import 'stylist_selection_page.dart';

class SalonDetailPage extends StatefulWidget {
  const SalonDetailPage({super.key, required this.salonId});

  final String salonId;

  @override
  State<SalonDetailPage> createState() => _SalonDetailPageState();
}

class _SalonDetailPageState extends State<SalonDetailPage> {
  final SalonDataService _salonDataService = SalonDataService();
  final BookingSelectionService _bookingSelectionService =
      BookingSelectionService();

  late final Future<SalonDetailData> _detailFuture;
  bool _isFavorite = false;
  bool _isFavoriteLoading = false;
  int _selectedPillIndex = 0;
  final Set<String> _selectedSubServiceKeys = <String>{};

  @override
  void initState() {
    super.initState();
    _detailFuture = _salonDataService.fetchSalonDetail(widget.salonId);
    _loadFavoriteState();
  }

  Future<void> _loadFavoriteState() async {
    try {
      final isFavorite = await _salonDataService.isSalonFavoriteForCurrentUser(
        widget.salonId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isFavorite = isFavorite;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isFavorite = false;
      });
    }
  }

  Future<void> _onFavoriteTap() async {
    if (_isFavoriteLoading) {
      return;
    }

    final next = !_isFavorite;
    setState(() {
      _isFavorite = next;
      _isFavoriteLoading = true;
    });

    try {
      await _salonDataService.setSalonFavoriteForCurrentUser(
        salonId: widget.salonId,
        isFavorite: next,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isFavorite = !next;
      });

      var message = 'Unable to save favorite right now.';
      if (error is FirebaseAuthException && error.code == 'not-signed-in') {
        message = 'Sign in is required to save favorites.';
      } else if (error is FirebaseException &&
          error.code == 'permission-denied') {
        message = 'Permission denied while saving favorite.';
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() {
          _isFavoriteLoading = false;
        });
      }
    }
  }

  String _subServiceKey(SalonSubServiceData service) {
    return '${service.name}|${service.duration}|${service.charge.toStringAsFixed(2)}';
  }

  void _toggleSubServiceSelection(SalonSubServiceData service) {
    final key = _subServiceKey(service);
    setState(() {
      if (_selectedSubServiceKeys.contains(key)) {
        _selectedSubServiceKeys.remove(key);
      } else {
        _selectedSubServiceKeys.add(key);
      }
    });
  }

  String _formatPrice(double charge) {
    return '\$${charge.toStringAsFixed(2)}';
  }

  Future<void> _onContinueTap(SalonDetailData detail) async {
    final selectedServices = detail.subServices.where((service) {
      return _selectedSubServiceKeys.contains(_subServiceKey(service));
    }).toList();

    if (selectedServices.isEmpty) {
      return;
    }

    await _bookingSelectionService.saveSelectedServices(
      salonId: detail.salonId,
      services: selectedServices,
    );

    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StylistSelectionPage(
          salonId: detail.salonId,
          stylists: detail.stylists,
          openingDays: detail.openingDays,
          openingTiming: detail.openingTiming,
          discountOffer: detail.discountOffer,
        ),
      ),
    );
  }

  Widget _buildIconActionButton({
    required IconData icon,
    required VoidCallback onTap,
    Color iconColor = AppColors.dark1,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFEDEDED),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required Widget content,
    Color iconColor = AppColors.gray1,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 6),
        Expanded(child: content),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<SalonDetailData>(
          future: _detailFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.storefront_outlined,
                        size: 32,
                        color: AppColors.gray1,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Unable to load salon details.',
                        style: TextStyle(
                          color: AppColors.dark1,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Go Back'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final detail = snapshot.data!;
            final selectedPill = detail.servicePills[_selectedPillIndex];
            final visibleSubServices = detail.subServices
                .where((service) => service.category == selectedPill)
                .toList();
            final selectedCount = _selectedSubServiceKeys.length;

            return Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 84, 16, 96),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AspectRatio(
                          aspectRatio: 1.55,
                          child: Image.asset(
                            detail.imageAsset,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: const Color(0xFFE7E7E7),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.image_outlined,
                                  size: 34,
                                  color: AppColors.gray2,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        detail.name,
                        style: const TextStyle(
                          fontSize: 40 / 2,
                          fontWeight: FontWeight.w700,
                          color: AppColors.dark1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        icon: Icons.location_on_outlined,
                        content: Text(
                          detail.fullAddress,
                          style: const TextStyle(
                            color: AppColors.gray1,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildInfoRow(
                        icon: Icons.access_time_rounded,
                        content: Text(
                          '${detail.openingTiming}, ${detail.openingDays}',
                          style: const TextStyle(
                            color: AppColors.gray1,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildInfoRow(
                        icon: Icons.star_rounded,
                        iconColor: const Color(0xFFFFC233),
                        content: Text(
                          '${detail.rating.toStringAsFixed(1)} (${detail.reviewsCount})',
                          style: const TextStyle(
                            color: AppColors.gray1,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        detail.shortDescription,
                        style: const TextStyle(
                          color: AppColors.gray1,
                          height: 1.45,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: List<Widget>.generate(
                            detail.servicePills.length,
                            (index) {
                              final label = detail.servicePills[index];
                              final isSelected = index == _selectedPillIndex;

                              return GestureDetector(
                                onTap: () {
                                  if (isSelected) {
                                    return;
                                  }
                                  setState(() {
                                    _selectedPillIndex = index;
                                  });
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(right: 18),
                                  padding: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: isSelected
                                            ? AppColors.main
                                            : Colors.transparent,
                                        width: 3,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      color: isSelected
                                          ? AppColors.main
                                          : const Color(0xFF8D8D8D),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (visibleSubServices.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 18,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Text(
                            'No services available for this category.',
                            style: TextStyle(
                              color: AppColors.gray1,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else
                        ...visibleSubServices.map((
                          SalonSubServiceData service,
                        ) {
                          final key = _subServiceKey(service);
                          final isSelected = _selectedSubServiceKeys.contains(
                            key,
                          );

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        service.name,
                                        style: const TextStyle(
                                          color: AppColors.dark1,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Row(
                                        children: [
                                          Text(
                                            _formatPrice(service.charge),
                                            style: const TextStyle(
                                              color: AppColors.gray1,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          const Icon(
                                            Icons.access_time_rounded,
                                            size: 15,
                                            color: AppColors.gray1,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            service.duration,
                                            style: const TextStyle(
                                              color: AppColors.gray1,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () =>
                                      _toggleSubServiceSelection(service),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeInOut,
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.main
                                          : Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.main
                                            : AppColors.dark1,
                                        width: 2,
                                      ),
                                    ),
                                    child: AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      transitionBuilder: (child, animation) {
                                        return ScaleTransition(
                                          scale: animation,
                                          child: child,
                                        );
                                      },
                                      child: Icon(
                                        isSelected
                                            ? Icons.check_rounded
                                            : Icons.add,
                                        key: ValueKey<bool>(isSelected),
                                        color: isSelected
                                            ? Colors.white
                                            : AppColors.dark1,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 12,
                  right: 12,
                  child: SafeArea(
                    bottom: false,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          height: 56,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.78),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              _buildIconActionButton(
                                icon: Icons.arrow_back_ios_new_rounded,
                                onTap: () => Navigator.of(context).pop(),
                              ),
                              const SizedBox(width: 6),
                              const Expanded(
                                child: Text(
                                  'Salon details',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.dark1,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              _buildIconActionButton(
                                icon: _isFavorite
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                iconColor: _isFavorite
                                    ? const Color(0xFFE33D5E)
                                    : AppColors.dark1,
                                onTap: _onFavoriteTap,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 12,
                  child: IgnorePointer(
                    ignoring: selectedCount == 0,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      opacity: selectedCount > 0 ? 1 : 0,
                      child: SafeArea(
                        top: false,
                        child: SizedBox(
                          height: 52,
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: selectedCount > 0
                                ? () => _onContinueTap(detail)
                                : null,
                            style: ElevatedButton.styleFrom(
                              elevation: 4,
                              backgroundColor: AppColors.main,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              'Continue ($selectedCount)',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
