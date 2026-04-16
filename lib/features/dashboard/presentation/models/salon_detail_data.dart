import 'salon_sub_service_data.dart';
import 'stylist_data.dart';

class SalonDetailData {
  const SalonDetailData({
    required this.salonId,
    required this.name,
    required this.distanceKm,
    required this.fullAddress,
    required this.openingDays,
    required this.openingTiming,
    required this.discountOffer,
    required this.rating,
    required this.reviewsCount,
    required this.shortDescription,
    required this.imageAsset,
    required this.servicePills,
    required this.subServices,
    required this.stylists,
  });

  final String salonId;
  final String name;
  final double distanceKm;
  final String fullAddress;
  final String openingDays;
  final String openingTiming;
  final String discountOffer;
  final double rating;
  final int reviewsCount;
  final String shortDescription;
  final String imageAsset;
  final List<String> servicePills;
  final List<SalonSubServiceData> subServices;
  final List<StylistData> stylists;
}
