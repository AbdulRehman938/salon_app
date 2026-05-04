import 'package:flutter/material.dart';
import '../models/salon_card_data.dart';

class SalonCard extends StatelessWidget {
  final SalonCardData salon;
  final bool isFavorite;
  final VoidCallback? onFavorite;
  final VoidCallback? onTap;

  const SalonCard({
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
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  salon.imageAsset,
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 72,
                    height: 72,
                    color: Colors.grey[200],
                    child: const Icon(Icons.image_outlined, color: Colors.grey),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(
                  top: 12,
                  bottom: 12,
                  right: 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
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
                        Text(
                          salon.distance,
                          style: const TextStyle(
                            color: Color(0xFF757575),
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 17,
                          color: Color(0xFF757575),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            salon.location,
                            style: const TextStyle(
                              color: Color(0xFF757575),
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          size: 19,
                          color: Color(0xFFFFC233),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          salon.rating,
                          style: const TextStyle(
                            color: Color(0xFF1A1A1A),
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '(${salon.reviews})',
                          style: const TextStyle(
                            color: Color(0xFF757575),
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
