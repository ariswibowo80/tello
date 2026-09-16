import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../moments/presentation/widgets/moment_card.dart';
import '../../../plans/presentation/widgets/plan_card.dart';
import '../../domain/entities/place_summary.dart';

class PlaceDetailScreen extends StatelessWidget {
  const PlaceDetailScreen({super.key, required this.place});

  final PlaceSummary place;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(place.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          if (place.address != null && place.address!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(place.address!, style: const TextStyle(color: AppColors.textSecondary)),
            ),
          if (place.hasCoordinates)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 160,
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(place.latitude!, place.longitude!),
                      zoom: 12,
                    ),
                    markers: {
                      Marker(
                        markerId: const MarkerId('place'),
                        position: LatLng(place.latitude!, place.longitude!),
                        infoWindow: InfoWindow(title: place.name),
                      ),
                    },
                    zoomControlsEnabled: false,
                    scrollGesturesEnabled: false,
                  ),
                ),
              ),
            ),
          if (place.moments.isNotEmpty) ...[
            Text('Moments here', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            for (final moment in place.moments)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: MomentCard(moment: moment, onTap: () => context.push('/moment/${moment.id}')),
              ),
            const SizedBox(height: 8),
          ],
          if (place.plans.isNotEmpty) ...[
            Text('Plans here', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            for (final plan in place.plans)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: PlanCard(plan: plan, onTap: () => context.push('/plan/${plan.id}')),
              ),
          ],
          if (place.moments.isEmpty && place.plans.isEmpty)
            const EmptyState(
              icon: Icons.place_outlined,
              title: 'Nothing here yet',
              message: 'Moments and Plans at this place will show up here.',
            ),
        ],
      ),
    );
  }
}
