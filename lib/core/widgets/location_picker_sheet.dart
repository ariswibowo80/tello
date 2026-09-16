import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import '../../features/moments/domain/entities/moment.dart' show GeoLocation;
import '../services/places_api_providers.dart';
import '../services/places_api_service.dart';
import '../theme/app_colors.dart';

/// Shows a sheet for picking a place. Returns the chosen [GeoLocation], or
/// null if dismissed. Used by Add Moment ("Where?"), Create Plan, and
/// itinerary items.
///
/// Search is backed by the Google Places Autocomplete + Details API when
/// GOOGLE_MAPS_API_KEY is configured (see scripts/run_dev.sh);
/// "Use current location" always works via device GPS + reverse
/// geocoding regardless.
Future<GeoLocation?> showLocationPickerSheet(BuildContext context) {
  return showModalBottomSheet<GeoLocation>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _LocationPickerSheet(),
  );
}

class _LocationPickerSheet extends ConsumerStatefulWidget {
  const _LocationPickerSheet();

  @override
  ConsumerState<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends ConsumerState<_LocationPickerSheet> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String? _sessionToken;

  bool _isSearching = false;
  bool _isLocating = false;
  bool _isFetchingDetails = false;
  String? _errorMessage;
  List<PlaceSuggestion> _suggestions = [];

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    // New session token per "search session" (first keystroke through
    // selection) - this is what lets Autocomplete + Details be billed
    // together as one session instead of per request.
    _sessionToken ??= const Uuid().v4();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<void> _search(String query) async {
    final places = ref.read(placesApiServiceProvider);
    if (!places.isConfigured) {
      setState(() => _errorMessage = "Place search isn't set up on this build yet.");
      return;
    }
    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });
    try {
      final results = await places.autocomplete(query, sessionToken: _sessionToken);
      if (!mounted) return;
      setState(() => _suggestions = results);
    } on PlacesApiException {
      if (mounted) setState(() => _errorMessage = "Couldn't search right now. Try again.");
    } catch (_) {
      if (mounted) setState(() => _errorMessage = "Couldn't search right now. Check your connection.");
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _selectSuggestion(PlaceSuggestion suggestion) async {
    setState(() {
      _isFetchingDetails = true;
      _errorMessage = null;
    });
    try {
      final places = ref.read(placesApiServiceProvider);
      final details = await places.details(suggestion.placeId, sessionToken: _sessionToken);
      _sessionToken = null; // session ends once details is fetched
      if (!mounted) return;
      if (details == null) {
        setState(() => _errorMessage = "Couldn't load that place. Try another.");
        return;
      }
      Navigator.of(context).pop(GeoLocation(
        name: details.name.isNotEmpty ? details.name : suggestion.description,
        address: details.address,
        latitude: details.latitude,
        longitude: details.longitude,
        placeId: details.placeId,
      ));
    } catch (_) {
      if (mounted) setState(() => _errorMessage = "Couldn't load that place. Try again.");
    } finally {
      if (mounted) setState(() => _isFetchingDetails = false);
    }
  }

  Future<({String name, String? address})?> _reverseGeocode(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return null;
      final p = placemarks.first;
      final name = p.locality?.isNotEmpty == true
          ? p.locality!
          : (p.subAdministrativeArea?.isNotEmpty == true ? p.subAdministrativeArea! : (p.name ?? ''));
      final address = [p.street, p.locality, p.administrativeArea, p.country]
          .where((s) => s != null && s.isNotEmpty)
          .join(', ');
      return (name: name.isNotEmpty ? name : 'Unnamed location', address: address);
    } catch (_) {
      return null;
    }
  }

  Future<void> _useCurrentLocation() async {
    if (_isLocating) return;
    setState(() {
      _isLocating = true;
      _errorMessage = null;
    });
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        setState(() => _errorMessage = 'Location permission is off. Enable it in Settings to use this.');
        return;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _errorMessage = 'Turn on location services to use this.');
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      final label = await _reverseGeocode(position.latitude, position.longitude);
      if (!mounted) return;
      Navigator.of(context).pop(GeoLocation(
        name: label?.name ?? 'Current location',
        address: label?.address,
        latitude: position.latitude,
        longitude: position.longitude,
      ));
    } catch (_) {
      setState(() => _errorMessage = "Couldn't get your current location. Please try again.");
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _isFetchingDetails || _isLocating;
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Where?', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Search a place on Google Maps',
                      suffixIcon: _isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : null,
                    ),
                    onChanged: _onQueryChanged,
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: isBusy ? null : _useCurrentLocation,
                    icon: _isLocating
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                          )
                        : const Icon(Icons.my_location_rounded, size: 18),
                    label: const Text('Use current location'),
                  ),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      child: Text(_errorMessage!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                    ),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: _suggestions.length,
                      itemBuilder: (context, i) {
                        final suggestion = _suggestions[i];
                        return ListTile(
                          leading: const Icon(Icons.place_rounded, color: AppColors.placeAccent),
                          title: Text(suggestion.description),
                          enabled: !isBusy,
                          onTap: () => _selectSuggestion(suggestion),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
