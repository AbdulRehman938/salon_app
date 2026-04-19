import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import '../../../auth/data/services/auth_service.dart';
import '../../presentation/models/salon_detail_data.dart';
import '../../presentation/models/salon_card_data.dart';
import '../../presentation/models/salon_sub_service_data.dart';
import '../../presentation/models/stylist_data.dart';

class SalonDataService {
  static const String _collection = 'salons';
  static const String _usersCollection = 'users';
  static const String _emailOtpCollection = 'emailOtpVerifications';

  bool _isPermissionDeniedError(Object error) {
    if (error is FirebaseException) {
      return error.code == 'permission-denied';
    }

    return error.toString().toLowerCase().contains('permission-denied');
  }

  static const List<String> _salonImageAssets = <String>[
    'assets/salonImg1.png',
    'assets/salonImg2.png',
    'assets/salonImg3.png',
  ];

  static const Map<String, List<String>> _serviceNamesBySalonId =
      <String, List<String>>{
        'PK-PJ-001': <String>['Haircut', 'Balayage'],
        'PK-PJ-002': <String>['Hydra Facial', 'Blow Dry'],
        'PK-PJ-003': <String>['Party Makeup', 'Keratin Treatment'],
        'PK-PJ-004': <String>['Manicure', 'Facial'],
        'PK-PJ-005': <String>['Haircut', 'Hair Dye'],
        'PK-PJ-006': <String>['Massage', 'Hair Botox'],
        'PK-PJ-007': <String>['Haircut', 'Waxing'],
        'PK-PJ-008': <String>['Facial', 'Hair Styling'],
        'PK-PJ-009': <String>['Blow Dry', 'Styling'],
        'PK-PJ-010': <String>['Hair Color', 'Hair Spa'],
        'PK-PJ-011': <String>['Haircut', 'Beard Styling'],
        'PK-PJ-012': <String>['Gold Facial', 'Hair Straightening'],
        'PK-PJ-013': <String>['Makeup', 'Hair Styling'],
        'PK-PJ-014': <String>['Layer Cut', 'Protein Treatment'],
        'PK-PJ-015': <String>['Cleanup', 'Waxing'],
        'PK-PJ-016': <String>['Styling', 'Hair Botox'],
        'PK-PJ-017': <String>['Haircut', 'Shave'],
        'PK-PJ-018': <String>['Makeup', 'Facial'],
        'PK-PJ-019': <String>['Smoothening', 'Hair Spa'],
        'PK-PJ-020': <String>['Haircut', 'Facial'],
        'PK-PJ-021': <String>['Bridal Makeup', 'Hair Styling'],
        'PK-PJ-022': <String>['Haircut', 'Facial'],
        'PK-PJ-023': <String>['Makeup', 'Waxing'],
        'PK-PJ-024': <String>['Whitening Facial', 'Hair Color'],
        'PK-PJ-025': <String>['Haircut', 'Cleanup'],
        'PK-PJ-026': <String>['Facial', 'Hair Spa'],
        'PK-PJ-027': <String>['Haircut', 'Beard Trim'],
        'PK-PJ-028': <String>['Party Makeup', 'Hair Styling'],
        'PK-PJ-029': <String>['Facial', 'Haircut'],
        'PK-PJ-030': <String>['Haircut', 'Makeup'],
        'PK-PJ-031': <String>['Hair Color', 'Facial'],
        'PK-PJ-032': <String>['Cleanup', 'Haircut'],
        'PK-PJ-033': <String>['Facial', 'Hair Styling'],
        'PK-PJ-034': <String>['Haircut', 'Hair Spa'],
        'PK-PJ-035': <String>['Bridal Makeup', 'Hair Color'],
        'PK-PJ-036': <String>['Facial', 'Haircut'],
        'PK-PJ-037': <String>['Haircut', 'Hair Color'],
        'PK-PJ-038': <String>['Cleanup', 'Makeup'],
        'PK-PJ-039': <String>['Hair Styling', 'Facial'],
        'PK-PJ-040': <String>['Hair Spa', 'Haircut'],
      };

