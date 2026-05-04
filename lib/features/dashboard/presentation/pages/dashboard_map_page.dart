import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:salon_app/core/constants/pakistan_cities.dart';
import '../../presentation/models/salon_card_data.dart';
import '../../data/services/salon_data_service.dart';
import '../widgets/map_salon_card.dart';
import 'salon_detail_page.dart';

class DashboardMapPage extends StatefulWidget {
  final String initialLocation;
  final List<SalonCardData> salons;
  final LatLng? searchLocation;
  final Function(String)? onFavoriteToggle;
  final Set<String>? favoriteSalonIds;
  final Map<String, List<String>> citiesByState;
  final Function(String)? onLocationChanged;

  const DashboardMapPage({
    super.key,
    this.initialLocation = 'Lakewood, CA',
    this.salons = const [],
    this.searchLocation,
    this.onFavoriteToggle,
    this.favoriteSalonIds,
    this.citiesByState = const {},
    this.onLocationChanged,
  });

  @override
  State<DashboardMapPage> createState() => _DashboardMapPageState();
}

class _DashboardMapPageState extends State<DashboardMapPage> with SingleTickerProviderStateMixin {
  late final TextEditingController _searchController;
  late final TextEditingController _citySearchController;
  late final LatLng _initialPosition;
  int _selectedCardIndex = 0;

  bool _isCityDropdownOpen = false;
  late final AnimationController _dropdownController;
  late final Animation<Offset> _dropdownOffset;
  String _cityFilter = '';
  String _selectedState = '';
  List<String> _citiesForSelectedState = <String>[];

  final SalonDataService _salonDataService = SalonDataService();
  Set<String> _favoriteSalonIds = {};
  
  // Filter states
  double _minRating = 0.0;
  String _selectedPriceRange = 'All';
  double _maxDistanceKm = 20.0;
  String _selectedService = 'All Services';
  List<String> _availableServices = ['All Services'];

  final MapController _mapController = MapController();
  late final ScrollController _scrollController;
  bool _isAnimatingCardScroll = false;
  
