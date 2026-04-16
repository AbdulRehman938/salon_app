import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class SearchLocationPage extends StatefulWidget {
  const SearchLocationPage({
    super.key,
    required this.initialLocation,
    required this.availableLocations,
  });

  final String initialLocation;
  final List<String> availableLocations;

  @override
  State<SearchLocationPage> createState() => _SearchLocationPageState();
}

class _SearchLocationPageState extends State<SearchLocationPage> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<String> get _visibleItems {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) {
      return widget.availableLocations;
    }
    return widget.availableLocations
        .where((item) => item.toLowerCase().contains(q))
        .toList();
  }

  void _selectLocation(String location) {
    Navigator.of(context).pop(location);
  }

  @override
  Widget build(BuildContext context) {
    final visibleItems = _visibleItems;
    final showNoResults = visibleItems.isEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 26,
                      minHeight: 26,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Search Location',
                    style: TextStyle(
                      color: AppColors.dark1,
                      fontSize: 30 / 2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8E8E8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: AppColors.gray1),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        onChanged: (value) {
                          setState(() {
                            _query = value;
                          });
                        },
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Enter address or city name',
                          hintStyle: TextStyle(color: AppColors.gray1),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (showNoResults)
                const Expanded(
                  child: Center(
                    child: Text(
                      'No salons found for this city/state.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.gray1,
                        fontSize: 16,
                        height: 1.3,
                      ),
                    ),
                  ),
                )
              else ...[
                const Text(
                  'Available Cities & States',
                  style: TextStyle(
                    color: AppColors.dark1,
                    fontSize: 34 / 2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: visibleItems.length,
                    itemBuilder: (context, index) {
                      final item = visibleItems[index];
                      final parts = item
                          .split(',')
                          .map((p) => p.trim())
                          .where((p) => p.isNotEmpty)
                          .toList();
                      final city = parts.isNotEmpty ? parts.first : item;
                      final state = parts.length > 1
                          ? parts.sublist(1).join(', ')
                          : '';
                      return InkWell(
                        onTap: () => _selectLocation(item),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 22,
                                color: AppColors.dark1,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      city,
                                      style: const TextStyle(
                                        color: AppColors.dark1,
                                        fontSize: 32 / 2,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      state,
                                      style: const TextStyle(
                                        color: AppColors.gray1,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: AppColors.gray1,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
