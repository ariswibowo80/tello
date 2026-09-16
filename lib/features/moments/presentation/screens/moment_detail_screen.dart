import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/extensions/date_extensions.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/storage_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/location_chip.dart';
import '../../../../core/widgets/tag_chip.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../people/domain/entities/person.dart';
import '../../../people/presentation/widgets/person_avatar.dart';
import '../../../timeline/presentation/providers/moments_timeline_controller.dart';
import '../../../household/presentation/providers/household_providers.dart';
import '../../domain/entities/moment.dart';
import '../providers/moment_detail_providers.dart';
import '../providers/moment_providers.dart';
import '../widgets/photo_viewer.dart';

class MomentDetailScreen extends ConsumerStatefulWidget {
  const MomentDetailScreen({super.key, required this.momentId});

  final String momentId;

  @override
  ConsumerState<MomentDetailScreen> createState() => _MomentDetailScreenState();
}

class _MomentDetailScreenState extends ConsumerState<MomentDetailScreen> {
  bool _isDeleting = false;
  bool _isAddingPhoto = false;

  Future<void> _addPhoto(Moment moment) async {
    if (_isAddingPhoto) return;
    final xfile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (xfile == null) return;

    setState(() => _isAddingPhoto = true);
    try {
      final householdId = ref.read(householdIdProvider).valueOrNull!;
      final storage = ref.read(storageServiceProvider);
      final folderPath = StoragePaths.momentMedia(householdId, moment.id);
      final task = storage.uploadImage(file: File(xfile.path), folderPath: folderPath);
      final item = await task.result;
      final updated = moment.copyWith(media: [...moment.media, item]);
      await ref.read(momentRepositoryProvider).updateMoment(updated);
    } on AppException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isAddingPhoto = false);
    }
  }

  Future<void> _share(Moment moment) async {
    final parts = <String>[
      moment.title,
      moment.startDate.rangeLabel(moment.endDate),
      if (moment.location != null) moment.location!.name,
      if (moment.description != null && moment.description!.isNotEmpty) moment.description!,
    ];
    await Share.share(parts.join('\n'));
  }

  Future<void> _confirmDelete(Moment moment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this moment?'),
        content: const Text("This will permanently remove the moment and its photos. This can't be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || _isDeleting) return;

    setState(() => _isDeleting = true);
    try {
      final storage = ref.read(storageServiceProvider);
      for (final media in moment.media) {
        await storage.deleteMedia(media.storagePath);
        if (media.thumbnailStoragePath != null) {
          await storage.deleteMedia(media.thumbnailStoragePath!);
        }
      }
      await ref.read(momentRepositoryProvider).deleteMoment(moment.id);
      ref.invalidate(momentsTimelineProvider);
      if (mounted) context.pop();
    } on AppException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final momentAsync = ref.watch(momentDetailProvider(widget.momentId));

    return momentAsync.when(
      loading: () => Scaffold(appBar: AppBar(), body: const LoadingState()),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorState(
          message: e is AppException ? e.message : 'Something went wrong. Please try again.',
          onRetry: () => ref.invalidate(momentDetailProvider(widget.momentId)),
        ),
      ),
      data: (moment) {
        if (moment == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
              icon: Icons.auto_awesome_rounded,
              title: 'This moment is gone',
              message: 'It may have already been deleted.',
            ),
          );
        }
        return _MomentDetailContent(
          moment: moment,
          isDeleting: _isDeleting,
          isAddingPhoto: _isAddingPhoto,
          onEdit: () => context.push(AppRoutes.editMoment, extra: moment),
          onAddPhoto: () => _addPhoto(moment),
          onShare: () => _share(moment),
          onDelete: () => _confirmDelete(moment),
        );
      },
    );
  }
}

class _MomentDetailContent extends ConsumerWidget {
  const _MomentDetailContent({
    required this.moment,
    required this.isDeleting,
    required this.isAddingPhoto,
    required this.onEdit,
    required this.onAddPhoto,
    required this.onShare,
    required this.onDelete,
  });

