import 'package:flutter/material.dart';
import '../../../auth/data/services/auth_service.dart';
import '../../data/services/salon_data_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../models/salon_card_data.dart';
import '../widgets/dashboard_bottom_nav.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/dashboard_search_bar.dart';
import '../widgets/salon_card.dart';
import '../widgets/service_pill.dart';
import 'bookings_page.dart';
import 'profile_page.dart';
import 'salon_detail_page.dart';
import 'search_location_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  static const String _allServicesLabel = 'All Services';

  int _selectedServiceIndex = 0;
  int _selectedNavIndex = 0;
  String _selectedLocation = 'No location';
  final AuthService _authService = AuthService();
  final SalonDataService _salonDataService = SalonDataService();
  final TextEditingController _citySearchController = TextEditingController();

  bool _isCityDropdownOpen = false;
  bool _isCityLoading = false;
  String _cityFilter = '';
  String _selectedState = '';
  List<String> _citiesForSelectedState = <String>[];
  Map<String, List<String>> _citiesByState = <String, List<String>>{};
  List<String> _allLocationOptions = <String>[];
  bool _isSalonsLoading = true;

  List<String> _services = <String>[_allServicesLabel];
  List<SalonCardData> _salons = <SalonCardData>[];

  @override
  void initState() {
    super.initState();
    _initializeDashboard();
  }

  Future<void> _initializeDashboard() async {
    await _salonDataService.ensureSeeded();
    await _loadLocationOptionsFromDatabase();
    await _loadServicesFromDatabase();
    await _loadSalonsFromDatabase();
  }

  Future<void> _loadServicesFromDatabase() async {
    final parsed = _parseCityState(_selectedLocation);
    final names = await _salonDataService.fetchUniqueServiceNames(
      state: parsed.state.isNotEmpty ? parsed.state : null,
      city: parsed.city.isNotEmpty ? parsed.city : null,
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _services = <String>[_allServicesLabel, ...names];
      if (_selectedServiceIndex >= _services.length) {
        _selectedServiceIndex = 0;
      }
    });
  }

  @override
  void dispose() {
    _citySearchController.dispose();
    super.dispose();
  }

  Future<void> _loadLocationOptionsFromDatabase() async {
    final byState = await _salonDataService.fetchCitiesByState();
    final options = await _salonDataService.fetchLocationOptions();

    if (!mounted) {
      return;
    }

    setState(() {
      _citiesByState = byState;
      _allLocationOptions = options;
      if (_allLocationOptions.isNotEmpty &&
          !_allLocationOptions.contains(_selectedLocation)) {
        _selectedLocation = _allLocationOptions.first;
      }
    });
  }

  Future<void> _openLocationSearch() async {
    final selected = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => SearchLocationPage(
          initialLocation: _selectedLocation,
          availableLocations: _allLocationOptions,
        ),
      ),
    );

    if (selected == null || selected.trim().isEmpty || !mounted) {
      return;
    }

    await _authService.saveLocationSearch(selectedLocation: selected.trim());

    setState(() {
      _selectedLocation = selected.trim();
    });

    await _loadServicesFromDatabase();
    await _loadSalonsFromDatabase();
  }

  Future<void> _loadSalonsFromDatabase() async {
    if (mounted) {
      setState(() {
        _isSalonsLoading = true;
      });
    }

    try {
      await _salonDataService.ensureSeeded();

      final parsed = _parseCityState(_selectedLocation);
      final selectedService = _services[_selectedServiceIndex];
      final salons = await _salonDataService.fetchSalons(
        state: parsed.state.isNotEmpty ? parsed.state : null,
        city: parsed.city.isNotEmpty ? parsed.city : null,
        serviceName: selectedService,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _salons = salons;
        _isSalonsLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _salons = <SalonCardData>[];
        _isSalonsLoading = false;
      });
    }
  }

  Future<void> _openSalonDetail(SalonCardData salon) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SalonDetailPage(salonId: salon.salonId),
      ),
    );
  }

  IconData _iconForService(String name) {
    final key = name.toLowerCase();
    if (key.contains('hair') || key.contains('cut') || key.contains('trim')) {
      return Icons.content_cut_rounded;
    }
    if (key.contains('facial') || key.contains('cleanup')) {
      return Icons.face_retouching_natural;
    }
    if (key.contains('makeup') || key.contains('bridal')) {
      return Icons.auto_fix_high_rounded;
    }
    if (key.contains('wax')) {
      return Icons.clean_hands_rounded;
    }
    if (key.contains('massage') || key.contains('spa')) {
      return Icons.spa_rounded;
    }
    if (key.contains('color') ||
        key.contains('dye') ||
        key.contains('balayage')) {
      return Icons.color_lens_rounded;
    }
    if (key.contains('manicure') || key.contains('nail')) {
      return Icons.back_hand_rounded;
    }
    return Icons.design_services_rounded;
  }

  ({String city, String state}) _parseCityState(String location) {
    final value = location.trim();
    if (value.isEmpty || value.toLowerCase() == 'no location') {
      return (city: '', state: '');
    }

    final pieces = value
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (pieces.length < 2) {
      return (city: value, state: '');
    }

    return (
      city: pieces.first.trim(),
      state: pieces.sublist(1).join(',').trim(),
    );
  }

  Future<void> _toggleCityDropdown() async {
    if (_isCityDropdownOpen) {
      setState(() {
        _isCityDropdownOpen = false;
      });
      return;
    }

    if (_citiesByState.isEmpty) {
      return;
    }

    final parsed = _parseCityState(_selectedLocation);
    final sortedStates = _citiesByState.keys.toList()..sort();
    final state = _citiesByState.containsKey(parsed.state)
        ? parsed.state
        : sortedStates.first;
    final cities = _citiesByState[state] ?? <String>[];

    setState(() {
      _isCityDropdownOpen = true;
      _isCityLoading = false;
      _selectedState = state;
      _citiesForSelectedState = cities;
      _cityFilter = '';
    });

    _citySearchController.clear();
  }

  List<String> get _filteredCities {
    final q = _cityFilter.trim().toLowerCase();
    if (q.isEmpty) {
      return _citiesForSelectedState;
    }
    return _citiesForSelectedState
        .where((city) => city.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _selectCityFromDropdown(String city) async {
    final state = _selectedState.trim();
    if (state.isEmpty) {
      return;
    }

    final location = '$city, $state';
    await _authService.saveLocationSearch(selectedLocation: location);

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedLocation = location;
      _isCityDropdownOpen = false;
    });

    await _loadServicesFromDatabase();
    await _loadSalonsFromDatabase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DashboardHeader(
                            locationLabel: _selectedLocation,
                            onLocationTap: _toggleCityDropdown,
                          ),
                        ),
                      ],
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: _isCityDropdownOpen
                          ? Container(
                              key: const ValueKey<String>('city-dropdown'),
                              margin: const EdgeInsets.only(top: 10),
                              padding: const EdgeInsets.fromLTRB(
                                12,
                                12,
                                12,
                                10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x1F000000),
                                    blurRadius: 14,
                                    offset: Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    height: 42,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F1F1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.search_rounded,
                                          color: AppColors.gray1,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: TextField(
                                            controller: _citySearchController,
                                            onChanged: (value) {
                                              setState(() {
                                                _cityFilter = value;
                                              });
                                            },
                                            decoration: InputDecoration(
                                              border: InputBorder.none,
                                              hintText:
                                                  'Search city in $_selectedState',
                                              hintStyle: const TextStyle(
                                                color: AppColors.gray1,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  if (_isCityLoading)
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  else if (_filteredCities.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      child: Text(
                                        'No cities found for this state.',
                                        style: TextStyle(
                                          color: AppColors.gray1,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    )
                                  else
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxHeight: 220,
                                      ),
                                      child: ListView.separated(
                                        shrinkWrap: true,
                                        itemCount: _filteredCities.length,
                                        separatorBuilder: (_, index) =>
                                            const Divider(
                                              height: 1,
                                              color: Color(0xFFE9E9E9),
                                            ),
                                        itemBuilder: (context, index) {
                                          final city = _filteredCities[index];
                                          return ListTile(
                                            dense: true,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 4,
                                                ),
                                            title: Text(
                                              city,
                                              style: const TextStyle(
                                                color: AppColors.dark1,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            onTap: () =>
                                                _selectCityFromDropdown(city),
                                          );
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 14),
                    DashboardSearchBar(onTap: _openLocationSearch),
                    const SizedBox(height: 18),
                    const Text(
                      'Services',
                      style: TextStyle(
                        color: AppColors.dark1,
                        fontSize: 31 / 2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List<Widget>.generate(_services.length, (i) {
                          final service = _services[i];
                          return ServicePill(
                            label: service,
                            icon: _iconForService(service),
                            isSelected: _selectedServiceIndex == i,
                            onTap: () async {
                              if (_selectedServiceIndex == i) {
                                return;
                              }
                              setState(() {
                                _selectedServiceIndex = i;
                              });
                              await _loadSalonsFromDatabase();
                            },
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Nearby Salons',
                            style: TextStyle(
                              color: AppColors.dark1,
                              fontSize: 31 / 2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {},
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.main,
                            padding: EdgeInsets.zero,
                          ),
                          icon: const Icon(Icons.map_outlined, size: 18),
                          label: const Text(
                            'View on Map',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_isSalonsLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_salons.isEmpty)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 22,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Column(
                          children: [
                            Icon(
                              Icons.storefront_outlined,
                              size: 28,
                              color: AppColors.gray1,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'No salons found for this location.',
                              style: TextStyle(
                                color: AppColors.dark1,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Try another city/state from the search or location dropdown.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.gray1,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ..._salons.map(
                        (salon) => SalonCard(
                          salon: salon,
                          onTap: () => _openSalonDetail(salon),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            DashboardBottomNav(
              selectedIndex: _selectedNavIndex,
              onChanged: (index) async {
                if (index == 1) {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BookingsPage()),
                  );
                  if (!mounted) {
                    return;
                  }
                  setState(() {
                    _selectedNavIndex = 0;
                  });
                  return;
                }

                if (index == 3) {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProfilePage()),
                  );
                  if (!mounted) {
                    return;
                  }
                  setState(() {
                    _selectedNavIndex = 0;
                  });
                  return;
                }

                setState(() {
                  _selectedNavIndex = index;
                });

                if (index > 1) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('This tab is coming soon.')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
