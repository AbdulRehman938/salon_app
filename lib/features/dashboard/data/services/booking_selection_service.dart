import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../presentation/models/salon_sub_service_data.dart';

class BookingSelectionService {
  static const String _servicesStorageKey = 'selected_salon_services';
  static const String _stylistStorageKey = 'selected_stylist_choice';
  static const String _dateTimeStorageKey = 'selected_appointment_date_time';

  Future<void> saveSelectedServices({
    required String salonId,
    required List<SalonSubServiceData> services,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final payload = <String, Object>{
      'salonId': salonId,
      'selectedAt': DateTime.now().toIso8601String(),
      'services': services
          .map(
            (service) => <String, Object>{
              'name': service.name,
              'charge': service.charge,
              'duration': service.duration,
              'category': service.category,
            },
          )
          .toList(),
    };

    await prefs.setString(_servicesStorageKey, jsonEncode(payload));
  }

  Future<void> saveStylistSelection({
    required String salonId,
    required String selectionType,
    String? stylistName,
    String? specialty,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final payload = <String, Object?>{
      'salonId': salonId,
      'selectionType': selectionType,
      'stylistName': stylistName,
      'specialty': specialty,
      'selectedAt': DateTime.now().toIso8601String(),
    };

    await prefs.setString(_stylistStorageKey, jsonEncode(payload));
  }

  Future<void> saveDateTimeSelection({
    required String salonId,
    required String dateIso,
    required String timeLabel,
    int? discountPercent,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final payload = <String, Object?>{
      'salonId': salonId,
      'dateIso': dateIso,
      'timeLabel': timeLabel,
      'discountPercent': discountPercent,
      'selectedAt': DateTime.now().toIso8601String(),
    };

    await prefs.setString(_dateTimeStorageKey, jsonEncode(payload));
  }

  Future<StoredServiceSelection?> getSelectedServices({
    required String salonId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_servicesStorageKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final decoded = _decodeMap(raw);
    if (decoded == null || decoded['salonId']?.toString() != salonId) {
      return null;
    }

    final rawServices = decoded['services'];
    if (rawServices is! List) {
      return null;
    }

    final services = <SalonSubServiceData>[];
    for (final item in rawServices) {
      if (item is! Map) {
        continue;
      }

      final name = (item['name'] ?? '').toString().trim();
      if (name.isEmpty) {
        continue;
      }

      final charge = item['charge'] is num
          ? (item['charge'] as num).toDouble()
          : double.tryParse(item['charge']?.toString() ?? '') ?? 0;

      services.add(
        SalonSubServiceData(
          name: name,
          charge: charge,
          duration: (item['duration'] ?? 'N/A').toString(),
          category: (item['category'] ?? 'Combo').toString(),
        ),
      );
    }

    return StoredServiceSelection(salonId: salonId, services: services);
  }

  Future<StoredStylistSelection?> getStylistSelection({
    required String salonId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_stylistStorageKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final decoded = _decodeMap(raw);
    if (decoded == null || decoded['salonId']?.toString() != salonId) {
      return null;
    }

    final selectionType = (decoded['selectionType'] ?? '').toString().trim();
    if (selectionType.isEmpty) {
      return null;
    }

    return StoredStylistSelection(
      salonId: salonId,
      selectionType: selectionType,
      stylistName: decoded['stylistName']?.toString(),
      specialty: decoded['specialty']?.toString(),
    );
  }

  Future<StoredDateTimeSelection?> getDateTimeSelection({
    required String salonId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_dateTimeStorageKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final decoded = _decodeMap(raw);
    if (decoded == null || decoded['salonId']?.toString() != salonId) {
      return null;
    }

    final dateIso = (decoded['dateIso'] ?? '').toString().trim();
    final timeLabel = (decoded['timeLabel'] ?? '').toString().trim();
    if (dateIso.isEmpty || timeLabel.isEmpty) {
      return null;
    }

    final parsedDate = DateTime.tryParse(dateIso);
    if (parsedDate == null) {
      return null;
    }

    final rawDiscount = decoded['discountPercent'];
    final discountPercent = rawDiscount is num
        ? rawDiscount.toInt()
        : int.tryParse(rawDiscount?.toString() ?? '');

    return StoredDateTimeSelection(
      salonId: salonId,
      date: parsedDate,
      timeLabel: timeLabel,
      discountPercent: discountPercent,
    );
  }

  Map<String, dynamic>? _decodeMap(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }
}

class StoredServiceSelection {
  const StoredServiceSelection({required this.salonId, required this.services});

  final String salonId;
  final List<SalonSubServiceData> services;
}

class StoredStylistSelection {
  const StoredStylistSelection({
    required this.salonId,
    required this.selectionType,
    this.stylistName,
    this.specialty,
  });

  final String salonId;
  final String selectionType;
  final String? stylistName;
  final String? specialty;
}

class StoredDateTimeSelection {
  const StoredDateTimeSelection({
    required this.salonId,
    required this.date,
    required this.timeLabel,
    this.discountPercent,
  });

  final String salonId;
  final DateTime date;
  final String timeLabel;
  final int? discountPercent;
}
