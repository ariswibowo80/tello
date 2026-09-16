import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

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
import '../../../../core/utils/maps_launcher.dart';
import '../../../moments/domain/entities/moment.dart' show GeoLocation, MediaType;
import '../../../moments/presentation/providers/moment_providers.dart';
import '../../../moments/presentation/widgets/photo_viewer.dart';
import '../../../people/domain/entities/person.dart';
import '../../../people/presentation/widgets/person_avatar.dart';
import '../../../timeline/presentation/providers/moments_timeline_controller.dart';
import '../../../timeline/presentation/providers/plans_timeline_controller.dart';
import '../../domain/entities/plan.dart';
import '../providers/plan_detail_providers.dart';
import '../providers/plan_providers.dart';
import '../providers/plans_list_controller.dart';
import '../widgets/plan_category_display.dart';
import '../widgets/plan_to_moment_sheet.dart';

class PlanDetailScreen extends ConsumerStatefulWidget {
  const PlanDetailScreen({super.key, required this.planId});

  final String planId;

  @override
  ConsumerState<PlanDetailScreen> createState() => _PlanDetailScreenState();
}

class _PlanDetailScreenState extends ConsumerState<PlanDetailScreen> {
  bool _isDeleting = false;
  bool _isCancelling = false;
  bool _isConverting = false;

  void _refreshPlanLists() {
    ref.invalidate(plansListProvider);
    ref.invalidate(plansTimelineProvider);
    ref.invalidate(upcomingPlansProvider);
  }

  Future<void> _toggleChecklistItem(Plan plan, ChecklistItem item, bool isDone) async {
    try {
      await ref
          .read(planRepositoryProvider)
          .updateChecklistItem(planId: plan.id, itemId: item.id, isDone: isDone);
    } on AppException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _cancelPlan(Plan plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this plan?'),
        content: const Text("It'll move to your Cancelled list. You can't undo this from here."),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Keep it')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancel Plan', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || _isCancelling) return;

    setState(() => _isCancelling = true);
    try {
      await ref.read(planRepositoryProvider).updateStatus(planId: plan.id, status: PlanStatus.cancelled);
      _refreshPlanLists();
    } on AppException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  Future<void> _confirmDelete(Plan plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this plan?'),
        content: const Text("This will permanently remove the plan and its photos. This can't be undone."),
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
      for (final media in plan.media) {
        await storage.deleteMedia(media.storagePath);
        if (media.thumbnailStoragePath != null) {
          await storage.deleteMedia(media.thumbnailStoragePath!);
        }
      }
      await ref.read(planRepositoryProvider).deletePlan(plan.id);
      _refreshPlanLists();
      if (mounted) context.pop();
    } on AppException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  Future<void> _markCompleted(Plan plan) async {
    final story = await showPlanToMomentSheet(context, plan: plan);
    if (story == null || _isConverting) return;

    setState(() => _isConverting = true);
    try {
      final draft = plan.toMomentDraft(story: story);
      final moment = await ref
          .read(momentRepositoryProvider)
          .createMomentFromPlan(planId: plan.id, draft: draft);
      ref.invalidate(momentsTimelineProvider);
      _refreshPlanLists();
      if (mounted) context.pushReplacement('/moment/${moment.id}');
    } on AppException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isConverting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final planAsync = ref.watch(planDetailProvider(widget.planId));

    return planAsync.when(
      loading: () => Scaffold(appBar: AppBar(), body: const LoadingState()),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorState(
          message: e is AppException ? e.message : 'Something went wrong. Please try again.',
          onRetry: () => ref.invalidate(planDetailProvider(widget.planId)),
        ),
      ),
      data: (plan) {
        if (plan == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
              icon: Icons.flight_takeoff_rounded,
              title: 'This plan is gone',
              message: 'It may have already been deleted.',
            ),
          );
        }
        return _PlanDetailContent(
          plan: plan,
          isBusy: _isDeleting || _isCancelling,
          isConverting: _isConverting,
          onEdit: () => context.push(AppRoutes.editPlan, extra: plan),
          onCancel: () => _cancelPlan(plan),
          onDelete: () => _confirmDelete(plan),
          onMarkCompleted: () => _markCompleted(plan),
          onToggleChecklist: (item, isDone) => _toggleChecklistItem(plan, item, isDone),
        );
      },
    );
  }
}

class _PlanDetailContent extends ConsumerWidget {
  const _PlanDetailContent({
    required this.plan,
    required this.isBusy,
    required this.isConverting,
    required this.onEdit,
    required this.onCancel,
    required this.onDelete,
    required this.onMarkCompleted,
    required this.onToggleChecklist,
  });

  final Plan plan;
  final bool isBusy;
  final bool isConverting;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final VoidCallback onDelete;
  final VoidCallback onMarkCompleted;
  final void Function(ChecklistItem item, bool isDone) onToggleChecklist;

  bool get _isOpen => plan.status != PlanStatus.completed && plan.status != PlanStatus.cancelled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final people = ref.watch(planPeopleProvider(plan));

