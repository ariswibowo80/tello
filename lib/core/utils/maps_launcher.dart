import 'package:url_launcher/url_launcher.dart';

import '../../features/moments/domain/entities/moment.dart' show GeoLocation;

/// Builds a Google Maps URL for a [GeoLocation]. This "universal link"
/// format opens in the Google Maps app if installed, or a browser
/// otherwise — the same URL works for both.
String googleMapsUrlFor(GeoLocation location) {
  final query = Uri.encodeComponent(
    location.latitude != null && location.longitude != null
        ? '${location.latitude},${location.longitude}'
        : '${location.name}${location.address != null ? ', ${location.address}' : ''}',
  );
  final placeIdParam = location.placeId != null ? '&query_place_id=${location.placeId}' : '';
  return 'https://www.google.com/maps/search/?api=1&query=$query$placeIdParam';
}

/// Opens [location] in the Google Maps app (falls back to the browser if
/// the app isn't installed). Returns false if the URL couldn't be
/// launched — callers should show their own error UI in that case, since
/// this function has no BuildContext of its own.
Future<bool> openInGoogleMaps(GeoLocation location) {
  final uri = Uri.parse(googleMapsUrlFor(location));
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Opens an arbitrary external link (e.g. an inspiration link) in the
/// browser or a linked app. Returns false if the URL was invalid or
/// couldn't be launched.
Future<bool> openExternalLink(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
