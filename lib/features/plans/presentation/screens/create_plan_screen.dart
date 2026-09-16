import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/extensions/date_extensions.dart';
import '../../../../core/services/storage_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/location_picker_sheet.dart';
import '../../../../core/widgets/media_grid.dart';
import '../../../../core/widgets/tag_chip.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../moments/domain/entities/moment.dart' show GeoLocation, MediaItem, MediaType;
import '../../../people/domain/entities/person.dart';
import '../../../people/presentation/providers/person_providers.dart';
import '../../../people/presentation/widgets/people_picker_sheet.dart';
import '../../../people/presentation/widgets/person_avatar.dart';
import '../../../household/presentation/providers/household_providers.dart';
import '../../domain/entities/plan.dart';
import '../providers/plan_providers.dart';
import '../widgets/itinerary_item_sheet.dart';
import '../widgets/plan_category_display.dart';

class _PickedMedia {
  _PickedMedia.uploading({required this.id, required File file})
      : file = file,
        progress = 0,
        uploaded = null,
        error = null;

  _PickedMedia.existing(MediaItem item)
      : id = item.storagePath,
        file = null,
        progress = null,
        uploaded = item,
        error = null;

  final String id;
  final File? file;
  double? progress;
  MediaItem? uploaded;
  String? error;
}

class CreatePlanScreen extends ConsumerStatefulWidget {
  const CreatePlanScreen({super.key, this.existingPlan});

  /// When non-null, the screen operates in edit mode: fields are prefilled
  /// from this Plan and Save calls `updatePlan` instead of `createPlan`.
  final Plan? existingPlan;

  @override
  ConsumerState<CreatePlanScreen> createState() => _CreatePlanScreenState();
}

