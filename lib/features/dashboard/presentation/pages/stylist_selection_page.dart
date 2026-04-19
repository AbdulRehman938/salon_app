import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/services/booking_selection_service.dart';
import '../models/stylist_data.dart';
import 'date_time_selection_page.dart';

class StylistSelectionPage extends StatefulWidget {
  const StylistSelectionPage({
    super.key,
    required this.salonId,
    required this.stylists,
    required this.openingDays,
    required this.openingTiming,
    required this.discountOffer,
  });

  final String salonId;
  final List<StylistData> stylists;
  final String openingDays;
  final String openingTiming;
  final String discountOffer;

  @override
  State<StylistSelectionPage> createState() => _StylistSelectionPageState();
}

class _StylistSelectionPageState extends State<StylistSelectionPage> {
  final BookingSelectionService _bookingSelectionService =
      BookingSelectionService();
  static const int _maxMultiStylists = 5;

  String? _selectedMode;
  int? _selectedStylistIndex;
  final Set<int> _selectedStylistIndices = <int>{};

  static const List<String> _stylistImages = <String>[
    'assets/stylists/image.png',
    'assets/stylists/image_1.png',
    'assets/stylists/image_2.png',
    'assets/stylists/image_3.png',
  ];

  bool get _canContinue {
    if (_selectedMode == 'multiple') {
      return _selectedStylistIndices.isNotEmpty;
    }
    return _selectedMode != null || _selectedStylistIndex != null;
  }

  bool get _isInMultipleSelectionMode => _selectedMode == 'multiple';

  Future<void> _onContinueTap() async {
    if (!_canContinue) {
      return;
    }

    String selectionType = _selectedMode ?? 'specific';
    String? stylistName;
    String? specialty;

    if (_selectedStylistIndex != null) {
      final stylist = widget.stylists[_selectedStylistIndex!];
      stylistName = stylist.name;
      specialty = stylist.specialty;
      selectionType = 'specific';
    }

    await _bookingSelectionService.saveStylistSelection(
      salonId: widget.salonId,
      selectionType: selectionType,
      stylistName: stylistName,
      specialty: specialty,
    );

    if (_isInMultipleSelectionMode && mounted) {
      setState(() {
        _selectedMode = null;
        _selectedStylistIndices.clear();
      });
    }

    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DateTimeSelectionPage(
          salonId: widget.salonId,
          openingDays: widget.openingDays,
          openingTiming: widget.openingTiming,
          discountOffer: widget.discountOffer,
        ),
      ),
    );
  }

  void _toggleStylistSelectionInMultipleMode(int index) {
    if (_selectedStylistIndices.contains(index)) {
      setState(() {
        _selectedStylistIndices.remove(index);
      });
      return;
    }

    if (_selectedStylistIndices.length >= _maxMultiStylists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can select up to 5 stylists only.')),
      );
      return;
    }

    setState(() {
      _selectedStylistIndices.add(index);
    });
  }

  Widget _buildMultipleSelectionCheckbox(bool isSelected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: isSelected ? AppColors.main : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isSelected ? AppColors.main : const Color(0xFFCFD4DD),
          width: 1.4,
        ),
      ),
      child: isSelected
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
          : null,
    );
  }

  Widget _buildModeTile({
    required String title,
    required String subtitle,
    required String imageAsset,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.main : const Color(0xFFE9E9E9),
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F4F8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Image.asset(imageAsset, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.dark1,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.gray1,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStylistTile(StylistData stylist, int index) {
    final isInMultipleMode = _isInMultipleSelectionMode;
    final isSelected = isInMultipleMode
        ? _selectedStylistIndices.contains(index)
        : _selectedStylistIndex == index;
    final imageAsset = _stylistImages[index % _stylistImages.length];

    return GestureDetector(
      onTap: () {
        if (isInMultipleMode) {
          _toggleStylistSelectionInMultipleMode(index);
          return;
        }

        setState(() {
          _selectedMode = null;
          _selectedStylistIndex = index;
          _selectedStylistIndices.clear();
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.main : const Color(0xFFEDEDED),
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            if (isInMultipleMode) ...[
              _buildMultipleSelectionCheckbox(isSelected),
              const SizedBox(width: 12),
            ],
            ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: SizedBox(
                width: 52,
                height: 52,
                child: Image.asset(
                  imageAsset,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: const Color(0xFFECECEC),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.person_outline,
                        color: AppColors.gray1,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stylist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.dark1,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stylist.specialty,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.gray1,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (stylist.isTopRated)
              Flexible(
                fit: FlexFit.loose,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 102),
                    child: Image.asset(
                      'assets/rated.png',
                      height: 34,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 84, 14, 96),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildModeTile(
                    title: 'Any Stylist',
                    subtitle: 'Next available stylist',
                    imageAsset: 'assets/anyStylist.png',
                    isSelected: _selectedMode == 'any',
                    onTap: () {
                      setState(() {
                        _selectedStylistIndex = null;
                        _selectedMode = 'any';
                        _selectedStylistIndices.clear();
                      });
                    },
                  ),
                  _buildModeTile(
                    title: 'Multiple Stylists',
                    subtitle: _isInMultipleSelectionMode
                        ? 'Select up to 5 (${_selectedStylistIndices.length}/5 selected)'
                        : 'Choose up to 5 stylists',
                    imageAsset: 'assets/multiStylists.png',
                    isSelected: _isInMultipleSelectionMode,
                    onTap: () {
                      setState(() {
                        if (_isInMultipleSelectionMode) {
                          _selectedMode = null;
                          _selectedStylistIndices.clear();
                          return;
                        }

                        _selectedStylistIndex = null;
                        _selectedMode = 'multiple';
                      });
                    },
                  ),
                  ...List<Widget>.generate(
                    widget.stylists.length,
                    (index) => _buildStylistTile(widget.stylists[index], index),
                  ),
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
                        color: Colors.white.withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: AppColors.dark1,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Expanded(
                            child: Text(
                              'Choose your stylist',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.dark1,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 12,
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _canContinue ? _onContinueTap : null,
                    style: ElevatedButton.styleFrom(
                      elevation: 2,
                      backgroundColor: _canContinue
                          ? AppColors.main
                          : const Color(0xFFB8B8B8),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _isInMultipleSelectionMode
                          ? 'Next Stylists'
                          : 'Select & Continue',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
