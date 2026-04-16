import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../auth/data/services/auth_service.dart';
import '../../presentation/models/salon_sub_service_data.dart';
import 'booking_checkout_service.dart';

class OnlinePaymentService {
  static const String _draftStorageKey = 'online_checkout_draft';
  static const String _demoPaymentsStorageKey = 'demo_online_payments';
  static const String _usersCollection = 'users';

  final SharedPreferencesAsyncLoader _prefsLoader;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final AuthService _authService = AuthService();

  OnlinePaymentService({
    SharedPreferencesAsyncLoader? prefsLoader,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _prefsLoader = prefsLoader ?? SharedPreferencesAsyncLoader(),
       _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

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

  Future<void> saveCheckoutDraft(OnlineCheckoutDraft draft) async {
    final prefs = await _prefsLoader.instance();
    await prefs.setString(_draftStorageKey, jsonEncode(draft.toJson()));
  }

  Future<OnlineCheckoutDraft?> getCheckoutDraft() async {
    final prefs = await _prefsLoader.instance();
    final raw = prefs.getString(_draftStorageKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    return OnlineCheckoutDraft.fromJson(decoded);
  }

  Future<List<StoredPaymentCard>> getSavedCardsForCurrentUser() async {
    final user = await _resolveCurrentUser();
    if (user == null) {
      return const [];
    }

    final snapshot = await _firestore
        .collection(_usersCollection)
        .doc(user.uid)
        .get();
    final data = snapshot.data();
    if (data == null) {
      return const [];
    }

    final paymentMethods = data['paymentMethods'];
    if (paymentMethods is! Map) {
      return const [];
    }

    final cardsRaw = paymentMethods['cards'];
    if (cardsRaw is! List) {
      return const [];
    }

    final cards = <StoredPaymentCard>[];
    for (final entry in cardsRaw) {
      if (entry is! Map) {
        continue;
      }

      final id = (entry['id'] ?? '').toString().trim();
      final last4 = (entry['last4'] ?? '').toString().trim();
      if (id.isEmpty || last4.isEmpty) {
        continue;
      }

      cards.add(
        StoredPaymentCard(
          id: id,
          brand: (entry['brand'] ?? 'Card').toString(),
          last4: last4,
          cardHolderName: (entry['cardHolderName'] ?? '').toString(),
          expiryLabel: (entry['expiryLabel'] ?? '').toString(),
        ),
      );
    }

    return cards;
  }

  Future<StoredPaymentCard> addCardForCurrentUser({
    required String cardNumber,
    required String expiryLabel,
    required String cvc,
    required String cardHolderName,
  }) async {
    final user = await _resolveCurrentUser();
    if (user == null) {
      throw FirebaseAuthException(
        code: 'not-authenticated',
        message: 'User must be signed in to save payment cards.',
      );
    }

    final existingCards = await getSavedCardsForCurrentUser();
    final digits = cardNumber.replaceAll(RegExp(r'\D'), '');
    final last4 = digits.length >= 4
        ? digits.substring(digits.length - 4)
        : digits;
    final cardId = 'card_${DateTime.now().microsecondsSinceEpoch}';
    final brand = _detectCardBrand(digits);

    final newCard = StoredPaymentCard(
      id: cardId,
      brand: brand,
      last4: last4,
      cardHolderName: cardHolderName.trim(),
      expiryLabel: expiryLabel.trim(),
    );

    final updated = <Map<String, Object?>>[
      newCard.toJsonForStorage(maskedCvc: cvc),
      ...existingCards.map((card) => card.toJsonForStorage()),
    ];

    await _firestore.collection(_usersCollection).doc(user.uid).set({
      'paymentMethods': {
        'cards': updated,
        'defaultCardId': cardId,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    }, SetOptions(merge: true));

    return newCard;
  }

  Future<StoredReceiptData> processDemoStripePayment({
    required OnlineCheckoutDraft draft,
    required OnlinePaymentMethodType paymentMethodType,
    StoredPaymentCard? selectedCard,
  }) async {
    final user = await _resolveCurrentUser();
    Map<String, dynamic>? userData;
    if (user != null) {
      final snapshot = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .get();
      userData = snapshot.data();
    }

    final bookingId = 'demo_${DateTime.now().millisecondsSinceEpoch}';
    final bookingDate =
        DateTime.tryParse(draft.bookingDateIso) ?? DateTime.now();
    final customerName =
        (userData?['displayName'] ?? userData?['name'] ?? user?.displayName)
            ?.toString()
            .trim();
    final customerPhone =
        (userData?['phone'] ?? userData?['phoneNumber'] ?? user?.phoneNumber)
            ?.toString()
            .trim();

    final qrPayload = jsonEncode({
      'bookingId': bookingId,
      'paymentStatus': 'paid_demo_local',
      'paymentMethod': paymentMethodType.name,
      'createdAtEpoch': DateTime.now().millisecondsSinceEpoch,
    });

    final receipt = StoredReceiptData(
      bookingId: bookingId,
      salonName: draft.salonName,
      customerName: customerName == null || customerName.isEmpty
          ? 'Guest User'
          : customerName,
      customerPhone: customerPhone == null || customerPhone.isEmpty
          ? '-'
          : customerPhone,
      bookingDate: bookingDate,
      bookingTime: draft.bookingTime,
      stylistLabel: draft.stylistLabel,
      services: draft.services
          .map(
            (service) => SalonSubServiceData(
              name: service.name,
              charge: service.price,
              duration: 'N/A',
              category: 'Online',
            ),
          )
          .toList(),
      discountAmount: draft.discountAmount,
      totalAmount: draft.totalAmount,
      paymentModeLabel: _fallbackPaymentLabel(paymentMethodType),
      qrPayloadJson: qrPayload,
    );

    final prefs = await _prefsLoader.instance();
    final existingRaw = prefs.getString(_demoPaymentsStorageKey);
    final existingList = _decodeList(existingRaw);
    existingList.insert(0, {
      'bookingId': receipt.bookingId,
      'salonName': receipt.salonName,
      'bookingDateIso': receipt.bookingDate.toIso8601String(),
      'bookingTime': receipt.bookingTime,
      'paymentModeLabel': receipt.paymentModeLabel,
      'totalAmount': receipt.totalAmount,
      'createdAtIso': DateTime.now().toIso8601String(),
    });
    await prefs.setString(_demoPaymentsStorageKey, jsonEncode(existingList));

    return receipt;
  }

  Future<List<DemoPaymentHistoryItem>> getDemoPaymentHistory() async {
    final prefs = await _prefsLoader.instance();
    final raw = prefs.getString(_demoPaymentsStorageKey);
    final decoded = _decodeList(raw);

    final items = <DemoPaymentHistoryItem>[];
    for (final map in decoded) {
      final bookingId = (map['bookingId'] ?? '').toString().trim();
      final salonName = (map['salonName'] ?? 'Salon').toString().trim();
      final bookingDateIso = (map['bookingDateIso'] ?? '').toString();
      final bookingTime = (map['bookingTime'] ?? '-').toString();
      final paymentModeLabel = (map['paymentModeLabel'] ?? 'Online (Demo)')
          .toString();
      final totalAmount = map['totalAmount'] is num
          ? (map['totalAmount'] as num).toDouble()
          : double.tryParse((map['totalAmount'] ?? '').toString()) ?? 0;
      final createdAtIso = (map['createdAtIso'] ?? '').toString();

      if (bookingId.isEmpty) {
        continue;
      }

      items.add(
        DemoPaymentHistoryItem(
          bookingId: bookingId,
          salonName: salonName.isEmpty ? 'Salon' : salonName,
          bookingDateIso: bookingDateIso,
          bookingTime: bookingTime,
          paymentModeLabel: paymentModeLabel,
          totalAmount: totalAmount,
          createdAtIso: createdAtIso,
        ),
      );
    }

    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  List<Map<String, Object?>> _decodeList(String? raw) {
    if (raw == null || raw.isEmpty) {
      return <Map<String, Object?>>[];
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return <Map<String, Object?>>[];
    }

    final result = <Map<String, Object?>>[];
    for (final item in decoded) {
      if (item is Map) {
        result.add(item.map((key, value) => MapEntry(key.toString(), value)));
      }
    }
    return result;
  }

  String _fallbackPaymentLabel(OnlinePaymentMethodType paymentMethodType) {
    switch (paymentMethodType) {
      case OnlinePaymentMethodType.card:
        return 'Card (Demo)';
      case OnlinePaymentMethodType.applePay:
        return 'Apple Pay (Demo)';
      case OnlinePaymentMethodType.googlePay:
        return 'Google Pay (Demo)';
    }
  }

  String _detectCardBrand(String digits) {
    if (digits.startsWith('4')) {
      return 'VISA';
    }
    if (RegExp(r'^(5[1-5]|2[2-7])').hasMatch(digits)) {
      return 'Mastercard';
    }
    if (digits.startsWith('34') || digits.startsWith('37')) {
      return 'Amex';
    }
    return 'Card';
  }
}

class OnlineCheckoutDraft {
  const OnlineCheckoutDraft({
    required this.salonId,
    required this.salonName,
    required this.bookingDateIso,
    required this.bookingTime,
    required this.stylistLabel,
    required this.services,
    required this.discountAmount,
    required this.totalAmount,
    required this.createdAtIso,
  });

  final String salonId;
  final String salonName;
  final String bookingDateIso;
  final String bookingTime;
  final String stylistLabel;
  final List<OnlineCheckoutServiceItem> services;
  final double discountAmount;
  final double totalAmount;
  final String createdAtIso;

  Map<String, Object?> toJson() {
    return {
      'salonId': salonId,
      'salonName': salonName,
      'bookingDateIso': bookingDateIso,
      'bookingTime': bookingTime,
      'stylistLabel': stylistLabel,
      'services': services.map((item) => item.toJson()).toList(),
      'discountAmount': discountAmount,
      'totalAmount': totalAmount,
      'createdAtIso': createdAtIso,
    };
  }

  factory OnlineCheckoutDraft.fromJson(Map<String, dynamic> json) {
    final rawServices = json['services'];
    final services = <OnlineCheckoutServiceItem>[];
    if (rawServices is List) {
      for (final item in rawServices) {
        if (item is Map) {
          services.add(
            OnlineCheckoutServiceItem(
              name: (item['name'] ?? '').toString(),
              price: item['price'] is num
                  ? (item['price'] as num).toDouble()
                  : double.tryParse(item['price']?.toString() ?? '') ?? 0,
            ),
          );
        }
      }
    }

    return OnlineCheckoutDraft(
      salonId: (json['salonId'] ?? '').toString(),
      salonName: (json['salonName'] ?? '').toString(),
      bookingDateIso: (json['bookingDateIso'] ?? '').toString(),
      bookingTime: (json['bookingTime'] ?? '').toString(),
      stylistLabel: (json['stylistLabel'] ?? '').toString(),
      services: services,
      discountAmount: json['discountAmount'] is num
          ? (json['discountAmount'] as num).toDouble()
          : double.tryParse(json['discountAmount']?.toString() ?? '') ?? 0,
      totalAmount: json['totalAmount'] is num
          ? (json['totalAmount'] as num).toDouble()
          : double.tryParse(json['totalAmount']?.toString() ?? '') ?? 0,
      createdAtIso: (json['createdAtIso'] ?? '').toString(),
    );
  }
}

class OnlineCheckoutServiceItem {
  const OnlineCheckoutServiceItem({required this.name, required this.price});

  final String name;
  final double price;

  Map<String, Object?> toJson() {
    return {'name': name, 'price': price};
  }
}

class StoredPaymentCard {
  const StoredPaymentCard({
    required this.id,
    required this.brand,
    required this.last4,
    required this.cardHolderName,
    required this.expiryLabel,
  });

  final String id;
  final String brand;
  final String last4;
  final String cardHolderName;
  final String expiryLabel;

  Map<String, Object?> toJsonForStorage({String? maskedCvc}) {
    return {
      'id': id,
      'brand': brand,
      'last4': last4,
      'cardHolderName': cardHolderName,
      'expiryLabel': expiryLabel,
      if (maskedCvc != null && maskedCvc.isNotEmpty)
        'cvcMask': '*' * maskedCvc.length,
    };
  }

  Map<String, Object?> toSafeJson() {
    return {'id': id, 'brand': brand, 'last4': last4};
  }
}

enum OnlinePaymentMethodType { card, applePay, googlePay }

class SharedPreferencesAsyncLoader {
  Future<SharedPreferences> instance() {
    return SharedPreferences.getInstance();
  }
}

class DemoPaymentHistoryItem {
  const DemoPaymentHistoryItem({
    required this.bookingId,
    required this.salonName,
    required this.bookingDateIso,
    required this.bookingTime,
    required this.paymentModeLabel,
    required this.totalAmount,
    required this.createdAtIso,
  });

  final String bookingId;
  final String salonName;
  final String bookingDateIso;
  final String bookingTime;
  final String paymentModeLabel;
  final double totalAmount;
  final String createdAtIso;

  DateTime get createdAt =>
      DateTime.tryParse(createdAtIso) ?? DateTime.fromMillisecondsSinceEpoch(0);
}