  /// Dynamic cache for geocoded city coordinates
  static final Map<String, LatLng> _geocodedCache = {};

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _favoriteSalonIds = widget.favoriteSalonIds ?? {};
    _loadFavorites();
    _loadServices();
    _searchController = TextEditingController(text: widget.initialLocation);
    _searchController.addListener(_onSearchChanged);
    _citySearchController = TextEditingController();
    _dropdownController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _dropdownOffset = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _dropdownController,
        curve: Curves.easeOutCubic,
      ),
    );
    // Determine initial position based on filtered salons or city fallback
    final initialSalonsWithCoords = _filteredSalons.where((s) => s.latitude != null && s.longitude != null).toList();
    
    if (initialSalonsWithCoords.isNotEmpty) {
      _initialPosition = LatLng(
        initialSalonsWithCoords.first.latitude!,
        initialSalonsWithCoords.first.longitude!,
      );
    } else {
      // Try city fallback from local database
      final city = _parseCityState(widget.initialLocation).city.toLowerCase();
      _initialPosition = PakistanCities.coordinates[city] ?? const LatLng(31.5204, 74.3587);
    }
    
    debugPrint('DashboardMapPage: Initial location is "${widget.initialLocation}"');
    debugPrint('DashboardMapPage: Found ${initialSalonsWithCoords.length} salons with coordinates out of ${_filteredSalons.length} filtered salons');
    debugPrint('DashboardMapPage: Setting initial position to ${_initialPosition.latitude}, ${_initialPosition.longitude}');

    // Trigger map centering after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitMapToSalons();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _mapController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _citySearchController.dispose();
    _dropdownController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isAnimatingCardScroll) return;
    if (_filteredSalons.isEmpty) return;
    
    double offset = _scrollController.offset;
    int index = (offset / 316).round();
    
    if (index < 0) index = 0;
    if (index >= _filteredSalons.length) index = _filteredSalons.length - 1;
    
    if (index != _selectedCardIndex) {
      setState(() {
        _selectedCardIndex = index;
      });
      
      final salon = _filteredSalons[index];
      if (salon.latitude != null && salon.longitude != null) {
        _mapController.move(LatLng(salon.latitude!, salon.longitude!), 14);
      }
    }
  }

  void _fitMapToSalons() {
    final salons = _filteredSalons;
    final points = salons
        .where((s) => s.latitude != null && s.longitude != null)
        .map((s) => LatLng(s.latitude!, s.longitude!))
        .toList();
        
    debugPrint('DashboardMapPage: Fitting map to ${points.length} points for query "${_searchController.text}"');
        
    if (points.isEmpty) {
      debugPrint('DashboardMapPage: No points found to fit camera, trying local city database');
      final cityText = _searchController.text.trim();
      final cityKey = _parseCityState(cityText).city.toLowerCase();
      
      final fallback = PakistanCities.coordinates[cityKey];
      if (fallback != null) {
        debugPrint('DashboardMapPage: Moving camera to local city fallback: ${fallback.latitude}, ${fallback.longitude}');
        _mapController.move(fallback, 13);
      } else {
        debugPrint('DashboardMapPage: City "$cityKey" not found in local database, falling back to Lahore');
        _mapController.move(const LatLng(31.5204, 74.3587), 13);
      }
      return;
    }
    
    if (points.length == 1) {
      debugPrint('DashboardMapPage: Moving camera to single point: ${points.first.latitude}, ${points.first.longitude}');
      _mapController.move(points.first, 14);
      return;
    }
    
    final bounds = LatLngBounds.fromPoints(points);
    debugPrint('DashboardMapPage: Fitting camera to bounds: ${bounds.southWest} to ${bounds.northEast}');
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(50),
      ),
    );
  }

  CameraFit? _buildInitialCameraFit() {
    final points = _filteredSalons
        .where((s) => s.latitude != null && s.longitude != null)
        .map((s) => LatLng(s.latitude!, s.longitude!))
        .toList();
        
    if (points.isNotEmpty) {
      if (points.length == 1) {
        return null;
      }
      return CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.all(80), // Increased padding to show the border
      );
    }
    return null;
  }

  /// Generates points for a circular "city border" highlight around the salons
  List<LatLng> _getCityHighlightPoints() {
    final points = _filteredSalons
        .where((s) => s.latitude != null && s.longitude != null)
        .map((s) => LatLng(s.latitude!, s.longitude!))
        .toList();
    
    LatLng center;
    double maxDist = 0.05; // Default approx 5km

    if (points.isEmpty) {
      final city = _parseCityState(_searchController.text).city.toLowerCase();
      center = PakistanCities.coordinates[city] ?? const LatLng(31.5204, 74.3587);
    } else {
      // Calculate center
      double avgLat = points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length;
      double avgLng = points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length;
      center = LatLng(avgLat, avgLng);

      // Calculate radius
      for (final p in points) {
        final dist = (p.latitude - avgLat).abs() + (p.longitude - avgLng).abs();
        if (dist > maxDist) maxDist = dist;
      }
      maxDist += 0.01; // buffer
    }

    // Generate circle points
    final simpleCircle = <LatLng>[];
    for (int i = 0; i <= 60; i++) {
      final angle = (i * 6) * (pi / 180);
      simpleCircle.add(LatLng(
        center.latitude + maxDist * 1.1 * sin(angle),
        center.longitude + maxDist * 1.4 * cos(angle),
      ));
    }

    return simpleCircle;
  }

  ({String city, String state}) _parseCityState(String location) {
    final value = location.trim();
    if (value.isEmpty || value.toLowerCase() == 'no location') {
      return (city: '', state: '');
    }

    final pieces = value.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
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
      await _dropdownController.reverse();
      return;
    }

    if (widget.citiesByState.isEmpty) return;

    final parsed = _parseCityState(_searchController.text);
    final sortedStates = widget.citiesByState.keys.toList()..sort();
    final state = widget.citiesByState.containsKey(parsed.state)
        ? parsed.state
        : sortedStates.first;
    final cities = widget.citiesByState[state] ?? <String>[];

    setState(() {
      _isCityDropdownOpen = true;
      _selectedState = state;
      _citiesForSelectedState = cities;
      _cityFilter = '';
    });

    _citySearchController.clear();
    await _dropdownController.forward();
  }

  List<String> get _filteredCities {
    final q = _cityFilter.trim().toLowerCase();
    if (q.isEmpty) return _citiesForSelectedState;
    return _citiesForSelectedState.where((city) => city.toLowerCase().contains(q)).toList();
  }

  Future<void> _selectCityFromDropdown(String city) async {
    final state = _selectedState.trim();
    if (state.isEmpty) return;
    
    final location = '$city, $state';
    
    setState(() {
      _isCityDropdownOpen = false;
      _searchController.text = location;
    });
    
    if (widget.onLocationChanged != null) {
      widget.onLocationChanged!(location);
    }
    
    await _dropdownController.reverse();
  }

  void _onSearchChanged() {
    setState(() {
      _selectedCardIndex = 0; // reset selection on filter change
    });
    // Use a small delay to ensure state is updated and map is ready
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _fitMapToSalons();
      }
    });
  }

  Future<void> _loadServices() async {
    final services = await _salonDataService.fetchUniqueServiceNames();
    if (mounted) {
      setState(() {
        _availableServices = ['All Services', ...services];
      });
    }
  }

  List<SalonCardData> get _filteredSalons {
    final query = _searchController.text.trim().toLowerCase();
    
    return widget.salons.where((salon) {
      // 1. Location Search Filter
      final matchesLocation = query.isEmpty || salon.location.toLowerCase().contains(query);
      if (!matchesLocation) return false;

      // 2. Rating Filter
      final rating = double.tryParse(salon.rating) ?? 0.0;
      if (rating < _minRating) return false;

      // 3. Price Filter (Mock logic based on distance/id for now)
      if (_selectedPriceRange != 'All') {
        final priceLevel = (salon.salonId.hashCode % 3 == 0) ? '\$\$\$' : (salon.salonId.hashCode % 2 == 0 ? '\$\$' : '\$');
        if (priceLevel != _selectedPriceRange) return false;
      }

      // 4. Distance Filter
      final distance = double.tryParse(salon.distance.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
      if (distance > _maxDistanceKm) return false;

      return true;
    }).toList();
  }

  Future<void> _loadFavorites() async {
    final favorites = await _salonDataService.fetchFavoriteSalonIdsForCurrentUser();
    if (mounted) {
      setState(() {
        _favoriteSalonIds = favorites.toSet();
      });
    }
  }

  Future<void> _onCardTap(int index) async {
    setState(() {
      _selectedCardIndex = index;
    });

    final salon = _filteredSalons[index];
    if (salon.latitude != null && salon.longitude != null) {
      _mapController.move(LatLng(salon.latitude!, salon.longitude!), 14);
    }

    _isAnimatingCardScroll = true;
    await _scrollController.animateTo(
      index * 316.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    _isAnimatingCardScroll = false;
  }

  Future<void> _onFavoriteTap(String salonId) async {
    final isCurrentlyFavorite = _favoriteSalonIds.contains(salonId);

    if (isCurrentlyFavorite) {
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Remove from Favorites?'),
            content: const Text('Are you sure you want to remove this salon from your favorites?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Remove'),
              ),
            ],
          );
        },
      );

      if (confirm != true) return;
    }

    final newFavoriteState = !isCurrentlyFavorite;

    setState(() {
      if (newFavoriteState) {
        _favoriteSalonIds.add(salonId);
      } else {
        _favoriteSalonIds.remove(salonId);
      }
    });

    try {
      await _salonDataService.setSalonFavoriteForCurrentUser(
        salonId: salonId,
        isFavorite: newFavoriteState,
      );

      if (newFavoriteState && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Added to favorites!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (isCurrentlyFavorite) {
            _favoriteSalonIds.add(salonId);
          } else {
            _favoriteSalonIds.remove(salonId);
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update favorites.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }

    if (widget.onFavoriteToggle != null) {
      widget.onFavoriteToggle!(salonId);
    }
  }

  void _onCardOpenDetail(SalonCardData salon) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SalonDetailPage(salonId: salon.salonId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: widget.searchLocation ?? _initialPosition,
                initialZoom: 13,
                onMapReady: () {
                  debugPrint('DashboardMapPage: Map is ready');
                  // Use a small delay to ensure tiles start loading
                  Future.delayed(const Duration(milliseconds: 300), () {
                    if (mounted) {
                      _fitMapToSalons();
                    }
                  });
                },
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.salon_app',
                ),
                // City Area Highlight (Red Border)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _getCityHighlightPoints(),
                      color: Colors.red.withOpacity(0.6),
                      strokeWidth: 4,
                    ),
                  ],
                ),
                MarkerLayer(markers: _buildMarkers()),
              ],
            ),
            // Top bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const Text(
                          'Map View',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: TextField(
                                controller: _searchController,
                                readOnly: true,
                                onTap: _toggleCityDropdown,
                                decoration: const InputDecoration(
                                  hintText: 'Lakewood, California',
                                  prefixIcon: Icon(
                                    Icons.location_on_outlined,
                                    color: Color(0xFF4A90E2),
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: _showFilterSheet,
                            child: Container(
                              height: 50,
                              width: 50,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFEEEEEE),
                                ),
                              ),
                              child: const Icon(
                                Icons.tune_rounded,
                                color: Color(0xFF4A90E2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Salon cards
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SizedBox(
                height: 290,
                child: ListView.builder(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  itemCount: _filteredSalons.length,
                  itemBuilder: (context, index) {
                    final salon = _filteredSalons[index];
                    final isFavorite = _favoriteSalonIds.contains(salon.salonId);
                    return Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: MapSalonCard(
                        salon: salon,
                        isFavorite: isFavorite,
                        onFavorite: () => _onFavoriteTap(salon.salonId),
                        onTap: () => _onCardOpenDetail(salon),
                      ),
                    );
                  },
                ),
              ),
            ),
            // Dropdown overlay
            if (_isCityDropdownOpen) ...[
              Positioned.fill(
                child: GestureDetector(
                  onTap: () async {
                    if (_isCityDropdownOpen) {
                      setState(() {
                        _isCityDropdownOpen = false;
                      });
                      await _dropdownController.reverse();
                    }
                  },
                  behavior: HitTestBehavior.translucent,
                  child: Container(color: Colors.transparent),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: SlideTransition(
                  position: _dropdownOffset,
                  child: Container(
                    key: const ValueKey<String>('city-dropdown-map'),
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x1F000000),
                          blurRadius: 14,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Container(
                                  height: 42,
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F1F1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.search_rounded, color: Color(0xFF757575)),
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
                                            hintText: 'Search city in $_selectedState',
                                            hintStyle: const TextStyle(color: Color(0xFF757575)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, color: Color(0xFF757575)),
                                tooltip: 'Close',
                                onPressed: () async {
                                  setState(() {
                                    _isCityDropdownOpen = false;
                                  });
                                  await _dropdownController.reverse();
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (_filteredCities.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: Text(
                                'No cities found for this state.',
                                style: TextStyle(
                                  color: Color(0xFF757575),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            )
                          else
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 220),
                              child: ListView.separated(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                itemCount: _filteredCities.length,
                                separatorBuilder: (_, index) => const Divider(
                                  height: 1,
                                  color: Color(0xFFE9E9E9),
                                ),
                                itemBuilder: (context, index) {
                                  final city = _filteredCities[index];
                                  return ListTile(
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                                    title: Text(
                                      city,
                                      style: const TextStyle(
                                        color: Color(0xFF1A1A1A),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    onTap: () => _selectCityFromDropdown(city),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Marker> _buildMarkers() {
    final List<Marker> markers = [];
    final salonsToDisplay = _filteredSalons;
    debugPrint('DashboardMapPage: Building markers for ${salonsToDisplay.length} salons');
    int markerCount = 0;
    
    // Salon markers
    for (int i = 0; i < salonsToDisplay.length; i++) {
      final salon = salonsToDisplay[i];
      
      // Use salon coordinates if available, otherwise use city fallback
      double? lat = salon.latitude;
      double? lng = salon.longitude;
      
      if (lat == null || lng == null) {
        // Parse city from salon location (e.g. "Rahim Yar Khan, Punjab")
        final city = _parseCityState(salon.location).city.toLowerCase();
        
        // Try to find the city in our database, fallback to Lahore if missing
        final fallback = PakistanCities.coordinates[city] ?? PakistanCities.coordinates['lahore']!;
        
        // Use a deterministic spread (circular/spiral) based on index
        // so markers don't overlap exactly
        final double angle = (i * 137.5) * (pi / 180); // Golden angle for even distribution
        final double radius = 0.003 * sqrt(i + 1); // Gradually increasing radius
        
        lat = fallback.latitude + radius * sin(angle);
        lng = fallback.longitude + radius * cos(angle) * 1.2;
      }

      if (lat != null && lng != null) {
        markerCount++;
        final isSelected = i == _selectedCardIndex;
        markers.add(
          Marker(
            width: isSelected ? 60 : 45,
            height: isSelected ? 60 : 45,
            point: LatLng(lat, lng),
            child: GestureDetector(
              onTap: () => _onCardTap(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? const Color(0xFF2962FF) : Colors.transparent,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.location_on,
                  color: isSelected
                      ? const Color(0xFF2962FF)
                      : const Color(0xFF4A90E2),
                  size: isSelected ? 38 : 28,
                ),
              ),
            ),
          ),
        );
      }
    }
    debugPrint('DashboardMapPage: Created $markerCount blue thumbpin markers');
    // Yellow pin for search location
    if (widget.searchLocation != null) {
      markers.add(
        Marker(
          width: 48,
          height: 48,
          point: widget.searchLocation!,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.yellow.withOpacity(0.4),
                  blurRadius: 18,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: const Icon(Icons.location_on, color: Colors.amber, size: 36),
          ),
        ),
      );
    }
    return markers;
  }

  void _showFilterSheet() {
    // Store temporary values to avoid constant rebuilds of the underlying map
    double tempRating = _minRating;
    String tempPrice = _selectedPriceRange;
    double tempDistance = _maxDistanceKm;
    bool showError = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            children: [
              // Island Handle
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Filters',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setSheetState(() {
                          tempRating = 0.0;
                          tempPrice = 'All';
                          tempDistance = 20.0;
                        });
                      },
                      child: const Text('Reset All', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    // Rating Filter
                    _buildFilterSection(
                      title: 'Minimum Rating',
                      child: Row(
                        children: [0.0, 3.0, 4.0, 4.5].map((rating) {
                          final isSelected = tempRating == rating;
                          return Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: ChoiceChip(
                              label: Text(rating == 0.0 ? 'All' : '$rating+'),
                              selected: isSelected,
                              onSelected: (val) {
                                setSheetState(() => tempRating = rating);
                              },
                              selectedColor: const Color(0xFF4A90E2).withOpacity(0.2),
                              labelStyle: TextStyle(
                                color: isSelected ? const Color(0xFF4A90E2) : Colors.grey[600],
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Price Filter
                    _buildFilterSection(
                      title: 'Price Range',
                      child: Row(
                        children: ['All', '\$', '\$\$', '\$\$\$'].map((range) {
                          final isSelected = tempPrice == range;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: ChoiceChip(
                                label: Center(child: Text(range)),
                                selected: isSelected,
                                onSelected: (val) {
                                  setSheetState(() => tempPrice = range);
                                },
                                selectedColor: const Color(0xFF4A90E2).withOpacity(0.2),
                                labelStyle: TextStyle(
                                  color: isSelected ? const Color(0xFF4A90E2) : Colors.grey[600],
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Distance Filter
                    _buildFilterSection(
                      title: 'Max Distance (${tempDistance.toInt()} km)',
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: const Color(0xFF4A90E2),
                          thumbColor: const Color(0xFF4A90E2),
                          overlayColor: const Color(0xFF4A90E2).withOpacity(0.2),
                        ),
                        child: Slider(
                          value: tempDistance,
                          min: 1.0,
                          max: 50.0,
                          divisions: 49,
                          onChanged: (val) {
                            setSheetState(() => tempDistance = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Error Message
              if (showError)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'No salons found matching these filters. Try adjusting them!',
                            style: TextStyle(color: Colors.red[700], fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // Apply Button
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      // Validate if any salons match BEFORE closing
                      final potentialSalons = widget.salons.where((salon) {
                        final rating = double.tryParse(salon.rating) ?? 0.0;
                        if (rating < tempRating) return false;
                        
                        if (tempPrice != 'All') {
                          final priceLevel = (salon.salonId.hashCode % 3 == 0) ? '\$\$\$' : (salon.salonId.hashCode % 2 == 0 ? '\$\$' : '\$');
                          if (priceLevel != tempPrice) return false;
                        }
                        
                        final distance = double.tryParse(salon.distance.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
                        if (distance > tempDistance) return false;
                        
                        return true;
                      }).toList();

                      if (potentialSalons.isEmpty) {
                        setSheetState(() => showError = true);
                      } else {
                        setState(() {
                          _minRating = tempRating;
                          _selectedPriceRange = tempPrice;
                          _maxDistanceKm = tempDistance;
                        });
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A90E2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Apply Filters',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}
