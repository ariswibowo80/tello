import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/storage_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/location_picker_sheet.dart';
import '../../../../core/widgets/media_grid.dart';
import '../../../../core/widgets/tag_input.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../people/domain/entities/person.dart';
import '../../../people/presentation/providers/person_providers.dart';
import '../../../people/presentation/widgets/people_picker_sheet.dart';
import '../../../people/presentation/widgets/person_avatar.dart';
import '../../../household/presentation/providers/household_providers.dart';
import '../../domain/entities/moment.dart';
import '../providers/moment_providers.dart';

class _PickedMedia {
  _PickedMedia.uploading({required this.id, required File file, required this.type})
      : file = file,
        progress = 0,
        uploaded = null,
        error = null;

  _PickedMedia.existing(MediaItem item)
      : id = item.storagePath,
        file = null,
        type = item.type,
        progress = null,
        uploaded = item,
        error = null;

  final String id;
  final File? file;
  final MediaType type;
  double? progress;
  MediaItem? uploaded;
  String? error;
}

class AddMomentScreen extends ConsumerStatefulWidget {
  const AddMomentScreen({super.key, this.existingMoment});

  /// When non-null, the screen operates in edit mode: fields are prefilled
  /// from this Moment and Save calls `updateMoment` instead of `createMoment`.
  final Moment? existingMoment;

  @override
  ConsumerState<AddMomentScreen> createState() => _AddMomentScreenState();
}