    return Scaffold(
      appBar: AppBar(
        title: Text(plan.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit_rounded), onPressed: onEdit),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'cancel') onCancel();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (context) => [
              if (_isOpen) const PopupMenuItem(value: 'cancel', child: Text('Cancel Plan')),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(20, 16, 20, _isOpen || plan.status == PlanStatus.completed ? 100 : 24),
            children: [
              Row(
                children: [
                  Icon(plan.category.icon, size: 16, color: AppColors.planAccent),
                  const SizedBox(width: 6),
                  Text(
                    plan.category.label,
                    style: const TextStyle(color: AppColors.planAccent, fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                  const Spacer(),
                  if (plan.status == PlanStatus.completed) const _StatusBadge(label: 'Completed', color: AppColors.success),
                  if (plan.status == PlanStatus.cancelled) const _StatusBadge(label: 'Cancelled', color: AppColors.textSecondary),
                ],
              ),
              const SizedBox(height: 8),
              Text(plan.title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                plan.startDate.rangeLabel(plan.endDate),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
              if (plan.location != null) ...[
                const SizedBox(height: 4),
                InkWell(
                  onTap: () async {
                    final opened = await openInGoogleMaps(plan.location!);
                    if (!opened && context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text("Couldn't open Google Maps.")));
                    }
                  },
                  child: LocationChip(name: plan.location!.address ?? plan.location!.name),
                ),
              ],
              const SizedBox(height: 14),
              if (_isOpen)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.planAccent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    plan.startDate.countdownLabel,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              if (plan.checklist.isNotEmpty) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: plan.progress,
                    minHeight: 8,
                    backgroundColor: AppColors.planAccentLight,
                    valueColor: const AlwaysStoppedAnimation(AppColors.planAccent),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(plan.progress * 100).round()}% complete',
                  style: const TextStyle(color: AppColors.planAccent, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
              if (people.isNotEmpty) ...[
                const SizedBox(height: 20),
                const _SectionLabel('Who is coming'),
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    for (final p in people)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PersonAvatar(person: p, size: 44),
                          const SizedBox(height: 4),
                          Text(p.name, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              const _SectionLabel('Checklist'),
              if (plan.checklist.isEmpty)
                const _MutedText('No checklist yet — add one from Edit.')
              else
                for (final item in plan.checklist)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      children: [
                        Checkbox(
                          value: item.isDone,
                          activeColor: AppColors.planAccent,
                          onChanged: isBusy ? null : (v) => onToggleChecklist(item, v ?? false),
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
                      ],
                    ),
                  ),
              const SizedBox(height: 20),
              const _SectionLabel('Itinerary'),
              if (plan.itinerary.isEmpty)
                const _MutedText('No itinerary yet — add one from Edit.')
              else
                _ItineraryList(items: plan.itinerary),
              const SizedBox(height: 20),
              const _SectionLabel('Budget'),
              _BudgetSection(plan: plan),
              const SizedBox(height: 20),
              const _SectionLabel('Places'),
              _PlacesMap(location: plan.location),
              const SizedBox(height: 20),
              const _SectionLabel('Photos & Inspiration'),
              _InspirationSection(plan: plan),
              const SizedBox(height: 20),
              const _SectionLabel('Notes'),
              _PlanNotesEditor(plan: plan),
            ],
          ),
          if (_isOpen)
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.planAccent),
                  onPressed: isConverting ? null : onMarkCompleted,
                  child: isConverting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Mark as Completed'),
                ),
              ),
            )
          else if (plan.status == PlanStatus.completed && plan.convertedToMomentId != null)
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () => context.push('/moment/${plan.convertedToMomentId}'),
                  child: const Text('View the Memory'),
                ),
              ),
            ),
          if (isBusy)
            Positioned.fill(
              child: Container(
                color: Colors.black26,
                child: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _MutedText extends StatelessWidget {
  const _MutedText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
            fontStyle: FontStyle.italic,
          ),
    );
  }
}

class _ItineraryList extends StatelessWidget {
  const _ItineraryList({required this.items});
  final List<ItineraryItem> items;