class _CreatePlanScreenState extends ConsumerState<CreatePlanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _estimatedBudgetController = TextEditingController();
  final _currencyController = TextEditingController(text: 'IDR');
  final _checklistInputController = TextEditingController();
  final _linkInputController = TextEditingController();

  late final String _planId;
  late final String _folderPath;

  DateTime? _startDate;
  DateTime? _endDate;
  PlanCategory? _category;
  GeoLocation? _location;
  List<Person> _selectedPeople = [];
  final List<ChecklistItem> _checklist = [];
  final List<ItineraryItem> _itinerary = [];
  final List<_PickedMedia> _media = [];
  final List<String> _links = [];

  String? _dateErrorText;
  String? _categoryErrorText;
  bool _isSubmitting = false;
  bool _peopleInitialized = false;

  bool get _isEditing => widget.existingPlan != null;

  @override
  void initState() {
    super.initState();
    // Media for a Plan lives under its household
    // (households/{id}/plans/...), not the current user - all household
    // members share the same storage folder. See storage.rules:
    // isHouseholdMember(householdId).
    final householdId = ref.read(householdIdProvider).valueOrNull!;
    final existing = widget.existingPlan;

    if (existing != null) {
      _planId = existing.id;
      _titleController.text = existing.title;
      _notesController.text = existing.notes ?? '';
      _estimatedBudgetController.text = existing.budget?.estimated?.toString() ?? '';
      _currencyController.text = existing.budget?.currency ?? 'IDR';
      _startDate = existing.startDate;
      _endDate = existing.endDate;
      _category = existing.category;
      _location = existing.location;
      _checklist.addAll(existing.checklist);
      _itinerary.addAll(existing.itinerary);
      _links.addAll(existing.links);
      for (final item in existing.media) {
        _media.add(_PickedMedia.existing(item));
      }
      _peopleInitialized = existing.peopleIds.isEmpty;
    } else {
      _planId = ref.read(planRepositoryProvider).newPlanId();
    }
    _folderPath = StoragePaths.planMedia(householdId, _planId);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _estimatedBudgetController.dispose();
    _currencyController.dispose();
    _checklistInputController.dispose();
    _linkInputController.dispose();
    super.dispose();
  }

  bool get _isUploadingMedia => _media.any((m) => m.uploaded == null && m.error == null);
  bool get _hasMediaErrors => _media.any((m) => m.error != null);
  bool get _canAddMoreMedia => _media.length < AppLimits.maxMediaPerPlan;

  List<ItineraryItem> get _sortedItinerary {
    final list = [..._itinerary];
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  void _startUpload(File file) {
    final entry = _PickedMedia.uploading(id: const Uuid().v4(), file: file);
    setState(() => _media.add(entry));

    final storage = ref.read(storageServiceProvider);
    final task = storage.uploadImage(file: file, folderPath: _folderPath);

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

  Future<void> _pickInspirationPhotos() async {
    if (!_canAddMoreMedia) return;
    final remaining = AppLimits.maxMediaPerPlan - _media.length;
    final picked = await ImagePicker().pickMultiImage(limit: remaining);
    for (final xfile in picked) {
      _startUpload(File(xfile.path));
    }
  }

  void _removeMedia(_PickedMedia entry) {
    setState(() => _media.remove(entry));
    final path = entry.uploaded?.storagePath;
    if (path != null) {
      ref.read(storageServiceProvider).deleteMedia(path);
    }
  }

  void _addChecklistItem() {
    final text = _checklistInputController.text.trim();
    if (text.isEmpty || _checklist.length >= AppLimits.maxChecklistItems) return;
    setState(() {
      _checklist.add(ChecklistItem(id: const Uuid().v4(), title: text));
      _checklistInputController.clear();
    });
  }

  void _toggleChecklistItem(ChecklistItem item, bool isDone) {
    setState(() {
      final index = _checklist.indexOf(item);
      if (index != -1) _checklist[index] = item.copyWith(isDone: isDone);
    });
  }

  Future<void> _addItineraryItem() async {
    if (_itinerary.length >= AppLimits.maxItineraryItems) return;
    final item = await showItineraryItemSheet(context, planStartDate: _startDate, planEndDate: _endDate);
    if (item != null) setState(() => _itinerary.add(item));
  }

  Future<void> _editItineraryItem(ItineraryItem existing) async {
    final updated = await showItineraryItemSheet(
      context,
      planStartDate: _startDate,
      planEndDate: _endDate,
      existingItem: existing,
    );
    if (updated == null) return;
    setState(() {
      final index = _itinerary.indexWhere((i) => i.id == existing.id);
      if (index != -1) _itinerary[index] = updated;
    });
  }

  void _addLink() {
    var text = _linkInputController.text.trim();
    if (text.isEmpty) return;
    if (!text.startsWith('http://') && !text.startsWith('https://')) {
      text = 'https://$text';
    }
    setState(() {
      _links.add(text);
      _linkInputController.clear();
    });
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

  /// In edit mode we only have `peopleIds` from the Plan, not full [Person]
  /// objects. This resolves them against the live People list the first
  /// time it has data, then stops (via [_peopleInitialized]) so it never
  /// overwrites choices made afterward.
  void _maybeResolveExistingPeople() {
    if (_peopleInitialized) return;
    final existingIds = widget.existingPlan!.peopleIds.toSet();
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
    if (_category == null) {
      setState(() => _categoryErrorText = 'Please choose a category.');
      return;
    }
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
          const SnackBar(content: Text("Remove the photo that failed to upload, then try again.")));
      return;
    }
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final now = DateTime.now();
    final estimatedText = _estimatedBudgetController.text.trim();
    final budget = estimatedText.isEmpty
        ? null
        : Budget(
            estimated: double.tryParse(estimatedText),
            currency: _currencyController.text.trim().isEmpty
                ? 'IDR'
                : _currencyController.text.trim().toUpperCase(),
          );
    final notesText = _notesController.text.trim();
    final existing = widget.existingPlan;

    final plan = Plan(
      id: _planId,
      title: _titleController.text.trim(),
      category: _category!,
      startDate: _startDate!,
      endDate: _endDate,
      status: existing?.status ?? PlanStatus.idea,
      location: _location,
      peopleIds: _selectedPeople.map((p) => p.id).toList(),
      checklist: _checklist,
      itinerary: _itinerary,
      budget: budget,
      media: _media.map((m) => m.uploaded!).toList(),
      links: _links,
      notes: notesText.isEmpty ? null : notesText,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      completedAt: existing?.completedAt,
      convertedToMomentId: existing?.convertedToMomentId,
    );

    try {
      final repo = ref.read(planRepositoryProvider);
      if (_isEditing) {
        await repo.updatePlan(plan);
      } else {
        await repo.createPlan(plan);
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
      appBar: AppBar(title: Text(_isEditing ? 'Edit Plan' : 'Plan Something')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionLabel('What are you planning?'),
                TextFormField(
                  controller: _titleController,
                  maxLength: AppLimits.maxTitleLength,
                  decoration: const InputDecoration(hintText: 'e.g. Liburan keluarga ke Bali'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Tell us what you\'re planning.' : null,
                ),
                const _SectionLabel('Category'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final cat in PlanCategory.values)
                      TagChip(
                        label: cat.label,
                        selected: _category == cat,
                        color: AppColors.planAccent,
                        backgroundColor: AppColors.planAccentLight,
                        onTap: () => setState(() {
                          _category = cat;
                          _categoryErrorText = null;
                        }),
                      ),
                  ],
                ),
                if (_categoryErrorText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(_categoryErrorText!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
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
                                ? _startDate!.dayMonth
                                : '${_startDate!.dayMonth} – ${_endDate!.dayMonth}'),
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
                const _SectionLabel('Who is coming?'),
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
                const SizedBox(height: 16),
                const _SectionLabel('Checklist'),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _checklistInputController,
                        decoration: const InputDecoration(hintText: 'e.g. Book flight'),
                        onSubmitted: (_) => _addChecklistItem(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(onPressed: _addChecklistItem, icon: const Icon(Icons.add)),
                  ],
                ),
                if (_checklist.isNotEmpty) const SizedBox(height: 8),
                for (final item in _checklist)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      children: [
                        Checkbox(
                          value: item.isDone,
                          activeColor: AppColors.planAccent,
                          onChanged: (v) => _toggleChecklistItem(item, v ?? false),
                        ),
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              decoration: item.isDone ? TextDecoration.lineThrough : null,
                              color: item.isDone ? AppColors.textSecondary : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () => setState(() => _checklist.remove(item)),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                const _SectionLabel('Itinerary'),
                for (final item in _sortedItinerary)
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _editItineraryItem(item),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.planAccentLight,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 56,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.date.dayMonth,
                                    style: const TextStyle(
                                        color: AppColors.planAccent, fontWeight: FontWeight.w700, fontSize: 12)),
                                if (item.time != null)
                                  Text(item.time!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                                if (item.location != null)
                                  Text(item.location!.name,
                                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () => setState(() => _itinerary.remove(item)),
                          ),
                        ],
                      ),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: _addItineraryItem,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add itinerary item'),
                ),
                const SizedBox(height: 16),
                const _SectionLabel('Notes'),
                TextFormField(
                  controller: _notesController,
                  maxLength: AppLimits.maxNoteLength,
                  maxLines: 4,
                  decoration: const InputDecoration(hintText: 'Anything else worth remembering...'),
                ),
                const _SectionLabel('Budget'),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _estimatedBudgetController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(hintText: 'Estimated budget (optional)'),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final parsed = double.tryParse(v.trim());
                          if (parsed == null) return 'Enter a valid number.';
                          if (parsed < 0) return "Budget can't be negative.";
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _currencyController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(hintText: 'Currency'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const _SectionLabel('Inspiration'),
                MediaGrid(
                  canAddMore: _canAddMoreMedia,
                  onAddTap: _pickInspirationPhotos,
                  items: [
                    for (final m in _media)
                      MediaGridItem(
                        id: m.id,
                        localFile: m.file,
                        networkUrl: m.file == null ? (m.uploaded?.thumbnailUrl ?? m.uploaded?.url) : null,
                        progress: m.progress,
                        error: m.error,
                        onRemove: () => _removeMedia(m),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _linkInputController,
                        decoration: const InputDecoration(hintText: 'Add a link, e.g. a Pinterest board'),
                        onSubmitted: (_) => _addLink(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(onPressed: _addLink, icon: const Icon(Icons.add_link_rounded)),
                  ],
                ),
                for (final link in _links)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.link_rounded, size: 16, color: AppColors.planAccent),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(link, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () => setState(() => _links.remove(link)),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.planAccent),
                    onPressed: isBusy ? null : _save,
                    child: isBusy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(_isEditing ? 'Save Changes' : 'Create Plan'),
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
