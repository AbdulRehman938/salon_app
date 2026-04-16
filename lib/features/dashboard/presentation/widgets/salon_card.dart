import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../models/salon_card_data.dart';

class SalonCard extends StatelessWidget {
  const SalonCard({super.key, required this.salon, this.onTap});

  final SalonCardData salon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFEFEF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    salon.imageAsset,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.image_outlined,
                        color: AppColors.gray2,
                        size: 28,
                      );
                    },
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
                            style: const TextStyle(
                              fontSize: 15,
                              color: AppColors.dark1,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          salon.distance,
                          style: const TextStyle(
                            color: AppColors.gray1,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: AppColors.gray1,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            salon.location,
                            style: const TextStyle(
                              color: AppColors.gray1,
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
                          size: 17,
                          color: Color(0xFFFFC233),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${salon.rating} (${salon.reviews})',
                          style: const TextStyle(
                            color: AppColors.dark2,
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
      ),
    );
  }
}