  Map<DateTime, List<ItineraryItem>> _groupByDay() {
    final sorted = [...items]..sort((a, b) => a.date.compareTo(b.date));
    final map = <DateTime, List<ItineraryItem>>{};
    for (final item in sorted) {
      final day = DateTime(item.date.year, item.date.month, item.date.day);
      map.putIfAbsent(day, () => []).add(item);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByDay();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in grouped.entries) ...[
          Text(
            entry.key.dayMonth,
            style: const TextStyle(color: AppColors.planAccent, fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 6),
          for (final item in entry.value)
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 64,
                    child: Text(
                      item.time ?? '',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (item.location != null)
                          InkWell(
                            onTap: () async {
                              final opened = await openInGoogleMaps(item.location!);
                              if (!opened && context.mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(const SnackBar(content: Text("Couldn't open Google Maps.")));
                              }
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.place_rounded, size: 12, color: AppColors.textSecondary),
                                const SizedBox(width: 2),
                                Flexible(
                                  child: Text(
                                    item.location!.name,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (item.notes != null)
                          Text(item.notes!,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

String _formatMoney(double amount, String currency) {
  return '$currency ${NumberFormat.decimalPattern('en_US').format(amount)}';
}

class _BudgetSection extends StatelessWidget {
  const _BudgetSection({required this.plan});
  final Plan plan;

  @override
  Widget build(BuildContext context) {
    final budget = plan.budget;
    final currency = budget?.currency ?? 'IDR';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _BudgetFigure(
                label: 'Estimated',
                value: budget?.estimated != null ? _formatMoney(budget!.estimated!, currency) : '—',
              ),
            ),
            Expanded(
              child: _BudgetFigure(
                label: 'Actual',
                value: budget?.actual != null ? _formatMoney(budget!.actual!, currency) : '—',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ActualBudgetEditor(plan: plan),
      ],
    );
  }
}

class _BudgetFigure extends StatelessWidget {
  const _BudgetFigure({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      ],
    );
  }
}

class _ActualBudgetEditor extends ConsumerStatefulWidget {
  const _ActualBudgetEditor({required this.plan});
  final Plan plan;

  @override
  ConsumerState<_ActualBudgetEditor> createState() => _ActualBudgetEditorState();
}

class _ActualBudgetEditorState extends ConsumerState<_ActualBudgetEditor> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.plan.budget?.actual?.toString() ?? '');
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
      final parsed = double.tryParse(_controller.text.trim());
      final updatedBudget = Budget(
        estimated: widget.plan.budget?.estimated,
        actual: parsed,
        currency: widget.plan.budget?.currency ?? 'IDR',
      );
      final updated = widget.plan.copyWith(budget: updatedBudget);
      await ref.read(planRepositoryProvider).updatePlan(updated);
      if (mounted) setState(() => _isDirty = false);
    } on AppException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: 'Update actual spend'),
            onChanged: (_) => setState(() => _isDirty = true),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          onPressed: (_isDirty && !_isSaving) ? _save : null,
          style: IconButton.styleFrom(backgroundColor: AppColors.planAccent),
          icon: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.check),
        ),
      ],
    );
  }
}

class _PlacesMap extends StatelessWidget {
  const _PlacesMap({required this.location});
  final GeoLocation? location;

  @override
  Widget build(BuildContext context) {
    if (location == null || location!.latitude == null || location!.longitude == null) {
      return const _MutedText('No location added yet — add one from Edit.');
    }
    final position = LatLng(location!.latitude!, location!.longitude!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 180,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: position, zoom: 13),
              markers: {
                Marker(
                  markerId: const MarkerId('plan-location'),
                  position: position,
                  infoWindow: InfoWindow(title: location!.name),
                ),
              },
              zoomControlsEnabled: false,
              scrollGesturesEnabled: false,
            ),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            final opened = await openInGoogleMaps(location!);
            if (!opened && context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text("Couldn't open Google Maps.")));
            }
          },
          icon: const Icon(Icons.map_rounded, size: 16),
          label: const Text('Open in Google Maps'),
        ),
      ],
    );
  }
}

class _InspirationSection extends StatelessWidget {
  const _InspirationSection({required this.plan});
  final Plan plan;

  @override
  Widget build(BuildContext context) {
    if (plan.media.isEmpty && plan.links.isEmpty) {
      return const _MutedText('Nothing added yet — add photos or links from Edit.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (plan.media.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: plan.media.length,
            itemBuilder: (context, i) {
              final item = plan.media[i];
              return GestureDetector(
                onTap: () => showPhotoViewer(context, media: plan.media, initialIndex: i),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: item.type == MediaType.image
                      ? Image.network(item.thumbnailUrl ?? item.url, fit: BoxFit.cover)
                      : Container(color: AppColors.planAccentLight),
                ),
              );
            },
          ),
        if (plan.links.isNotEmpty) ...[
          if (plan.media.isNotEmpty) const SizedBox(height: 12),
          for (final link in plan.links)
            InkWell(
              onTap: () async {
                final opened = await openExternalLink(link);
                if (!opened && context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text("Couldn't open that link.")));
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.link_rounded, size: 16, color: AppColors.planAccent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        link,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(decoration: TextDecoration.underline),
                      ),
                    ),
                    const Icon(Icons.open_in_new_rounded, size: 14, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _PlanNotesEditor extends ConsumerStatefulWidget {
  const _PlanNotesEditor({required this.plan});
  final Plan plan;

  @override
  ConsumerState<_PlanNotesEditor> createState() => _PlanNotesEditorState();
}

class _PlanNotesEditorState extends ConsumerState<_PlanNotesEditor> {
  late final TextEditingController _controller = TextEditingController(text: widget.plan.notes ?? '');
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
      final updated = widget.plan.copyWith(notes: trimmed.isEmpty ? null : trimmed, clearNotes: trimmed.isEmpty);
      await ref.read(planRepositoryProvider).updatePlan(updated);
      if (mounted) setState(() => _isDirty = false);
    } on AppException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          maxLines: 4,
          maxLength: AppLimits.maxNoteLength,
          decoration: const InputDecoration(hintText: 'Anything else worth remembering...'),
          onChanged: (_) => setState(() => _isDirty = true),
        ),
        const SizedBox(height: 4),
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
    );
  }
}
