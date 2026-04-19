import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/services/booking_history_service.dart';
import '../widgets/dashboard_bottom_nav.dart';
import 'dashboard_page.dart';
import 'favorites_page.dart';
import 'profile_page.dart';
import 'receipt_page.dart';

class BookingsPage extends StatefulWidget {
  const BookingsPage({super.key});

  @override
  State<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends State<BookingsPage> {
  final BookingHistoryService _bookingHistoryService = BookingHistoryService();
  BookingHistoryTab _selectedTab = BookingHistoryTab.upcoming;
  bool _isCancellingBooking = false;

  Future<void> _onCancelPressed(BookingHistoryItem item) async {
    if (_isCancellingBooking) {
      return;
    }

    final shouldCancel = await _showCancelBookingSheet();
    if (!mounted || shouldCancel != true) {
      return;
    }

    await _cancelBooking(item);
  }

  Future<bool?> _showCancelBookingSheet() {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: false,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            decoration: const BoxDecoration(
              color: Color(0xFFF4F4F4),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD3D3D3),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Cancel Booking',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.dark1,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Are you sure you want to cancel?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.dark1,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Canceling your appointment will remove it\nfrom your upcoming bookings.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF6A6A6A),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(sheetContext).pop(true),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.main, width: 1.2),
                      backgroundColor: const Color(0xFFEFEFEF),
                      foregroundColor: AppColors.main,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Yes, Cancel Booking',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(sheetContext).pop(false),
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: AppColors.main,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Keep Appointment',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showCancelSuccessDialog() async {
    await showGeneralDialog<void>(
      context: context,
      barrierLabel: 'cancel-success',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 360,
              margin: const EdgeInsets.symmetric(horizontal: 14),
              padding: const EdgeInsets.fromLTRB(18, 26, 18, 18),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F3F3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: AppColors.main,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 42,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Booking Canceled',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.dark1,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Your appointment has been successfully\ncanceled.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF8A8A8A),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        if (!mounted) {
                          return;
                        }
                        setState(() {
                          _selectedTab = BookingHistoryTab.upcoming;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: AppColors.main,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Back to Bookings',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
        final scale = Tween<double>(begin: 0.92, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        );
        return FadeTransition(
          opacity: fade,
          child: ScaleTransition(scale: scale, child: child),
        );
      },
    );
  }

  Future<void> _cancelBooking(BookingHistoryItem item) async {
    setState(() {
      _isCancellingBooking = true;
    });

    try {
      await _bookingHistoryService.cancelBooking(bookingId: item.bookingId);
      if (!mounted) {
        return;
      }

      await _showCancelSuccessDialog();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to cancel booking: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCancellingBooking = false;
        });
      }
    }
  }

  Future<void> _submitReview(BookingHistoryItem item) async {
    final alreadyReviewed = await _bookingHistoryService
        .hasSubmittedReviewForBooking(item.bookingId);
    if (!mounted) {
      return;
    }

    if (alreadyReviewed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You already submitted a review for this booking.'),
        ),
      );
      return;
    }

    final ratingController = ValueNotifier<double>(5);
    final reviewController = TextEditingController();

    final didSubmit = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: SizedBox(width: 42, child: Divider(thickness: 3)),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Review ${item.salonName}',
                    style: const TextStyle(
                      color: AppColors.dark1,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ValueListenableBuilder<double>(
                    valueListenable: ratingController,
                    builder: (context, value, _) {
                      return Row(
                        children: List<Widget>.generate(5, (index) {
                          final star = index + 1;
                          return IconButton(
                            onPressed: () {
                              setSheetState(() {
                                ratingController.value = star.toDouble();
                              });
                            },
                            icon: Icon(
                              value >= star
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: const Color(0xFFFFB703),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: reviewController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Share your experience',
                      fillColor: const Color(0xFFF5F5F5),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final comment = reviewController.text.trim();
                        if (comment.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please add a short review.'),
                            ),
                          );
                          return;
                        }
                        try {
                          await _bookingHistoryService.submitReview(
                            bookingId: item.bookingId,
                            salonId: item.salonId,
                            salonName: item.salonName,
                            rating: ratingController.value,
                            comment: comment,
                          );
                          if (!context.mounted) {
                            return;
                          }
                          Navigator.of(context).pop(true);
                        } on FirebaseException catch (error) {
                          if (!context.mounted) {
                            return;
                          }
                          final message = error.code == 'already-reviewed'
                              ? 'You already submitted a review for this booking.'
                              : 'Unable to submit review right now.';
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(message)));
                        } catch (_) {
                          if (!context.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Unable to submit review right now.',
                              ),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.main,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Submit Review'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    ratingController.dispose();
    reviewController.dispose();

    if (!mounted || didSubmit != true) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Review submitted.')));
  }

  void _onBottomNavChanged(int index) {
    if (index == 1) {
      return;
    }

    if (index == 0) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DashboardPage()),
        (route) => false,
      );
      return;
    }

    if (index == 3) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ProfilePage()),
        (route) => false,
      );
      return;
    }

    if (index == 2) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const FavoritesPage()),
        (route) => false,
      );
      return;
    }
  }

  List<BookingHistoryItem> _itemsForTab(List<BookingHistoryItem> allItems) {
    return allItems.where((item) => item.tab == _selectedTab).toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 116, 12, 82),
              child: user == null
                  ? const Center(
                      child: Text(
                        'Sign in to view your bookings.',
                        style: TextStyle(
                          color: AppColors.dark1,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : StreamBuilder<List<BookingHistoryItem>>(
                      stream: _bookingHistoryService.streamMyBookings(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Unable to load bookings: ${snapshot.error}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.dark1,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }

                        final allItems =
                            snapshot.data ?? const <BookingHistoryItem>[];
                        final items = _itemsForTab(allItems);

                        if (items.isEmpty) {
                          return _EmptyBookingsState(tab: _selectedTab);
                        }

                        return ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final allowReview =
                                _selectedTab == BookingHistoryTab.completed ||
                                _selectedTab == BookingHistoryTab.cancelled;
                            return _BookingCard(
                              item: item,
                              onCancel: item.canCancel
                                  ? () => _onCancelPressed(item)
                                  : null,
                              onViewReceipt: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ReceiptPage(
                                      receipt: item.toReceiptData(),
                                    ),
                                  ),
                                );
                              },
                              onReview: allowReview
                                  ? () => _submitReview(item)
                                  : null,
                            );
                          },
                        );
                      },
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
                          const Expanded(
                            child: Text(
                              'My Bookings',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.dark1,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 62,
              left: 12,
              right: 12,
              child: _BookingsTabs(
                selectedTab: _selectedTab,
                onChanged: (tab) {
                  setState(() {
                    _selectedTab = tab;
                  });
                },
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: DashboardBottomNav(
                selectedIndex: 1,
                onChanged: _onBottomNavChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingsTabs extends StatelessWidget {
  const _BookingsTabs({required this.selectedTab, required this.onChanged});

  final BookingHistoryTab selectedTab;
  final ValueChanged<BookingHistoryTab> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget tabLink(BookingHistoryTab tab, String label) {
      final selected = selectedTab == tab;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(tab),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.main : const Color(0xFF8B8B8B),
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 5),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                height: 2,
                width: selected ? 58 : 0,
                decoration: BoxDecoration(
                  color: AppColors.main,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          tabLink(BookingHistoryTab.upcoming, 'Upcoming'),
          const SizedBox(width: 18),
          tabLink(BookingHistoryTab.completed, 'Completed'),
          const SizedBox(width: 18),
          tabLink(BookingHistoryTab.cancelled, 'Cancelled'),
        ],
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.item,
    required this.onViewReceipt,
    this.onCancel,
    this.onReview,
  });

  final BookingHistoryItem item;
  final VoidCallback onViewReceipt;
  final VoidCallback? onCancel;
  final VoidCallback? onReview;

  String _dateLabel(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.salonName,
            style: const TextStyle(
              color: AppColors.dark1,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_dateLabel(item.bookingDate)} at ${item.bookingTime}',
            style: const TextStyle(
              color: AppColors.gray1,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onViewReceipt,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.dark1,
                    side: const BorderSide(color: Color(0xFFE0E0E0)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('View Receipt'),
                ),
              ),
              if (onCancel != null || onReview != null)
                const SizedBox(width: 8),
              if (onCancel != null)
                Expanded(
                  child: ElevatedButton(
                    onPressed: onCancel,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE45757),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
              if (onReview != null)
                Expanded(
                  child: ElevatedButton(
                    onPressed: onReview,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.main,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Give Review'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyBookingsState extends StatelessWidget {
  const _EmptyBookingsState({required this.tab});

  final BookingHistoryTab tab;

  @override
  Widget build(BuildContext context) {
    String label;
    switch (tab) {
      case BookingHistoryTab.upcoming:
        label = 'No upcoming bookings.';
        break;
      case BookingHistoryTab.completed:
        label = 'No completed bookings yet.';
        break;
      case BookingHistoryTab.cancelled:
        label = 'No cancelled bookings.';
        break;
    }

    return Center(
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.gray1,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