  final Moment moment;
  final bool isDeleting;
  final bool isAddingPhoto;
  final VoidCallback onEdit;
  final VoidCallback onAddPhoto;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final people = ref.watch(momentPeopleProvider(moment));
    final heroImages = moment.media.where((m) => m.type == MediaType.image).toList();

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            moment.location?.name ?? moment.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            IconButton(
              tooltip: 'Add Photo',
              icon: isAddingPhoto
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_photo_alternate_rounded),
              onPressed: isAddingPhoto ? null : onAddPhoto,
            ),
            IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit_rounded), onPressed: onEdit),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'share') onShare();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'share', child: Text('Share')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Story'),
              Tab(text: 'Photos'),
              Tab(text: 'Map'),
              Tab(text: 'Notes'),
            ],
          ),
        ),
        body: Stack(
          children: [
            Column(
              children: [
                if (heroImages.isNotEmpty) _HeroCarousel(images: heroImages),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(moment.title, style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 4),
                      Text(
                        moment.startDate.rangeLabel(moment.endDate),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                      ),
                      if (moment.location != null) ...[
                        const SizedBox(height: 4),
                        LocationChip(name: moment.location!.address ?? moment.location!.name),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _StoryTab(moment: moment, people: people),
                      _PhotosTab(media: moment.media),
                      _MapTab(location: moment.location),
                      _NotesTab(moment: moment),
                    ],
                  ),
                ),
              ],
            ),
            if (isDeleting)
              Positioned.fill(
                child: Container(
                  color: Colors.black26,
                  child: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HeroCarousel extends StatelessWidget {
  const _HeroCarousel({required this.images});
  final List<MediaItem> images;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      width: double.infinity,
      child: PageView.builder(
        itemCount: images.length,
        itemBuilder: (context, i) {
          final item = images[i];
          return GestureDetector(
            onTap: () => showPhotoViewer(context, media: images, initialIndex: i),
            child: Hero(
              tag: 'moment-media-${item.storagePath}',
              child: CachedNetworkImage(imageUrl: item.url, fit: BoxFit.cover, width: double.infinity),
            ),
          );
        },
      ),
    );
  }
}

class _StoryTab extends StatelessWidget {
  const _StoryTab({required this.moment, required this.people});
  final Moment moment;
  final List<Person> people;

  @override
  Widget build(BuildContext context) {
    final hasStory = moment.description != null && moment.description!.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          hasStory ? moment.description! : 'No story written yet.',
          style: hasStory
              ? Theme.of(context).textTheme.bodyLarge
              : Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary, fontStyle: FontStyle.italic),
        ),
        if (people.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Who was there', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              for (final p in people)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PersonAvatar(person: p, size: 48),
                    const SizedBox(height: 4),
                    Text(p.name, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
            ],
          ),
        ],
        if (moment.tags.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Tags', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final t in moment.tags) TagChip(label: '#$t')],
          ),
        ],
      ],
    );
  }
}

class _PhotosTab extends StatelessWidget {
  const _PhotosTab({required this.media});
  final List<MediaItem> media;

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) {
      return const EmptyState(
        icon: Icons.photo_library_outlined,
        title: 'No photos yet',
        message: 'Add photos from the icon at the top of this screen.',
      );
    }

    final images = media.where((m) => m.type == MediaType.image).toList();

    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: media.length,
      itemBuilder: (context, i) {
        final item = media[i];
        final imageIndex = item.type == MediaType.image ? images.indexOf(item) : -1;
        return GestureDetector(
          onTap: imageIndex >= 0 ? () => showPhotoViewer(context, media: images, initialIndex: imageIndex) : null,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(imageUrl: item.thumbnailUrl ?? item.url, fit: BoxFit.cover),
                if (item.type == MediaType.video)
                  const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 28)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MapTab extends StatelessWidget {
  const _MapTab({required this.location});
  final GeoLocation? location;

  @override
  Widget build(BuildContext context) {
    if (location == null || location!.latitude == null || location!.longitude == null) {
      return const EmptyState(
        icon: Icons.map_outlined,
        title: 'No location added',
        message: 'Edit this moment to add a place.',
      );
    }

    final position = LatLng(location!.latitude!, location!.longitude!);
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: position, zoom: 14),
      markers: {
        Marker(
          markerId: const MarkerId('moment-location'),
          position: position,
          infoWindow: InfoWindow(title: location!.name),
        ),
      },
    );
  }
}

class _NotesTab extends ConsumerStatefulWidget {
  const _NotesTab({required this.moment});
  final Moment moment;

  @override
  ConsumerState<_NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends ConsumerState<_NotesTab> {
  late final TextEditingController _controller = TextEditingController(text: widget.moment.notes ?? '');
  bool _isSaving = false;
  bool _isDirty = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final trimmed = _controller.text.trim();
      final updated = widget.moment.copyWith(notes: trimmed.isEmpty ? null : trimmed, clearNotes: trimmed.isEmpty);
      await ref.read(momentRepositoryProvider).updateMoment(updated);
      if (mounted) setState(() => _isDirty = false);
    } on AppException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              maxLines: null,
              expands: true,
              maxLength: AppLimits.maxNoteLength,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                hintText: 'Add a private note about this moment...',
                alignLabelWithHint: true,
              ),
              onChanged: (_) => setState(() => _isDirty = true),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: (_isDirty && !_isSaving) ? _save : null,
              child: _isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save Notes'),
            ),
          ),
        ],
      ),
    );
  }
}
