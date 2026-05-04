import 'package:flutter/material.dart';
import '../models/salon_card_data.dart';

class MapSalonCard extends StatelessWidget {
  final SalonCardData salon;
  final bool isFavorite;
  final VoidCallback? onFavorite;
  final VoidCallback? onTap;

  const MapSalonCard({
    super.key,
    required this.salon,
    this.isFavorite = false,
    this.onFavorite,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 300,
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image with favorite button
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      salon.imageAsset,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 120,
                        width: double.infinity,
                        color: Colors.grey[200],
                        child: const Icon(Icons.image_outlined, color: Colors.grey),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: onFavorite,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: isFavorite ? Colors.red : Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Title and Distance
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      salon.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    salon.distance,
                    style: const TextStyle(
                      color: Color(0xFF757575),
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Location
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: Color(0xFF757575),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      salon.location,
                      style: const TextStyle(
                        color: Color(0xFF757575),
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Rating
              Row(
                children: [
                  const Icon(
                    Icons.star,
                    size: 18,
                    color: Color(0xFFFFC233),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    salon.rating,
                    style: const TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '(${salon.reviews})',
                    style: const TextStyle(
                      color: Color(0xFF757575),
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