  static const List<Map<String, Object>> _seedSalons = <Map<String, Object>>[
    {
      'id': 'PK-PJ-001',
      'name': 'Shafaq n Kami Salon',
      'state': 'Punjab',
      'city': 'Lahore',
      'rating': 4.7,
      'reviews_count': 6361,
      'distance_km': 1.5,
    },
    {
      'id': 'PK-PJ-002',
      'name': 'COSMO Salon',
      'state': 'Punjab',
      'city': 'Lahore',
      'rating': 4.5,
      'reviews_count': 2126,
      'distance_km': 3.2,
    },
    {
      'id': 'PK-PJ-003',
      'name': 'Newlook Salon',
      'state': 'Punjab',
      'city': 'Faisalabad',
      'rating': 4.6,
      'reviews_count': 1070,
      'distance_km': 0.8,
    },
    {
      'id': 'PK-PJ-004',
      'name': 'Depilex Beauty Clinic',
      'state': 'Punjab',
      'city': 'Multan',
      'rating': 4.9,
      'reviews_count': 354,
      'distance_km': 4.5,
    },
    {
      'id': 'PK-PJ-005',
      'name': 'Toni & Guy',
      'state': 'Punjab',
      'city': 'Rawalpindi',
      'rating': 4.7,
      'reviews_count': 920,
      'distance_km': 2.1,
    },
    {
      'id': 'PK-PJ-006',
      'name': 'Sunuba Salon',
      'state': 'Punjab',
      'city': 'Gujranwala',
      'rating': 4.7,
      'reviews_count': 740,
      'distance_km': 1.1,
    },
    {
      'id': 'PK-PJ-007',
      'name': 'Seeme Beauty Salon',
      'state': 'Punjab',
      'city': 'Lahore',
      'rating': 4.7,
      'reviews_count': 2360,
      'distance_km': 2.8,
    },
    {
      'id': 'PK-PJ-008',
      'name': 'Moshaz Salon',
      'state': 'Punjab',
      'city': 'Bahawalpur',
      'rating': 4.5,
      'reviews_count': 410,
      'distance_km': 3.9,
    },
    {
      'id': 'PK-PJ-009',
      'name': 'Nabila Signature',
      'state': 'Punjab',
      'city': 'Lahore',
      'rating': 4.5,
      'reviews_count': 1473,
      'distance_km': 1.9,
    },
    {
      'id': 'PK-PJ-010',
      'name': 'Glam Studio',
      'state': 'Punjab',
      'city': 'Lahore',
      'rating': 4.6,
      'reviews_count': 1320,
      'distance_km': 2.4,
    },
    {
      'id': 'PK-PJ-011',
      'name': 'Royal Cuts',
      'state': 'Punjab',
      'city': 'Rawalpindi',
      'rating': 4.3,
      'reviews_count': 890,
      'distance_km': 3.7,
    },
    {
      'id': 'PK-PJ-012',
      'name': 'Beauty Lounge',
      'state': 'Punjab',
      'city': 'Multan',
      'rating': 4.7,
      'reviews_count': 620,
      'distance_km': 2.9,
    },
    {
      'id': 'PK-PJ-013',
      'name': 'Elegance Salon',
      'state': 'Punjab',
      'city': 'Faisalabad',
      'rating': 4.4,
      'reviews_count': 540,
      'distance_km': 1.3,
    },
    {
      'id': 'PK-PJ-014',
      'name': 'Style Hub',
      'state': 'Punjab',
      'city': 'Bahawalpur',
      'rating': 4.5,
      'reviews_count': 310,
      'distance_km': 2.6,
    },
    {
      'id': 'PK-PJ-015',
      'name': 'Glow Beauty Bar',
      'state': 'Punjab',
      'city': 'Sargodha',
      'rating': 4.2,
      'reviews_count': 260,
      'distance_km': 4.0,
    },
    {
      'id': 'PK-PJ-016',
      'name': 'Urban Chic',
      'state': 'Punjab',
      'city': 'Gujrat',
      'rating': 4.6,
      'reviews_count': 410,
      'distance_km': 2.2,
    },
    {
      'id': 'PK-PJ-017',
      'name': 'Classic Look',
      'state': 'Punjab',
      'city': 'Okara',
      'rating': 4.3,
      'reviews_count': 180,
      'distance_km': 3.5,
    },
    {
      'id': 'PK-PJ-018',
      'name': 'Blush Lounge',
      'state': 'Punjab',
      'city': 'Sheikhupura',
      'rating': 4.5,
      'reviews_count': 230,
      'distance_km': 1.8,
    },
    {
      'id': 'PK-PJ-019',
      'name': 'Hair Studio',
      'state': 'Punjab',
      'city': 'Jhelum',
      'rating': 4.4,
      'reviews_count': 150,
      'distance_km': 2.9,
    },
    {
      'id': 'PK-PJ-020',
      'name': 'Charm Salon',
      'state': 'Punjab',
      'city': 'Kasur',
      'rating': 4.3,
      'reviews_count': 210,
      'distance_km': 2.1,
    },
    {
      'id': 'PK-PJ-021',
      'name': 'Elite Makeover Studio',
      'state': 'Punjab',
      'city': 'Rahim Yar Khan',
      'rating': 4.6,
      'reviews_count': 380,
      'distance_km': 2.7,
    },
    {
      'id': 'PK-PJ-022',
      'name': 'The Glam Bar',
      'state': 'Punjab',
      'city': 'Khanewal',
      'rating': 4.3,
      'reviews_count': 210,
      'distance_km': 3.1,
    },
    {
      'id': 'PK-PJ-023',
      'name': 'Royal Beauty Hub',
      'state': 'Punjab',
      'city': 'Vehari',
      'rating': 4.4,
      'reviews_count': 260,
      'distance_km': 2.4,
    },
    {
      'id': 'PK-PJ-024',
      'name': 'Glow Up Salon',
      'state': 'Punjab',
      'city': 'Sahiwal',
      'rating': 4.5,
      'reviews_count': 310,
      'distance_km': 1.6,
    },
    {
      'id': 'PK-PJ-025',
      'name': 'Signature Salon',
      'state': 'Punjab',
      'city': 'Pakpattan',
      'rating': 4.2,
      'reviews_count': 180,
      'distance_km': 2.9,
    },
    {
      'id': 'PK-PJ-026',
      'name': 'Bliss Beauty Lounge',
      'state': 'Punjab',
      'city': 'Mandi Bahauddin',
      'rating': 4.4,
      'reviews_count': 220,
      'distance_km': 3.3,
    },
    {
      'id': 'PK-PJ-027',
      'name': 'Trendy Cuts',
      'state': 'Punjab',
      'city': 'Chiniot',
      'rating': 4.3,
      'reviews_count': 150,
      'distance_km': 2.0,
    },
    {
      'id': 'PK-PJ-028',
      'name': 'Beauty World',
      'state': 'Punjab',
      'city': 'Jhang',
      'rating': 4.5,
      'reviews_count': 270,
      'distance_km': 2.5,
    },
    {
      'id': 'PK-PJ-029',
      'name': 'Urban Glow',
      'state': 'Punjab',
      'city': 'Attock',
      'rating': 4.2,
      'reviews_count': 140,
      'distance_km': 3.8,
    },
    {
      'id': 'PK-PJ-030',
      'name': 'The Beauty Spot',
      'state': 'Punjab',
      'city': 'Chakwal',
      'rating': 4.4,
      'reviews_count': 190,
      'distance_km': 2.3,
    },
    {
      'id': 'PK-PJ-031',
      'name': 'Gloss & Glow',
      'state': 'Punjab',
      'city': 'Sialkot',
      'rating': 4.6,
      'reviews_count': 520,
      'distance_km': 1.9,
    },
    {
      'id': 'PK-PJ-032',
      'name': 'Polish Beauty Lounge',
      'state': 'Punjab',
      'city': 'Narowal',
      'rating': 4.3,
      'reviews_count': 160,
      'distance_km': 2.6,
    },
    {
      'id': 'PK-PJ-033',
      'name': 'Heaven Salon',
      'state': 'Punjab',
      'city': 'Hafizabad',
      'rating': 4.4,
      'reviews_count': 170,
      'distance_km': 2.1,
    },
    {
      'id': 'PK-PJ-034',
      'name': 'Style Station',
      'state': 'Punjab',
      'city': 'Gujranwala',
      'rating': 4.5,
      'reviews_count': 480,
      'distance_km': 2.7,
    },
    {
      'id': 'PK-PJ-035',
      'name': 'The Makeover Studio',
      'state': 'Punjab',
      'city': 'Lahore',
      'rating': 4.8,
      'reviews_count': 2100,
      'distance_km': 1.7,
    },
    {
      'id': 'PK-PJ-036',
      'name': 'Charm Beauty Lounge',
      'state': 'Punjab',
      'city': 'Multan',
      'rating': 4.6,
      'reviews_count': 390,
      'distance_km': 2.8,
    },
    {
      'id': 'PK-PJ-037',
      'name': 'Prime Salon',
      'state': 'Punjab',
      'city': 'Faisalabad',
      'rating': 4.5,
      'reviews_count': 670,
      'distance_km': 1.9,
    },
    {
      'id': 'PK-PJ-038',
      'name': 'Aura Beauty Salon',
      'state': 'Punjab',
      'city': 'Bahawalpur',
      'rating': 4.4,
      'reviews_count': 280,
      'distance_km': 2.5,
    },
    {
      'id': 'PK-PJ-039',
      'name': 'Trends Salon',
      'state': 'Punjab',
      'city': 'Sargodha',
      'rating': 4.3,
      'reviews_count': 300,
      'distance_km': 3.0,
    },
    {
      'id': 'PK-PJ-040',
      'name': 'Luxe Beauty Bar',
      'state': 'Punjab',
      'city': 'Gujrat',
      'rating': 4.6,
      'reviews_count': 350,
      'distance_km': 2.2,
    },
  ];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();