class _AddMomentScreenState extends ConsumerState<AddMomentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _storyController = TextEditingController();

  late final String _momentId;
  late final String _folderPath;

  DateTime? _startDate;
  DateTime? _endDate;
  GeoLocation? _location;
  List<Person> _selectedPeople = [];
  final List<_PickedMedia> _media = [];
  Set<String> _tags = {};

  String? _dateErrorText;
  bool _isSubmitting = false;
  bool _peopleInitialized = false;

  bool get _isEditing => widget.existingMoment != null;

  @override
  void initState() {
    super.initState();
    // Media for a Moment lives under its household
    // (households/{id}/moments/...), not the current user - all household
    // members share the same storage folder. See storage.rules:
    // isHouseholdMember(householdId).
    final householdId = ref.read(householdIdProvider).valueOrNull!;
    final existing = widget.existingMoment;

    if (existing != null) {
      _momentId = existing.id;
      _titleController.text = existing.title;
      _storyController.text = existing.description ?? '';
      _startDate = existing.startDate;
      _endDate = existing.endDate;
      _location = existing.location;
      _tags = existing.tags.toSet();
      for (final item in existing.media) {
        _media.add(_PickedMedia.existing(item));
      }
      _peopleInitialized = existing.peopleIds.isEmpty;
    } else {
      _momentId = ref.read(momentRepositoryProvider).newMomentId();
    }
    _folderPath = StoragePaths.momentMedia(householdId, _momentId);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _storyController.dispose();
    super.dispose();
  }

  bool get _isUploadingMedia => _media.any((m) => m.uploaded == null && m.error == null);
  bool get _hasMediaErrors => _media.any((m) => m.error != null);
  bool get _canAddMoreMedia => _media.length < AppLimits.maxMediaPerMoment;

  void _startUpload(File file, MediaType type) {
    final entry = _PickedMedia.uploading(id: const Uuid().v4(), file: file, type: type);
    setState(() => _media.add(entry));

    final storage = ref.read(storageServiceProvider);
    final task = type == MediaType.image
        ? storage.uploadImage(file: file, folderPath: _folderPath)
        : storage.uploadVideo(file: file, folderPath: _folderPath);

    task.progress.listen((p) {
      if (!mounted) return;
      setState(() => entry.progress = p);
    });

    task.result.then((item) {
      if (!mounted) return;
      setState(() {
        entry.progress = 1;
        entry.uploaded = item;
      });
    }).catchError((Object e) {
      if (!mounted) return;
      setState(() => entry.error = e is AppException ? e.message : 'Upload failed. Please try again.');
    });
  }

  Future<void> _pickPhotos() async {
    if (!_canAddMoreMedia) return;
    final remaining = AppLimits.maxMediaPerMoment - _media.length;
    final picked = await ImagePicker().pickMultiImage(limit: remaining);
    for (final xfile in picked) {
      _startUpload(File(xfile.path), MediaType.image);
    }
  }

  Future<void> _pickVideo() async {
    if (!_canAddMoreMedia) return;
    final xfile = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (xfile != null) _startUpload(File(xfile.path), MediaType.video);
  }

  void _removeMedia(_PickedMedia entry) {
    setState(() => _media.remove(entry));
    final path = entry.uploaded?.storagePath;
    if (path != null) {
      // Best-effort cleanup; the moment was never saved so nothing else
      // references this file.
      ref.read(storageServiceProvider).deleteMedia(path);
    }
  }

  void _showAddMediaSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
              title: const Text('Photos'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickPhotos();
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam_rounded, color: AppColors.primary),
              title: const Text('Video'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickVideo();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked == null) return;
    setState(() {
      _startDate = picked;
      _dateErrorText = null;
      if (_endDate != null && _endDate!.isBefore(_startDate!)) _endDate = null;
    });
  }

  Future<void> _pickEndDate() async {
    if (_startDate == null) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate!,
      firstDate: _startDate!,
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  Future<void> _pickLocation() async {
    final result = await showLocationPickerSheet(context);
    if (result != null) setState(() => _location = result);
  }

  Future<void> _pickPeople() async {
    final result = await showPeoplePickerSheet(context, initiallySelected: _selectedPeople);
    if (result != null) setState(() => _selectedPeople = result);
  }

  /// In edit mode we only have `peopleIds` from the Moment, not full
  /// [Person] objects. This resolves them against the live People list the
  /// first time it has data, then stops watching (via [_peopleInitialized])
  /// so it never overwrites choices the person makes afterward.
  void _maybeResolveExistingPeople() {
    if (_peopleInitialized) return;
    final existingIds = widget.existingMoment!.peopleIds.toSet();
    final people = ref.watch(peopleListProvider).valueOrNull;
    if (people == null) return;
    final matched = people.where((p) => existingIds.contains(p.id)).toList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _peopleInitialized) return;
      setState(() {
        _selectedPeople = matched;
        _peopleInitialized = true;
      });
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null) {
      setState(() => _dateErrorText = 'Please choose a date.');
      return;
    }
    if (_isUploadingMedia) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please wait for photos to finish uploading.')));
      return;
    }
    if (_hasMediaErrors) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Remove the photo/video that failed to upload, then try again.")));
      return;
    }
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final now = DateTime.now();
    final storyText = _storyController.text.trim();
    final existing = widget.existingMoment;
    final moment = Moment(
      id: _momentId,
      title: _titleController.text.trim(),
      description: storyText.isEmpty ? null : storyText,
      startDate: _startDate!,
      endDate: _endDate,
      location: _location,
      peopleIds: _selectedPeople.map((p) => p.id).toList(),
      media: _media.map((m) => m.uploaded!).toList(),
      tags: _tags.toList(),
      notes: existing?.notes,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      sourcePlanId: existing?.sourcePlanId,
    );

    try {
      final repo = ref.read(momentRepositoryProvider);
      if (_isEditing) {
        await repo.updateMoment(moment);
      } else {
        await repo.createMoment(moment);
      }
      if (mounted) context.pop(true);
    } on AppException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) _maybeResolveExistingPeople();
    final isBusy = _isSubmitting || _isUploadingMedia;

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Moment' : 'Add Moment')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionLabel('What happened?'),
                TextFormField(
                  controller: _titleController,
                  maxLength: AppLimits.maxTitleLength,
                  decoration: const InputDecoration(hintText: 'e.g. Liburan ke Jogja'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Tell us what happened.' : null,
                ),
                const SizedBox(height: 12),
                const _SectionLabel('When?'),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickStartDate,
                        icon: const Icon(Icons.calendar_today_rounded, size: 16),
                        label: Text(_startDate == null
                            ? 'Choose date'
                            : _endDate == null
                                ? _startDate!.rangeLabelShort
                                : '${_startDate!.rangeLabelShort} – ${_endDate!.rangeLabelShort}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_startDate != null)
                      TextButton(
                        onPressed: _pickEndDate,
                        child: Text(_endDate == null ? '+ End date' : 'Change end'),
                      ),
                  ],
                ),
                if (_dateErrorText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(_dateErrorText!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
                  ),
                const SizedBox(height: 12),
                const _SectionLabel('Where?'),
                OutlinedButton.icon(
                  onPressed: _pickLocation,
                  icon: const Icon(Icons.place_rounded, size: 16, color: AppColors.placeAccent),
                  label: Text(_location?.name ?? 'Add a location'),
                ),
                const SizedBox(height: 12),
                const _SectionLabel('Who was there?'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final person in _selectedPeople)
                      Tooltip(message: person.name, child: PersonAvatar(person: person, size: 44)),
                    Material(
                      color: AppColors.primaryLight,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _pickPeople,
                        child: const Padding(
                          padding: EdgeInsets.all(10),
                          child: Icon(Icons.person_add_alt_1_rounded, color: AppColors.primary, size: 24),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const _SectionLabel('Photos / Videos'),
                MediaGrid(
                  canAddMore: _canAddMoreMedia,
                  onAddTap: _showAddMediaSheet,
                  items: [
                    for (final m in _media)
                      MediaGridItem(
                        id: m.id,
                        localFile: m.file,
                        networkUrl: m.file == null ? (m.uploaded?.thumbnailUrl ?? m.uploaded?.url) : null,
                        isVideo: m.type == MediaType.video,
                        progress: m.progress,
                        error: m.error,
                        onRemove: () => _removeMedia(m),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const _SectionLabel('Your Story'),
                TextFormField(
                  controller: _storyController,
                  maxLength: AppLimits.maxStoryLength,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    hintText: 'Liburan keluarga pertama setelah sekian lama...',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 4),
                const _SectionLabel('Tags'),
                TagInput(selectedTags: _tags, onChanged: (t) => setState(() => _tags = t)),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isBusy ? null : _save,
                    child: isBusy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(_isEditing ? 'Save Changes' : 'Save Moment'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 4),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

extension _ShortDateLabel on DateTime {
  String get rangeLabelShort {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '$day ${months[month - 1]} $year';
  }
}
