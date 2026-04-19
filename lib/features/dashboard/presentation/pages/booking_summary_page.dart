import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/services/booking_checkout_service.dart';
import '../../data/services/booking_selection_service.dart';
import '../../data/services/online_payment_service.dart';
import '../../data/services/salon_data_service.dart';
import '../models/salon_detail_data.dart';
import 'payment_method_page.dart';
import 'receipt_page.dart';

class BookingSummaryPage extends StatefulWidget {
  const BookingSummaryPage({super.key, required this.salonId});

  final String salonId;

  @override
  State<BookingSummaryPage> createState() => _BookingSummaryPageState();
}

class _BookingSummaryPageState extends State<BookingSummaryPage> {
  final SalonDataService _salonDataService = SalonDataService();
  final BookingSelectionService _bookingSelectionService =
      BookingSelectionService();
  final BookingCheckoutService _bookingCheckoutService =
      BookingCheckoutService();
  final OnlinePaymentService _onlinePaymentService = OnlinePaymentService();

  int _paymentMode = 1;
  bool _isSubmitting = false;
  late final Future<_BookingSummaryStateData> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _summaryFuture = _loadSummary();
  }

  Future<_BookingSummaryStateData> _loadSummary() async {
    final results = await Future.wait<Object?>([
      _salonDataService.fetchSalonDetail(widget.salonId),
      _bookingSelectionService.getSelectedServices(salonId: widget.salonId),
      _bookingSelectionService.getStylistSelection(salonId: widget.salonId),
      _bookingSelectionService.getDateTimeSelection(salonId: widget.salonId),
    ]);

    return _BookingSummaryStateData(
      salonDetail: results[0] as SalonDetailData,
      services: results[1] as StoredServiceSelection?,
      stylist: results[2] as StoredStylistSelection?,
      dateTime: results[3] as StoredDateTimeSelection?,
    );
  }

  String _formatDistance(double km) {
    if (km == km.roundToDouble()) {
      return '${km.toStringAsFixed(0)} km';
    }
    return '${km.toStringAsFixed(1)} km';
  }

  String _formatDateLine(StoredDateTimeSelection? dateTime) {
    if (dateTime == null) {
      return '-';
    }

    const weekdays = <int, String>{
      DateTime.monday: 'Mon',
      DateTime.tuesday: 'Tue',
      DateTime.wednesday: 'Wed',
      DateTime.thursday: 'Thu',
      DateTime.friday: 'Fri',
      DateTime.saturday: 'Sat',
      DateTime.sunday: 'Sun',
    };

    const months = <int, String>{
      1: 'Jan',
      2: 'Feb',
      3: 'Mar',
      4: 'Apr',
      5: 'May',
      6: 'Jun',
      7: 'Jul',
      8: 'Aug',
      9: 'Sep',
      10: 'Oct',
      11: 'Nov',
      12: 'Dec',
    };

    final day = weekdays[dateTime.date.weekday] ?? '';
    final month = months[dateTime.date.month] ?? '';
    return '$day, $month ${dateTime.date.day} at ${dateTime.timeLabel}';
  }

  int _parseDurationInMinutes(String value) {
    final match = RegExp(r'(\d+)').firstMatch(value);
    if (match == null) {
      return 0;
    }
    return int.tryParse(match.group(1) ?? '') ?? 0;
  }

  String _formatStylistLine(
    StoredStylistSelection? stylist,
    StoredServiceSelection? services,
  ) {
    final totalDuration = services == null
        ? 0
        : services.services
              .map((service) => _parseDurationInMinutes(service.duration))
              .fold<int>(0, (acc, v) => acc + v);

    final durationLabel = totalDuration > 0 ? ' - $totalDuration Mins' : '';

    if (stylist == null) {
      return '-';
    }

    if (stylist.selectionType == 'any') {
      return 'Any stylist$durationLabel';
    }

    if (stylist.selectionType == 'multiple') {
      return 'Multiple stylists$durationLabel';
    }

    final name = (stylist.stylistName ?? 'Selected stylist').trim();
    return '$name$durationLabel';
  }

  String _formatPrice(double value) {
    return '\$${value.toStringAsFixed(2)}';
  }

  String _compactAddress(String fullAddress) {
    final parts = fullAddress
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.length >= 2) {
      return '${parts[parts.length - 2]}, ${parts[parts.length - 1]}';
    }

    return fullAddress;
  }

  Future<void> _onProceedTap(_BookingSummaryStateData summary) async {
    if (_isSubmitting) {
      return;
    }

    final services = summary.services?.services ?? const [];
    final dateTime = summary.dateTime;
    if (services.isEmpty || dateTime == null) {
      final missing = <String>[];
      if (services.isEmpty) {
        missing.add('services');
      }
      if (dateTime == null) {
        missing.add('date/time');
      }

      debugPrint('Proceed blocked: missing ${missing.join(', ')}.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Missing booking details: ${missing.join(' & ')}. Please reselect and try again.',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    final subtotal = services.fold<double>(0, (acc, item) => acc + item.charge);
    final discountPercent = dateTime.discountPercent ?? 0;
    final discountAmount = subtotal * (discountPercent / 100);
    final total = subtotal - discountAmount;

    if (_paymentMode == 0) {
      final draft = OnlineCheckoutDraft(
        salonId: summary.salonDetail.salonId,
        salonName: summary.salonDetail.name,
        bookingDateIso: dateTime.date.toIso8601String(),
        bookingTime: dateTime.timeLabel,
        stylistLabel: _formatStylistLine(summary.stylist, summary.services),
        services: services
            .map(
              (service) => OnlineCheckoutServiceItem(
                name: service.name,
                price: service.charge,
              ),
            )
            .toList(),
        discountAmount: discountAmount,
        totalAmount: total < 0 ? 0 : total,
        createdAtIso: DateTime.now().toIso8601String(),
      );

      await _onlinePaymentService.saveCheckoutDraft(draft);

      if (!mounted) {
        return;
      }

      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const PaymentMethodPage()));
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final receipt = await _bookingCheckoutService.createPayAtSalonBooking(
        salon: summary.salonDetail,
        dateTime: dateTime,
        stylist: summary.stylist,
        services: services,
        discountAmount: discountAmount,
        total: total < 0 ? 0 : total,
      );

      if (!mounted) {
        return;
      }

      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => ReceiptPage(receipt: receipt)));
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.code == 'permission-denied'
                ? 'Booking could not be saved. Check Firestore rules for bookings.'
                : (error.code == 'login-required' ||
                      error.code == 'not-authenticated' ||
                      error.code == 'session-bootstrap-unavailable')
                ? 'Your session expired. Please sign out and sign in again, then retry booking.'
                : 'Unable to create booking right now (${error.code}).',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to create booking right now: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      body: SafeArea(
        child: FutureBuilder<_BookingSummaryStateData>(
          future: _summaryFuture,
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
                        Icons.receipt_long_outlined,
                        size: 32,
                        color: AppColors.gray1,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Unable to load booking summary.',
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

            final summary = snapshot.data!;
            final salon = summary.salonDetail;
            final services = summary.services;
            final stylist = summary.stylist;
            final dateTime = summary.dateTime;

            final serviceList = services?.services ?? const [];
            final subtotal = serviceList.fold<double>(
              0,
              (acc, item) => acc + item.charge,
            );
            final discountPercent = dateTime?.discountPercent ?? 0;
            final discountAmount = subtotal * (discountPercent / 100);
            final total = subtotal - discountAmount;

            return Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12, 84, 12, 90),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9F9F9),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                width: 92,
                                height: 92,
                                child: Image.asset(
                                  salon.imageAsset,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          salon.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppColors.dark1,
                                            fontSize: 38 / 2,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        _formatDistance(salon.distanceKm),
                                        style: const TextStyle(
                                          color: AppColors.gray1,
                                          fontSize: 28 / 2,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on_outlined,
                                        size: 16,
                                        color: AppColors.gray1,
                                      ),
                                      const SizedBox(width: 3),
                                      Expanded(
                                        child: Text(
                                          _compactAddress(salon.fullAddress),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppColors.gray1,
                                            fontSize: 30 / 2,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.star,
                                        size: 18,
                                        color: Color(0xFFFFC233),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${salon.rating.toStringAsFixed(1)} (${salon.reviewsCount})',
                                        style: const TextStyle(
                                          color: AppColors.dark2,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Booking details',
                        style: TextStyle(
                          color: AppColors.dark1,
                          fontSize: 38 / 2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Date',
                        style: TextStyle(
                          color: AppColors.dark1,
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDateLine(dateTime),
                        style: const TextStyle(
                          color: AppColors.gray1,
                          fontSize: 32 / 2,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Stylist',
                        style: TextStyle(
                          color: AppColors.dark1,
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatStylistLine(stylist, services),
                        style: const TextStyle(
                          color: AppColors.gray1,
                          fontSize: 32 / 2,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Color(0xFFE7E7E7), thickness: 1),
                      const SizedBox(height: 14),
                      const Text(
                        'Payment',
                        style: TextStyle(
                          color: AppColors.dark1,
                          fontSize: 38 / 2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _PaymentTile(
                        title: 'Pay Online Now',
                        subtitle: 'Secure your booking instantly',
                        value: 0,
                        groupValue: _paymentMode,
                        onChanged: (value) {
                          setState(() {
                            _paymentMode = value;
                          });
                        },
                      ),
                      _PaymentTile(
                        title: 'Pay at Salon',
                        subtitle: 'Settle payment after your appointment',
                        value: 1,
                        groupValue: _paymentMode,
                        onChanged: (value) {
                          setState(() {
                            _paymentMode = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Color(0xFFE7E7E7), thickness: 1),
                      const SizedBox(height: 14),
                      const Text(
                        'Pricing Details',
                        style: TextStyle(
                          color: AppColors.dark1,
                          fontSize: 38 / 2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (serviceList.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 6),
                          child: Text(
                            'No selected services found.',
                            style: TextStyle(
                              color: AppColors.gray1,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                      else
                        ...serviceList.map(
                          (service) => Padding(
                            padding: const EdgeInsets.only(bottom: 7),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    service.name,
                                    style: const TextStyle(
                                      color: AppColors.gray1,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Text(
                                  _formatPrice(service.charge),
                                  style: const TextStyle(
                                    color: AppColors.gray1,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Discount',
                              style: TextStyle(
                                color: AppColors.gray1,
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            discountAmount > 0
                                ? '-${_formatPrice(discountAmount)}'
                                : _formatPrice(0),
                            style: const TextStyle(
                              color: AppColors.gray1,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Total',
                              style: TextStyle(
                                color: AppColors.dark1,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            _formatPrice(total < 0 ? 0 : total),
                            style: const TextStyle(
                              color: AppColors.dark1,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
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
                                  size: 19,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Expanded(
                                child: Text(
                                  'Booking summary',
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
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => _onProceedTap(summary),
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: const Color(0xFF2F57F0),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Continue',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
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

class _BookingSummaryStateData {
  const _BookingSummaryStateData({
    required this.salonDetail,
    required this.services,
    required this.stylist,
    required this.dateTime,
  });

  final SalonDetailData salonDetail;
  final StoredServiceSelection? services;
  final StoredStylistSelection? stylist;
  final StoredDateTimeSelection? dateTime;
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final int value;
  final int groupValue;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final isSelected = groupValue == value;

    return GestureDetector(
      onTap: () => onChanged(value),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.dark1,
                      fontSize: 20 / 1.2,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.gray1,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF2F57F0)
                      : const Color(0xFF9A9A9A),
                  width: 2,
                ),
              ),
              child: Center(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? const Color(0xFF2F57F0)
                        : Colors.transparent,
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
