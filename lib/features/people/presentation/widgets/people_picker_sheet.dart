import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../domain/entities/person.dart';
import '../providers/person_providers.dart';
import 'person_avatar.dart';

/// Shows a multi-select list of the user's people. Returns the selected
/// [Person] list, or null if the sheet was dismissed without confirming.
Future<List<Person>?> showPeoplePickerSheet(
  BuildContext context, {
  required List<Person> initiallySelected,
}) {
  return showModalBottomSheet<List<Person>>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _PeoplePickerSheet(initiallySelected: initiallySelected),
  );
}

class _PeoplePickerSheet extends ConsumerStatefulWidget {
  const _PeoplePickerSheet({required this.initiallySelected});
  final List<Person> initiallySelected;

  @override
  ConsumerState<_PeoplePickerSheet> createState() => _PeoplePickerSheetState();
}

class _PeoplePickerSheetState extends ConsumerState<_PeoplePickerSheet> {
  late final Set<String> _selectedIds = widget.initiallySelected.map((p) => p.id).toSet();
  final Map<String, Person> _selectedById = {};
  final _nameController = TextEditingController();
  bool _isAddingPerson = false;

  @override
  void initState() {
    super.initState();
    for (final p in widget.initiallySelected) {
      _selectedById[p.id] = p;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _addPerson() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _isAddingPerson) return;
    setState(() => _isAddingPerson = true);
    try {
      final repo = ref.read(personRepositoryProvider);
      final person = await repo.createPerson(name: name);
      setState(() {
        _selectedIds.add(person.id);
        _selectedById[person.id] = person;
        _nameController.clear();
      });
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _isAddingPerson = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final peopleAsync = ref.watch(peopleListProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: [
                      Text('Who was there?', style: Theme.of(context).textTheme.titleLarge),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          for (final id in _selectedIds) {
                            _selectedById.putIfAbsent(id, () => Person(id: id, name: ''));
                          }
                          Navigator.of(context).pop(
                            _selectedIds.map((id) => _selectedById[id]).whereType<Person>().toList(),
                          );
                        },
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(hintText: 'Add a new person'),
                          onSubmitted: (_) => _addPerson(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _isAddingPerson ? null : _addPerson,
                        icon: _isAddingPerson
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.add),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: peopleAsync.when(
                    loading: () => const LoadingState(),
                    error: (e, _) => ErrorState(
                      message: e is AppException ? e.message : 'Something went wrong. Please try again.',
                    ),
                    data: (people) {
                      if (people.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            'No people yet. Add someone above to start tagging who was there.',
                            textAlign: TextAlign.center,
                          ),
                        );
                      }
                      return ListView.builder(
                        controller: scrollController,
                        itemCount: people.length,
                        itemBuilder: (context, i) {
                          final person = people[i];
                          final isSelected = _selectedIds.contains(person.id);
                          return ListTile(
                            leading: PersonAvatar(person: person, selected: isSelected),
                            title: Text(person.name),
                            subtitle: person.relationship != null ? Text(person.relationship!) : null,
                            trailing: Checkbox(
                              value: isSelected,
                              activeColor: AppColors.primary,
                              onChanged: (_) => setState(() {
                                if (isSelected) {
                                  _selectedIds.remove(person.id);
                                } else {
                                  _selectedIds.add(person.id);
                                  _selectedById[person.id] = person;
                                }
                              }),
                            ),
                            onTap: () => setState(() {
                              if (isSelected) {
                                _selectedIds.remove(person.id);
                              } else {
                                _selectedIds.add(person.id);
                                _selectedById[person.id] = person;
                              }
                            }),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