  String _emailDocId(String email) {
    return base64Url.encode(utf8.encode(_authService.normalizeEmail(email)));
  }

  Future<User?> _resolveCurrentUser() async {
    final current = _auth.currentUser;
    if (current != null) {
      return current;
    }

    try {
      return await _auth
          .authStateChanges()
          .where((user) => user != null)
          .map((user) => user!)
          .first
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      return _auth.currentUser;
    }
  }

  Future<bool> isSalonFavoriteForCurrentUser(String salonId) async {
    final user = await _resolveCurrentUser();
    if (user != null) {
      final snapshot = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .get();

      final data = snapshot.data();
      if (data == null) {
        return false;
      }

      final rawFavorites = data['favoriteSalonIds'];
      if (rawFavorites is! List) {
        return false;
      }

      final favorites = rawFavorites
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toSet();
      return favorites.contains(salonId);
    }

    final email = await _authService.getSessionVerifiedEmail();
    if (email == null || email.isEmpty) {
      return false;
    }

    final snapshot = await _firestore
        .collection(_emailOtpCollection)
        .doc(_emailDocId(email))
        .get();

    final data = snapshot.data();
    if (data == null) {
      return false;
    }

    final rawFavorites = data['favoriteSalonIds'];
    if (rawFavorites is! List) {
      return false;
    }

    final favorites = rawFavorites
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toSet();
    return favorites.contains(salonId);
  }

