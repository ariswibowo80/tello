import 'dart:convert';

import 'package:http/http.dart' as http;

/// A single Autocomplete suggestion from the Places API (New).
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

/// Thin wrapper around the Google Places API (New) Autocomplete and Place
/// Details endpoints (`places.googleapis.com/v1`).
///
/// The legacy Places API can no longer be enabled on new Google Cloud
/// projects, so this uses the "New" API instead. The public surface
/// (autocomplete / details / PlacesApiException) is unchanged.
///
/// Requires GOOGLE_MAPS_API_KEY to be supplied at build/run time via
/// --dart-define (see scripts/run_dev.sh and scripts/build_apk.sh) — the
/// Maps SDK key baked into AndroidManifest.xml is NOT readable from Dart,
/// so this reads a separate compile-time constant of the same value.
///
/// Needs "Places API (New)" enabled for this project in Google Cloud
/// Console (the Maps SDK being enabled is not enough on its own), and the
/// API key's restrictions must permit it: an "Android apps" application
/// restriction will reject these plain HTTP calls, so use no application
/// restriction (or a server-style one) and restrict the key to the APIs
/// instead. Places API also requires a Google Cloud Billing account on the
/// project — separate from Firebase's Blaze plan, since this call goes
/// straight to Google Maps Platform, not through Firebase.
class PlacesApiService {
  const PlacesApiService({http.Client? client, String? apiKey})
      : _client = client,
        _apiKeyOverride = apiKey;

  final http.Client? _client;
  final String? _apiKeyOverride;

  static const _envApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

  static const _autocompleteUrl = 'https://places.googleapis.com/v1/places:autocomplete';
  static const _detailsBaseUrl = 'https://places.googleapis.com/v1/places';

  String get _apiKey => _apiKeyOverride ?? _envApiKey;

  bool get isConfigured => _apiKey.isNotEmpty;

  Future<http.Response> _post(Uri uri, Map<String, String> headers, String body) {
    final c = _client;
    return c != null ? c.post(uri, headers: headers, body: body) : http.post(uri, headers: headers, body: body);
  }

  Future<http.Response> _get(Uri uri, Map<String, String> headers) {
    final c = _client;
    return c != null ? c.get(uri, headers: headers) : http.get(uri, headers: headers);
  }

  /// Error body shape: {"error": {"code": 403, "status": "PERMISSION_DENIED", ...}}
  PlacesApiException _errorFrom(http.Response response) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final status = (body['error'] as Map<String, dynamic>?)?['status'] as String?;
      if (status != null && status.isNotEmpty) return PlacesApiException(status);
    } catch (_) {
      // fall through to the HTTP status code
    }
    return PlacesApiException('HTTP_${response.statusCode}');
  }

  Future<List<PlaceSuggestion>> autocomplete(String input, {String? sessionToken}) async {
    if (!isConfigured || input.trim().isEmpty) return [];
    final response = await _post(
      Uri.parse(_autocompleteUrl),
      {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': _apiKey,
      },
      jsonEncode({
        'input': input,
        if (sessionToken != null) 'sessionToken': sessionToken,
        // Bias toward Indonesia, Tello's primary market, without hard
        // restricting — travelers may search places elsewhere too.
        // (regionCode influences ranking; includedRegionCodes would restrict.)
        'regionCode': 'id',
      }),
    );
    if (response.statusCode != 200) throw _errorFrom(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    // No matches => {} (no "suggestions" key).
    final suggestions = (body['suggestions'] as List? ?? const []);
    return suggestions
        .map((s) {
          final p = (s as Map<String, dynamic>)['placePrediction'] as Map<String, dynamic>?;
          return PlaceSuggestion(
            placeId: p?['placeId'] as String? ?? '',
            description: (p?['text'] as Map<String, dynamic>?)?['text'] as String? ?? '',
          );
        })
        .where((s) => s.placeId.isNotEmpty)
        .toList();
  }

  Future<PlaceDetails?> details(String placeId, {String? sessionToken}) async {
    if (!isConfigured) return null;
    final uri = Uri.parse('$_detailsBaseUrl/${Uri.encodeComponent(placeId)}').replace(queryParameters: {
      if (sessionToken != null) 'sessionToken': sessionToken,
    });
    final response = await _get(uri, {
      'X-Goog-Api-Key': _apiKey,
      'X-Goog-FieldMask': 'displayName,formattedAddress,location',
    });
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) throw _errorFrom(response);
    final result = jsonDecode(response.body) as Map<String, dynamic>;
    final loc = result['location'] as Map<String, dynamic>?;
    return PlaceDetails(
      placeId: placeId,
      name: (result['displayName'] as Map<String, dynamic>?)?['text'] as String? ?? '',
      address: result['formattedAddress'] as String?,
      latitude: (loc?['latitude'] as num?)?.toDouble(),
      longitude: (loc?['longitude'] as num?)?.toDouble(),
    );
  }
}
