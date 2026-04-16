import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../auth/data/services/auth_service.dart';
import '../../presentation/models/salon_sub_service_data.dart';
import 'booking_checkout_service.dart';
import 'online_payment_service.dart';

enum BookingHistoryTab { upcoming, completed, cancelled }

class BookingHistoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();
  final OnlinePaymentService _onlinePaymentService = OnlinePaymentService();

  Future<User?> _resolveCurrentUser() async {
    var user = _auth.currentUser;
    if (user != null) {
      return user;
    }

    final sessionEmail = await _authService.getSessionVerifiedEmail();
    if (sessionEmail == null || sessionEmail.isEmpty) {
      return null;
    }

    try {
      user = await _authService.ensureAuthenticatedSessionForVerifiedEmail(
        sessionEmail,
      );
    } on FirebaseAuthException {
      user = await _authService.refreshCurrentUser();
    }

    return user;
  }

  Future<({User? user, String? sessionEmail})> _resolveBookingIdentity() async {
    final user = await _resolveCurrentUser();
    final sessionEmail = await _authService.getSessionVerifiedEmail();
    return (user: user, sessionEmail: sessionEmail);
  }

  String _reviewDocId(String bookingId, String uid) {
    return '${bookingId}_$uid';
  }

  Stream<List<BookingHistoryItem>> streamMyBookings() {
    return Stream<({User? user, String? sessionEmail})>.fromFuture(
      _resolveBookingIdentity(),
    ).asyncExpand((identity) {
      final user = identity.user;
      if (user == null) {
        return Stream<List<BookingHistoryItem>>.value(
          const <BookingHistoryItem>[],
        );
      }

      final isEmailOtpAnonymousSession = user.isAnonymous;
      final normalizedSessionEmail = _authService.normalizeEmail(
        identity.sessionEmail ?? '',
      );
      final baseQuery = isEmailOtpAnonymousSession
          ? normalizedSessionEmail.isEmpty
                ? _firestore
                      .collection('bookings')
                      .where('receipt.customer.uid', isEqualTo: user.uid)
                : _firestore
                      .collection('bookings')
                      .where(
                        'receipt.customer.email',
                        isEqualTo: normalizedSessionEmail,
                      )
          : _firestore
                .collection('bookings')
                .where('receipt.customer.uid', isEqualTo: user.uid);

      return baseQuery.snapshots().asyncMap((snapshot) async {
        final firestoreItems = snapshot.docs
            .map((doc) => BookingHistoryItem.fromDoc(doc))
            .toList();

        final demoHistory = await _onlinePaymentService.getDemoPaymentHistory();
        final demoItems = demoHistory
            .map((item) => BookingHistoryItem.fromDemoHistory(item))
            .toList();

        final items = <BookingHistoryItem>[...firestoreItems, ...demoItems];

        items.sort((a, b) => b.bookingDate.compareTo(a.bookingDate));
        return items;
      });
    });
  }

  Future<void> cancelBooking({required String bookingId}) async {
    final user = await _resolveCurrentUser();
    if (user == null) {
      throw FirebaseAuthException(
        code: 'not-authenticated',
        message: 'User must be signed in before cancelling.',
      );
    }

    await _firestore.collection('bookings').doc(bookingId).update({
      'status': 'cancelled',
      'cancelledAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> submitReview({
    required String bookingId,
    required String salonId,
    required String salonName,
    required double rating,
    required String comment,
  }) async {
    final user = await _resolveCurrentUser();
    if (user == null) {
      throw FirebaseAuthException(
        code: 'not-authenticated',
        message: 'User must be signed in before submitting review.',
      );
    }

    final reviewDocRef = _firestore
        .collection('reviews')
        .doc(_reviewDocId(bookingId, user.uid));
    final existing = await reviewDocRef.get();
    if (existing.exists) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'already-reviewed',
        message: 'Review already submitted for this booking.',
      );
    }

    await reviewDocRef.set({
      'bookingId': bookingId,
      'salonId': salonId,
      'salonName': salonName,
      'userUid': user.uid,
      'rating': rating,
      'comment': comment.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<bool> hasSubmittedReviewForBooking(String bookingId) async {
    final user = await _resolveCurrentUser();
    if (user == null) {
      return false;
    }

    final snapshot = await _firestore
        .collection('reviews')
        .doc(_reviewDocId(bookingId, user.uid))
        .get();
    return snapshot.exists;
  }
}

class BookingHistoryItem {
  const BookingHistoryItem({
    required this.bookingId,
    required this.salonId,
    required this.salonName,
    required this.bookingDate,
    required this.bookingTime,
    required this.paymentMode,
    required this.customerName,
    required this.customerPhone,
    required this.stylistLabel,
    required this.services,
    required this.discountAmount,
    required this.totalAmount,
    required this.status,
    required this.qrPayloadJson,
    required this.canCancel,
    required this.canReview,
  });

  final String bookingId;
  final String salonId;
  final String salonName;
  final DateTime bookingDate;
  final String bookingTime;
  final String paymentMode;
  final String customerName;
  final String customerPhone;
  final String stylistLabel;
  final List<SalonSubServiceData> services;
  final double discountAmount;
  final double totalAmount;
  final String status;
  final String qrPayloadJson;
  final bool canCancel;
  final bool canReview;

  BookingHistoryTab get tab {
    if (status == 'cancelled') {
      return BookingHistoryTab.cancelled;
    }

    if (bookingDate.isBefore(DateTime.now())) {
      return BookingHistoryTab.completed;
    }

    return BookingHistoryTab.upcoming;
  }

  StoredReceiptData toReceiptData() {
    return StoredReceiptData(
      bookingId: bookingId,
      salonName: salonName,
      customerName: customerName,
      customerPhone: customerPhone,
      bookingDate: bookingDate,
      bookingTime: bookingTime,
      stylistLabel: stylistLabel,
      services: services,
      discountAmount: discountAmount,
      totalAmount: totalAmount,
      paymentModeLabel: _paymentModeLabel(paymentMode),
      qrPayloadJson: qrPayloadJson,
    );
  }

  static BookingHistoryItem fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final receipt =
        (data['receipt'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final salon =
        (receipt['salon'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final booking =
        (receipt['booking'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final customer =
        (receipt['customer'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final pricing =
        (receipt['pricing'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final servicesJson =
        (receipt['services'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .toList();

    final bookingId = (data['bookingId'] ?? doc.id).toString();
    final salonName = (salon['name'] ?? 'Salon').toString();
    final salonId = (data['salonId'] ?? salon['id'] ?? '').toString();
    final bookingDateIso = (booking['dateIso'] ?? '').toString();
    final bookingDate = DateTime.tryParse(bookingDateIso) ?? DateTime.now();
    final bookingTime = (booking['time'] ?? '-').toString();
    final paymentMode = (booking['paymentMode'] ?? data['paymentMode'] ?? '')
        .toString();
    final customerName = (customer['name'] ?? '-').toString();
    final customerPhone = (customer['phone'] ?? '-').toString();
    final stylistLabel = (booking['stylist'] ?? '-').toString();
    final discountAmount = _toDouble(pricing['discount']);
    final totalAmount = _toDouble(pricing['total']);
    final status = (data['status'] ?? '').toString().trim().toLowerCase();

    final qrMap = <String, dynamic>{
      'bookingId': bookingId,
      ...receipt,
      'createdAtEpoch': DateTime.now().millisecondsSinceEpoch,
    };

    return BookingHistoryItem(
      bookingId: bookingId,
      salonId: salonId,
      salonName: salonName,
      bookingDate: bookingDate,
      bookingTime: bookingTime,
      paymentMode: paymentMode,
      customerName: customerName,
      customerPhone: customerPhone,
      stylistLabel: stylistLabel,
      services: servicesJson
          .map(
            (item) => SalonSubServiceData(
              name: (item['name'] ?? '').toString(),
              charge: _toDouble(item['price']),
              duration: '-',
              category: '-',
            ),
          )
          .toList(),
      discountAmount: discountAmount,
      totalAmount: totalAmount,
      status: status,
      qrPayloadJson: jsonEncode(qrMap),
      canCancel: status != 'cancelled' && bookingDate.isAfter(DateTime.now()),
      canReview: status == 'cancelled' || bookingDate.isBefore(DateTime.now()),
    );
  }

  static BookingHistoryItem fromDemoHistory(DemoPaymentHistoryItem item) {
    final bookingDate =
        DateTime.tryParse(item.bookingDateIso) ?? DateTime.now();

    final qrMap = <String, Object?>{
      'bookingId': item.bookingId,
      'source': 'online_demo_local',
      'paymentMode': item.paymentModeLabel,
      'createdAtEpoch': DateTime.now().millisecondsSinceEpoch,
    };

    return BookingHistoryItem(
      bookingId: item.bookingId,
      salonId: '',
      salonName: item.salonName,
      bookingDate: bookingDate,
      bookingTime: item.bookingTime,
      paymentMode: item.paymentModeLabel,
      customerName: 'Guest User',
      customerPhone: '-',
      stylistLabel: '-',
      services: const <SalonSubServiceData>[],
      discountAmount: 0,
      totalAmount: item.totalAmount,
      status: '',
      qrPayloadJson: jsonEncode(qrMap),
      canCancel: false,
      canReview: false,
    );
  }

  static double _toDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse((value ?? '').toString()) ?? 0;
  }

  static String _paymentModeLabel(String mode) {
    switch (mode) {
      case 'pay_online_now':
        return 'Pay Online Now';
      case 'pay_at_salon':
        return 'Pay at Salon';
      default:
        return mode.isEmpty ? '-' : mode;
    }
  }
}
