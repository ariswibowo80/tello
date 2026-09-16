import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../domain/entities/place_summary.dart';
import '../providers/places_providers.dart';
import '../widgets/place_card.dart';
import 'place_detail_screen.dart';

class PlacesScreen extends StatelessWidget {
  const PlacesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Places'),
          bottom: const TabBar(
            tabs: [Tab(text: 'Visited'), Tab(text: 'Planned')],
          ),
        ),
        body: const TabBarView(
          children: [
            _PlacesTab(kind: _PlacesTabKind.visited),
            _PlacesTab(kind: _PlacesTabKind.planned),
          ],
        ),
      ),
    );
  }
}

enum _PlacesTabKind { visited, planned }

class _PlacesTab extends ConsumerWidget {
  const _PlacesTab({required this.kind});
  final _PlacesTabKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providerToUse = kind == _PlacesTabKind.visited ? visitedPlacesProvider : plannedPlacesProvider;
    final placesAsync = ref.watch(providerToUse);

    return placesAsync.when(
      loading: () => const LoadingState(),
      error: (e, _) => ErrorState(
        message: e is AppException ? e.message : 'Something went wrong. Please try again.',
        onRetry: () => ref.invalidate(providerToUse),
      ),
      data: (places) {
        if (places.isEmpty) {
          return kind == _PlacesTabKind.visited
              ? const EmptyState(
                  icon: Icons.map_outlined,
                  title: 'No places visited yet',
                  message: 'Moments with a location will show up here.',
                )
              : const EmptyState(
                  icon: Icons.flight_takeoff_rounded,
                  title: 'Nowhere new planned yet',
                  message: "Plans with a location you haven't visited before will show up here.",
                );
        }

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async => ref.invalidate(providerToUse),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _PlacesMapPreview(places: places),
              if (places.any((p) => p.hasCoordinates)) const SizedBox(height: 16),
              for (final place in places)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: PlaceCard(
                    place: place,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => PlaceDetailScreen(place: place)),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PlacesMapPreview extends StatelessWidget {
  const _PlacesMapPreview({required this.places});
  final List<PlaceSummary> places;

  @override
  Widget build(BuildContext context) {
    final withCoords = places.where((p) => p.hasCoordinates).toList();
    if (withCoords.isEmpty) return const SizedBox.shrink();

    final markers = {
      for (final p in withCoords)
        Marker(
          markerId: MarkerId(p.name),
          position: LatLng(p.latitude!, p.longitude!),
          infoWindow: InfoWindow(title: p.name),
        ),
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 160,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: markers.first.position, zoom: 3),
          markers: markers,
          zoomControlsEnabled: false,
        ),
      ),
    );
  }
}
