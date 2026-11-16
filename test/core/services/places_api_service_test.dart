import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tello/core/services/places_api_service.dart';

void main() {
  group('PlacesApiService (Places API New)', () {
    test('isConfigured is false without a key', () {
      expect(const PlacesApiService(apiKey: '').isConfigured, isFalse);
      expect(const PlacesApiService(apiKey: 'k').isConfigured, isTrue);
    });

    test('autocomplete posts to places:autocomplete and parses suggestions', () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({
            'suggestions': [
              {
                'placePrediction': {
                  'placeId': 'abc',
                  'text': {'text': 'Yogyakarta, Daerah Istimewa Yogyakarta, Indonesia'},
                },
              },
              {
                // query suggestions have no placePrediction and must be skipped
                'queryPrediction': {
                  'text': {'text': 'yogya'},
                },
              },
            ],
          }),
          200,
        );
      });
      final svc = PlacesApiService(client: client, apiKey: 'KEY');

      final results = await svc.autocomplete('yogya', sessionToken: 'tok');

      expect(captured.method, 'POST');
      expect(captured.url.toString(), 'https://places.googleapis.com/v1/places:autocomplete');
      expect(captured.headers['X-Goog-Api-Key'], 'KEY');
      final sent = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(sent['input'], 'yogya');
      expect(sent['sessionToken'], 'tok');
      expect(sent['regionCode'], 'id');
      expect(results, hasLength(1));
      expect(results.single.placeId, 'abc');
      expect(results.single.description, startsWith('Yogyakarta'));
    });

    test('autocomplete returns empty list when there are no matches', () async {
      final svc = PlacesApiService(client: MockClient((_) async => http.Response('{}', 200)), apiKey: 'KEY');
      expect(await svc.autocomplete('zzzz'), isEmpty);
    });

    test('autocomplete surfaces the API error status', () async {
      final svc = PlacesApiService(
        client: MockClient((_) async => http.Response(
              jsonEncode({
                'error': {'code': 403, 'status': 'PERMISSION_DENIED', 'message': 'nope'},
              }),
              403,
            )),
        apiKey: 'KEY',
      );
      expect(
        svc.autocomplete('bali'),
        throwsA(isA<PlacesApiException>().having((e) => e.status, 'status', 'PERMISSION_DENIED')),
      );
    });

    test('details requests the field mask and parses the place', () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({
            'displayName': {'text': 'Candi Prambanan', 'languageCode': 'id'},
            'formattedAddress': 'Jl. Raya Solo - Yogyakarta No.16, Sleman',
            'location': {'latitude': -7.752, 'longitude': 110.4914},
          }),
          200,
        );
      });
      final svc = PlacesApiService(client: client, apiKey: 'KEY');

      final d = await svc.details('abc', sessionToken: 'tok');

      expect(captured.method, 'GET');
      expect(captured.url.path, '/v1/places/abc');
      expect(captured.url.queryParameters['sessionToken'], 'tok');
      expect(captured.headers['X-Goog-Api-Key'], 'KEY');
      expect(captured.headers['X-Goog-FieldMask'], 'displayName,formattedAddress,location');
      expect(d, isNotNull);
      expect(d!.placeId, 'abc');
      expect(d.name, 'Candi Prambanan');
      expect(d.address, contains('Sleman'));
      expect(d.latitude, closeTo(-7.752, 1e-6));
      expect(d.longitude, closeTo(110.4914, 1e-6));
    });

    test('details returns null for an unknown place (404)', () async {
      final svc = PlacesApiService(client: MockClient((_) async => http.Response('{}', 404)), apiKey: 'KEY');
      expect(await svc.details('missing'), isNull);
    });
  });
}
