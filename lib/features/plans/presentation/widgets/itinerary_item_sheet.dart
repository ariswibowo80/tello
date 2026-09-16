import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/extensions/date_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/location_picker_sheet.dart';
import '../../../moments/domain/entities/moment.dart' show GeoLocation;
import '../../domain/entities/plan.dart';

/// Shows a sheet for adding or editing one itinerary entry. Returns the
/// resulting [ItineraryItem], or null if dismissed without saving.
///
/// Pass [existingItem] to edit it in place (same id is kept on save);
/// omit it to add a new entry.
Future<ItineraryItem?> showItineraryItemSheet(
  BuildContext context, {
  required DateTime? planStartDate,
  required DateTime? planEndDate,
  ItineraryItem? existingItem,
}) {
  return showModalBottomSheet<ItineraryItem>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _ItineraryItemSheet(
      planStartDate: planStartDate,
      planEndDate: planEndDate,
      existingItem: existingItem,
    ),
  );
}

class _ItineraryItemSheet extends StatefulWidget {
  const _ItineraryItemSheet({
    required this.planStartDate,
    required this.planEndDate,
    this.existingItem,
  });

  final DateTime? planStartDate;
  final DateTime? planEndDate;
  final ItineraryItem? existingItem;

  @override
  State<_ItineraryItemSheet> createState() => _ItineraryItemSheetState();
}

class _ItineraryItemSheetState extends State<_ItineraryItemSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _titleController = TextEditingController(text: widget.existingItem?.title ?? '');
  late final _timeController = TextEditingController(text: widget.existingItem?.time ?? '');
  late final _notesController = TextEditingController(text: widget.existingItem?.notes ?? '');
  late DateTime _date = widget.existingItem?.date ?? widget.planStartDate ?? DateTime.now();
  GeoLocation? _location;

  bool get _isEditing => widget.existingItem != null;

  @override
  void initState() {
    super.initState();
    _location = widget.existingItem?.location;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _timeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: widget.planStartDate ?? DateTime(2000),
      lastDate: widget.planEndDate ?? DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickLocation() async {
    final result = await showLocationPickerSheet(context);
    if (result != null) setState(() => _location = result);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final item = ItineraryItem(
      id: widget.existingItem?.id ?? const Uuid().v4(),
      date: _date,
      time: _timeController.text.trim().isEmpty ? null : _timeController.text.trim(),
      title: _titleController.text.trim(),
      location: _location,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );
    Navigator.of(context).pop(item);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_isEditing ? 'Edit itinerary item' : 'Add itinerary item',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today_rounded, size: 16),
                      label: Text(_date.rangeLabel(null)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _timeController,
                      decoration: const InputDecoration(hintText: 'Time (e.g. 10:00 AM)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(hintText: 'What happens here? e.g. Bali Safari'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Give this stop a title.' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickLocation,
                      icon: const Icon(Icons.place_rounded, size: 16, color: AppColors.placeAccent),
                      label: Text(
                        _location?.name ?? 'Add a location (optional)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (_location != null)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => setState(() => _location = null),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(hintText: 'Notes (optional)'),
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.planAccent),
                  child: Text(_isEditing ? 'Save Changes' : 'Add to Itinerary'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