  Future<void> setSalonFavoriteForCurrentUser({
    required String salonId,
    required bool isFavorite,
  }) async {
    final user = await _resolveCurrentUser();
    if (user != null) {
      final userDoc = _firestore.collection(_usersCollection).doc(user.uid);
      await userDoc.set({
        'favoriteSalonIds': isFavorite
            ? FieldValue.arrayUnion(<String>[salonId])
            : FieldValue.arrayRemove(<String>[salonId]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }

    final email = await _authService.getSessionVerifiedEmail();
    if (email == null || email.isEmpty) {
      throw FirebaseAuthException(
        code: 'not-signed-in',
        message: 'Sign in to save favorites.',
      );
    }

    final emailDoc = _firestore
        .collection(_emailOtpCollection)
        .doc(_emailDocId(email));

    await emailDoc.set({
      'email': _authService.normalizeEmail(email),
      'favoriteSalonIds': isFavorite
          ? FieldValue.arrayUnion(<String>[salonId])
          : FieldValue.arrayRemove(<String>[salonId]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<List<String>> fetchFavoriteSalonIdsForCurrentUser() async {
    final user = await _resolveCurrentUser();
    if (user != null) {
      final snapshot = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .get();

      final data = snapshot.data();
      if (data == null) {
        return const <String>[];
      }

      final rawFavorites = data['favoriteSalonIds'];
      if (rawFavorites is! List) {
        return const <String>[];
      }

      return rawFavorites
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    final email = await _authService.getSessionVerifiedEmail();
    if (email == null || email.isEmpty) {
      return const <String>[];
    }

    final snapshot = await _firestore
        .collection(_emailOtpCollection)
        .doc(_emailDocId(email))
        .get();

    final data = snapshot.data();
    if (data == null) {
      return const <String>[];
    }

    final rawFavorites = data['favoriteSalonIds'];
    if (rawFavorites is! List) {
      return const <String>[];
    }

    return rawFavorites
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  Future<List<SalonCardData>> fetchFavoriteSalonsForCurrentUser() async {
    final favoriteIds = await fetchFavoriteSalonIdsForCurrentUser();
    if (favoriteIds.isEmpty) {
      return const <SalonCardData>[];
    }

    final uniqueIds = favoriteIds.toSet();
    final snapshot = await _firestore.collection(_collection).get();

    final cardsById = <String, SalonCardData>{};
    for (final doc in snapshot.docs) {
      if (!uniqueIds.contains(doc.id)) {
        continue;
      }

      final data = doc.data();
      final rating = (data['rating'] as num?)?.toDouble() ?? 0;
      final reviews = (data['reviews_count'] as num?)?.toInt() ?? 0;
      final distance = (data['distance_km'] as num?)?.toDouble() ?? 0;
      final cityValue = (data['city'] ?? '').toString();
      final stateValue = (data['state'] ?? '').toString();

      cardsById[doc.id] = SalonCardData(
        salonId: doc.id,
        name: (data['name'] ?? 'Unknown Salon').toString(),
        distance: _formatDistance(distance),
        location: '$cityValue, $stateValue',
        rating: rating.toStringAsFixed(1),
        reviews: reviews.toString(),
        imageAsset: _salonImageAssets[_imageIndexForSalonId(doc.id)],
      );
    }

    final ordered = <SalonCardData>[];
    for (final id in favoriteIds) {
      final card = cardsById[id];
      if (card != null) {
        ordered.add(card);
      }
    }
    return ordered;
  }

  Map<String, Object>? _seedSalonById(String salonId) {
    for (final salon in _seedSalons) {
      if ((salon['id'] ?? '').toString() == salonId) {
        return salon;
      }
    }
    return null;
  }

  int _imageIndexForSalonId(String salonId) {
    final seedIndex = _seedSalons.indexWhere(
      (salon) => (salon['id'] ?? '').toString() == salonId,
    );

    if (seedIndex >= 0) {
      return seedIndex % _salonImageAssets.length;
    }

    return salonId.hashCode.abs() % _salonImageAssets.length;
  }

  String _serviceCategoryForName(String name) {
    final key = name.toLowerCase();

    if (key.contains('cut') || key.contains('trim') || key.contains('shave')) {
      return 'Hair Cut';
    }
    if (key.contains('style') || key.contains('blow')) {
      return 'Hair Styling';
    }
    if (key.contains('color') ||
        key.contains('dye') ||
        key.contains('balayage') ||
        key.contains('keratin') ||
        key.contains('protein') ||
        key.contains('botox') ||
        key.contains('spa') ||
        key.contains('smooth') ||
        key.contains('straight')) {
      return 'Hair Treatments';
    }

    return 'Combo';
  }

  List<SalonSubServiceData> _buildSubServices(
    String salonId,
    Map<String, dynamic> data,
  ) {
    final subServices = <SalonSubServiceData>[];

    final rawServices = data['services'];
    if (rawServices is List) {
      for (final item in rawServices) {
        if (item is! Map) {
          continue;
        }

        final name = (item['service_name'] ?? '').toString().trim();
        if (name.isEmpty) {
          continue;
        }

        final rawPrice = item.containsKey('price')
            ? item['price']
            : item['charge'];
        final charge = rawPrice is num
            ? rawPrice.toDouble()
            : double.tryParse(rawPrice?.toString() ?? '') ?? 0;

        final duration = (item['duration_time'] ?? 'N/A').toString().trim();

        subServices.add(
          SalonSubServiceData(
            name: name,
            charge: charge,
            duration: duration.isEmpty ? 'N/A' : duration,
            category: _serviceCategoryForName(name),
          ),
        );
      }
    }

    if (subServices.isNotEmpty) {
      return subServices;
    }

    final fallbackNames = _serviceNamesBySalonId[salonId] ?? const <String>[];
    return fallbackNames
        .map(
          (name) => SalonSubServiceData(
            name: name,
            charge: 0,
            duration: 'N/A',
            category: _serviceCategoryForName(name),
          ),
        )
        .toList();
  }

  List<StylistData> _buildStylists(Map<String, dynamic> data) {
    final topRatedNames = <String>{};

    final rawTopRated = data['top_rated_stylists'];
    if (rawTopRated is List) {
      for (final item in rawTopRated) {
        if (item is Map) {
          final name = (item['name'] ?? '').toString().trim();
          if (name.isNotEmpty) {
            topRatedNames.add(name.toLowerCase());
          }
        }
      }
    }

    final stylists = <StylistData>[];
    final rawStylists = data['stylists'];
    if (rawStylists is List) {
      for (final item in rawStylists) {
        if (item is! Map) {
          continue;
        }

        final name = (item['name'] ?? '').toString().trim();
        if (name.isEmpty) {
          continue;
        }

        final specialty = (item['specialty'] ?? '').toString().trim();
        stylists.add(
          StylistData(
            name: name,
            specialty: specialty.isEmpty ? 'Hair Specialist' : specialty,
            isTopRated: topRatedNames.contains(name.toLowerCase()),
          ),
        );
      }
    }

    return stylists;
  }

  List<String> _buildServicePills(List<SalonSubServiceData> subServices) {
    final preferredOrder = <String>[
      'Hair Cut',
      'Hair Styling',
      'Hair Treatments',
      'Combo',
    ];

    final available = subServices.map((item) => item.category).toSet();
    final ordered = <String>[];

    for (final label in preferredOrder) {
      if (available.remove(label)) {
        ordered.add(label);
      }
    }

    final remaining = available.toList()..sort();
    ordered.addAll(remaining);

    if (ordered.isEmpty) {
      return const <String>['Combo'];
    }

    return ordered;
  }

  List<String> _serviceNamesForSalon(Map<String, Object> salon) {
    final id = (salon['id'] ?? '').toString();
    final mapped = _serviceNamesBySalonId[id];
    if (mapped != null && mapped.isNotEmpty) {
      return mapped;
    }

    final rawServices = salon['services'];
    if (rawServices is List) {
      return rawServices
          .whereType<Map>()
          .map((item) => (item['service_name'] ?? '').toString().trim())
          .where((name) => name.isNotEmpty)
          .toList();
    }
    return const <String>['Haircut', 'Facial'];
  }

  Map<String, Object> _buildFullSalonPayload(Map<String, Object> salon) {
    final name = (salon['name'] ?? '').toString();
    final city = (salon['city'] ?? '').toString();
    final state = (salon['state'] ?? '').toString();

    final defaultAddress = '$city, $state';
    final defaultDescription =
        'Professional salon in $city offering modern beauty services.';

    final serviceNames = _serviceNamesForSalon(salon);

    return <String, Object>{
      ...salon,
      'full_address': salon.containsKey('full_address')
          ? salon['full_address'] as Object
          : defaultAddress,
      'opening_hours': salon.containsKey('opening_hours')
          ? salon['opening_hours'] as Object
          : const <String, Object>{
              'days': 'Monday - Sunday',
              'timing': '10:00 AM - 08:00 PM',
            },
      'short_description': salon.containsKey('short_description')
          ? salon['short_description'] as Object
          : (name.isEmpty ? defaultDescription : '$name: $defaultDescription'),
      'services': salon.containsKey('services')
          ? salon['services'] as Object
          : serviceNames
                .map(
                  (name) => <String, Object>{
                    'service_name': name,
                    'charge': 0,
                    'duration_time': 'N/A',
                  },
                )
                .toList(),
      'service_names': serviceNames,
    };
  }

  Future<void> ensureSeeded() async {
    try {
      final collection = _firestore.collection(_collection);
      final existing = await collection.limit(1).get();

      if (existing.docs.isEmpty) {
        final batch = _firestore.batch();
        for (final salon in _seedSalons) {
          final id = salon['id']!.toString();
          batch.set(collection.doc(id), {
            ..._buildFullSalonPayload(salon),
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
        return;
      }

      final firstId = _seedSalons.first['id']!.toString();
      final firstSnapshot = await collection.doc(firstId).get();
      final firstData = firstSnapshot.data();
      final alreadyHasExtendedFields =
          firstData != null &&
          firstData['short_description'] != null &&
          firstData['opening_hours'] != null &&
          firstData['services'] != null &&
          firstData['service_names'] != null;

      if (alreadyHasExtendedFields) {
        return;
      }

      final batch = _firestore.batch();
      for (final salon in _seedSalons) {
        final id = salon['id']!.toString();
        batch.set(collection.doc(id), {
          ..._buildFullSalonPayload(salon),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await batch.commit();
    } catch (error) {
      if (!_isPermissionDeniedError(error)) {
        rethrow;
      }
    }
  }

  Future<List<SalonCardData>> fetchSalons({
    String? state,
    String? city,
    String? serviceName,
  }) async {
    Query<Map<String, dynamic>> query = _firestore.collection(_collection);

    final normalizedState = state?.trim() ?? '';
    final normalizedCity = city?.trim() ?? '';

    if (normalizedState.isNotEmpty) {
      query = query.where('state', isEqualTo: normalizedState);
    }
    if (normalizedCity.isNotEmpty) {
      query = query.where('city', isEqualTo: normalizedCity);
    }

    final snapshot = await query.get();
    final normalizedService = serviceName?.trim().toLowerCase() ?? '';

    final filteredDocs = snapshot.docs.where((doc) {
      if (normalizedService.isEmpty || normalizedService == 'all services') {
        return true;
      }

      final data = doc.data();
      final fallbackNames = _serviceNamesBySalonId[doc.id] ?? const <String>[];

      for (final name in fallbackNames) {
        if (name.trim().toLowerCase() == normalizedService) {
          return true;
        }
      }

      final rawNames = data['service_names'];
      if (rawNames is List) {
        for (final name in rawNames) {
          if (name.toString().trim().toLowerCase() == normalizedService) {
            return true;
          }
        }
      }

      final rawServices = data['services'];
      if (rawServices is List) {
        for (final item in rawServices) {
          if (item is Map) {
            final name = (item['service_name'] ?? '').toString();
            if (name.trim().toLowerCase() == normalizedService) {
              return true;
            }
          }
        }
      }
      return false;
    }).toList();

    return List<SalonCardData>.generate(filteredDocs.length, (index) {
      final data = filteredDocs[index].data();
      final rating = (data['rating'] as num?)?.toDouble() ?? 0;
      final reviews = (data['reviews_count'] as num?)?.toInt() ?? 0;
      final distance = (data['distance_km'] as num?)?.toDouble() ?? 0;
      final cityValue = (data['city'] ?? '').toString();
      final stateValue = (data['state'] ?? '').toString();

      return SalonCardData(
        salonId: filteredDocs[index].id,
        name: (data['name'] ?? 'Unknown Salon').toString(),
        distance: _formatDistance(distance),
        location: '$cityValue, $stateValue',
        rating: rating.toStringAsFixed(1),
        reviews: reviews.toString(),
        imageAsset: _salonImageAssets[index % _salonImageAssets.length],
      );
    });
  }

  Future<SalonDetailData> fetchSalonDetail(String salonId) async {
    final doc = await _firestore.collection(_collection).doc(salonId).get();
    final seed = _seedSalonById(salonId);

    if (!doc.exists && seed == null) {
      throw StateError('Salon not found: $salonId');
    }

    final merged = <String, dynamic>{};
    if (seed != null) {
      merged.addAll(_buildFullSalonPayload(seed));
    }
    if (doc.data() != null) {
      merged.addAll(doc.data()!);
    }

    final city = (merged['city'] ?? '').toString().trim();
    final state = (merged['state'] ?? '').toString().trim();
    final fallbackAddress = [
      city,
      state,
    ].where((part) => part.isNotEmpty).join(', ');

    String openingDays = 'Monday - Sunday';
    String openingTiming = '10:00 AM - 08:00 PM';
    final rawOpening = merged['opening_hours'];
    if (rawOpening is Map) {
      final daysValue = (rawOpening['days'] ?? '').toString().trim();
      final timingValue = (rawOpening['timing'] ?? '').toString().trim();
      if (daysValue.isNotEmpty) {
        openingDays = daysValue;
      }
      if (timingValue.isNotEmpty) {
        openingTiming = timingValue;
      }
    }

    final subServices = _buildSubServices(salonId, merged);
    final servicePills = _buildServicePills(subServices);
    final stylists = _buildStylists(merged);

    final rawRating = merged['rating'];
    final rating = rawRating is num
        ? rawRating.toDouble()
        : double.tryParse(rawRating?.toString() ?? '') ?? 0;

    final rawReviews = merged['reviews_count'];
    final reviews = rawReviews is num
        ? rawReviews.toInt()
        : int.tryParse(rawReviews?.toString() ?? '') ?? 0;

    final rawDistance = merged['distance_km'];
    final distanceKm = rawDistance is num
        ? rawDistance.toDouble()
        : double.tryParse(rawDistance?.toString() ?? '') ?? 0;

    return SalonDetailData(
      salonId: salonId,
      name: (merged['name'] ?? 'Unknown Salon').toString(),
      distanceKm: distanceKm,
      fullAddress: (merged['full_address'] ?? fallbackAddress).toString(),
      openingDays: openingDays,
      openingTiming: openingTiming,
      discountOffer: (merged['discount_offer'] ?? '').toString().trim(),
      rating: rating,
      reviewsCount: reviews,
      shortDescription: (merged['short_description'] ?? '').toString(),
      imageAsset: _salonImageAssets[_imageIndexForSalonId(salonId)],
      servicePills: servicePills,
      subServices: subServices,
      stylists: stylists,
    );
  }

  Future<List<String>> fetchUniqueServiceNames({
    String? state,
    String? city,
  }) async {
    Query<Map<String, dynamic>> query = _firestore.collection(_collection);

    final normalizedState = state?.trim() ?? '';
    final normalizedCity = city?.trim() ?? '';

    if (normalizedState.isNotEmpty) {
      query = query.where('state', isEqualTo: normalizedState);
    }
    if (normalizedCity.isNotEmpty) {
      query = query.where('city', isEqualTo: normalizedCity);
    }

    final snapshot = await query.get();
    final names = <String>{};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final fallbackNames = _serviceNamesBySalonId[doc.id] ?? const <String>[];
      for (final name in fallbackNames) {
        final normalized = name.trim();
        if (normalized.isNotEmpty) {
          names.add(normalized);
        }
      }

      final rawNames = data['service_names'];
      if (rawNames is List) {
        for (final item in rawNames) {
          final name = item.toString().trim();
          if (name.isNotEmpty) {
            names.add(name);
          }
        }
      } else {
        final rawServices = data['services'];
        if (rawServices is List) {
          for (final item in rawServices) {
            if (item is Map) {
              final name = (item['service_name'] ?? '').toString().trim();
              if (name.isNotEmpty) {
                names.add(name);
              }
            }
          }
        }
      }
    }

    final sorted = names.toList()..sort();
    return sorted;
  }

  Future<Map<String, List<String>>> fetchCitiesByState() async {
    final snapshot = await _firestore.collection(_collection).get();
    final Map<String, Set<String>> grouped = <String, Set<String>>{};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final state = (data['state'] ?? '').toString().trim();
      final city = (data['city'] ?? '').toString().trim();
      if (state.isEmpty || city.isEmpty) {
        continue;
      }

      grouped.putIfAbsent(state, () => <String>{}).add(city);
    }

    final result = <String, List<String>>{};
    for (final entry in grouped.entries) {
      final cities = entry.value.toList()..sort();
      result[entry.key] = cities;
    }
    return result;
  }

  Future<List<String>> fetchLocationOptions() async {
    final byState = await fetchCitiesByState();
    final options = <String>[];

    final states = byState.keys.toList()..sort();
    for (final state in states) {
      final cities = byState[state] ?? const <String>[];
      for (final city in cities) {
        options.add('$city, $state');
      }
    }
    return options;
  }

  static String _formatDistance(double km) {
    if (km == km.roundToDouble()) {
      return '${km.toStringAsFixed(0)} km';
    }
    return '${km.toStringAsFixed(1)} km';
  }
}
