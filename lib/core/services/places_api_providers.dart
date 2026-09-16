import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'places_api_service.dart';

final placesApiServiceProvider = Provider<PlacesApiService>((ref) => const PlacesApiService());
