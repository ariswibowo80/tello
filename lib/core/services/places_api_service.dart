import 'dart:convert';

import 'package:http/http.dart' as http;

/// A single Autocomplete suggestion from the Places API.
class PlaceSuggestion {
  const PlaceSuggestion({required this.placeId, required this.description});
  final String placeId;
  final String description;
}

class PlaceDetails {
  const PlaceDetails({
    required this.placeId,
    required this.name,
    this.address,
    this.latitude,
    this.longitude,
  });
  final String placeId;
  final String name;
  final String? address;
  final double? latitude;
  final double? longitude;
}

class PlacesApiException implements Exception {
  const PlacesApiException(this.status);
  final String status;
  @override
  String toString() => 'Places API error: $status';
}

/// Thin wrapper around the Google Places API's (legacy) Autocomplete and
/// Place Details endpoints.
///
/// Requires GOOGLE_MAPS_API_KEY to be supplied at build/run time via
/// --dart-define (see scripts/run_dev.sh and scripts/build_apk.sh) — the
/// Maps SDK key baked into AndroidManifest.xml is NOT readable from Dart,
/// so this reads a separate compile-time constant of the same value.
///
/// Needs "Places API" enabled for this project in Google Cloud Console
/// (the Maps SDK being enabled is not enough on its own), and the API
/// key's restrictions must permit it. Places API also requires a Google
/// Cloud Billing account on the project — separate from Firebase's Blaze
/// plan, since this call goes straight to Google Maps Platform, not
/// through Firebase.
class PlacesApiService {
  const PlacesApiService();

  static const _apiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

  static const _autocompleteUrl = 'https://maps.googleapis.com/maps/api/place/autocomplete/json';
  static const _detailsUrl = 'https://maps.googleapis.com/maps/api/place/details/json';

  bool get isConfigured => _apiKey.isNotEmpty;

  Future<List<PlaceSuggestion>> autocomplete(String input, {String? sessionToken}) async {
    if (!isConfigured || input.trim().isEmpty) return [];
    final uri = Uri.parse(_autocompleteUrl).replace(queryParameters: {
      'input': input,
      'key': _apiKey,
      if (sessionToken != null) 'sessiontoken': sessionToken,
      // Bias toward Indonesia, Tello's primary market, without hard
      // restricting — travelers may search places elsewhere too.
      'components': 'country:id',
    });
    final response = await http.get(uri);
    if (response.statusCode != 200) return [];
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final status = body['status'] as String?;
    if (status != 'OK' && status != 'ZERO_RESULTS') {
      throw PlacesApiException(status ?? 'UNKNOWN_ERROR');
    }
    final predictions = (body['predictions'] as List? ?? const []);
    return predictions
        .map((p) => PlaceSuggestion(
              placeId: p['place_id'] as String? ?? '',
              description: p['description'] as String? ?? '',
            ))
        .where((s) => s.placeId.isNotEmpty)
        .toList();
  }

  Future<PlaceDetails?> details(String placeId, {String? sessionToken}) async {
    if (!isConfigured) return null;
    final uri = Uri.parse(_detailsUrl).replace(queryParameters: {
      'place_id': placeId,
      'fields': 'name,formatted_address,geometry',
      'key': _apiKey,
      if (sessionToken != null) 'sessiontoken': sessionToken,
    });
    final response = await http.get(uri);
    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final status = body['status'] as String?;
    if (status != 'OK') throw PlacesApiException(status ?? 'UNKNOWN_ERROR');
    final result = body['result'] as Map<String, dynamic>?;
    if (result == null) return null;
    final geometry = result['geometry'] as Map<String, dynamic>?;
    final loc = geometry?['location'] as Map<String, dynamic>?;
    return PlaceDetails(
      placeId: placeId,
      name: result['name'] as String? ?? '',
      address: result['formatted_address'] as String?,
      latitude: (loc?['lat'] as num?)?.toDouble(),
      longitude: (loc?['lng'] as num?)?.toDouble(),
    );
  }
}
