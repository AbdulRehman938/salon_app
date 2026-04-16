import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../auth/data/services/auth_service.dart';
import '../../presentation/models/salon_detail_data.dart';
import '../../presentation/models/salon_sub_service_data.dart';
import 'booking_selection_service.dart';

class BookingCheckoutService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();

  Future<User> _requireAuthenticatedUser() async {
    var user = _auth.currentUser;
    if (user != null) {
      return user;
    }

    final sessionEmail = await _authService.getSessionVerifiedEmail();
    if (sessionEmail != null && sessionEmail.isNotEmpty) {
      try {
        user = await _authService.ensureAuthenticatedSessionForVerifiedEmail(
          sessionEmail,
        );
      } on FirebaseAuthException {
        rethrow;
      }
    }

    user ??= await _authService.refreshCurrentUser();
    if (user == null) {
      throw FirebaseAuthException(
        code: 'login-required',
        message: 'Please sign in again before checkout.',
      );
    }

    return user;
  }

  Future<StoredReceiptData> createPayAtSalonBooking({
    required SalonDetailData salon,
    required StoredDateTimeSelection dateTime,
    required StoredStylistSelection? stylist,
    required List<SalonSubServiceData> services,
    required double discountAmount,
    required double total,
  }) async {
    final user = await _requireAuthenticatedUser();

    final userDocData = await _loadUserDoc(user.uid);

    final sessionEmail = await _authService.getSessionVerifiedEmail();
    final email = (user.email ?? sessionEmail ?? '').trim();
    final customerName = _resolveCustomerName(user, userDocData, email);
    final phone = _resolvePhone(user, userDocData);

    final stylistLabel = _resolveStylistLabel(stylist);

    final receiptPayload = <String, Object?>{
      'salon': <String, Object?>{
        'id': salon.salonId,
        'name': salon.name,
        'distanceKm': salon.distanceKm,
        'address': salon.fullAddress,
        'imageAsset': salon.imageAsset,
      },
      'booking': <String, Object?>{
        'dateIso': dateTime.date.toIso8601String(),
        'time': dateTime.timeLabel,
        'stylist': stylistLabel,
        'paymentMode': 'pay_at_salon',
      },
      'services': services
          .map(
            (service) => <String, Object?>{
              'name': service.name,
              'price': service.charge,
            },
          )
          .toList(),
      'pricing': <String, Object?>{'discount': discountAmount, 'total': total},
      'customer': <String, Object?>{
        'uid': user.uid,
        'name': customerName,
        'phone': phone,
        'email': email,
      },
    };

    final bookingDoc = _firestore.collection('bookings').doc();
    await bookingDoc.set({
      'bookingId': bookingDoc.id,
      'salonId': salon.salonId,
      'paymentMode': 'pay_at_salon',
      'createdAt': FieldValue.serverTimestamp(),
      'receipt': receiptPayload,
    });

    final qrPayload = <String, Object?>{
      'bookingId': bookingDoc.id,
      ...receiptPayload,
      'createdAtEpoch': DateTime.now().millisecondsSinceEpoch,
    };

    return StoredReceiptData(
      bookingId: bookingDoc.id,
      salonName: salon.name,
      customerName: customerName,
      customerPhone: phone,
      bookingDate: dateTime.date,
      bookingTime: dateTime.timeLabel,
      stylistLabel: stylistLabel,
      services: services,
      discountAmount: discountAmount,
      totalAmount: total,
      paymentModeLabel: 'Pay at Salon',
      qrPayloadJson: jsonEncode(qrPayload),
    );
  }

  Future<Map<String, dynamic>?> _loadUserDoc(String? uid) async {
    if (uid == null || uid.isEmpty) {
      return null;
    }

    final snapshot = await _firestore.collection('users').doc(uid).get();
    final data = snapshot.data();
    if (data == null) {
      return null;
    }

    return data;
  }

  String _resolveCustomerName(
    User? user,
    Map<String, dynamic>? userDoc,
    String email,
  ) {
    final docNameCandidates = <String?>[
      userDoc?['displayName']?.toString(),
      userDoc?['name']?.toString(),
      userDoc?['fullName']?.toString(),
    ];

    for (final candidate in docNameCandidates) {
      final value = (candidate ?? '').trim();
      if (value.isNotEmpty) {
        return value;
      }
    }

    final authName = (user?.displayName ?? '').trim();
    if (authName.isNotEmpty) {
      return authName;
    }

    if (email.isNotEmpty && email.contains('@')) {
      return email.split('@').first;
    }

    return 'Guest User';
  }

  String _resolvePhone(User? user, Map<String, dynamic>? userDoc) {
    final docPhoneCandidates = <String?>[
      userDoc?['phone']?.toString(),
      userDoc?['phoneNumber']?.toString(),
      userDoc?['mobile']?.toString(),
    ];

    for (final candidate in docPhoneCandidates) {
      final value = (candidate ?? '').trim();
      if (value.isNotEmpty) {
        return value;
      }
    }

    final authPhone = (user?.phoneNumber ?? '').trim();
    if (authPhone.isNotEmpty) {
      return authPhone;
    }

    return '-';
  }

  String _resolveStylistLabel(StoredStylistSelection? stylist) {
    if (stylist == null) {
      return '-';
    }

    if (stylist.selectionType == 'any') {
      return 'Any';
    }

    if (stylist.selectionType == 'multiple') {
      return 'Multiple';
    }

    final name = (stylist.stylistName ?? '').trim();
    if (name.isEmpty) {
      return 'Selected';
    }

    return name;
  }
}

class StoredReceiptData {
  const StoredReceiptData({
    required this.bookingId,
    required this.salonName,
    required this.customerName,
    required this.customerPhone,
    required this.bookingDate,
    required this.bookingTime,
    required this.stylistLabel,
    required this.services,
    required this.discountAmount,
    required this.totalAmount,
    required this.paymentModeLabel,
    required this.qrPayloadJson,
  });

  final String bookingId;
  final String salonName;
  final String customerName;
  final String customerPhone;
  final DateTime bookingDate;
  final String bookingTime;
  final String stylistLabel;
  final List<SalonSubServiceData> services;
  final double discountAmount;
  final double totalAmount;
  final String paymentModeLabel;
  final String qrPayloadJson;
}
