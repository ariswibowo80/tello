import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import 'tag_chip.dart';

class TagInput extends StatefulWidget {
  const TagInput({super.key, required this.selectedTags, required this.onChanged});

  final Set<String> selectedTags;
  final ValueChanged<Set<String>> onChanged;

  @override
  State<TagInput> createState() => _TagInputState();
}

class _TagInputState extends State<TagInput> {
  final _controller = TextEditingController();

  static final _defaultTagsLower = AppTags.defaultCategories.map((t) => t.toLowerCase()).toSet();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle(String tagLower) {
    final updated = {...widget.selectedTags};
    if (updated.contains(tagLower)) {
      updated.remove(tagLower);
    } else {
      updated.add(tagLower);
    }
    widget.onChanged(updated);
  }

  void _addCustomTag(String raw) {
    final tag = raw.trim().replaceAll('#', '').toLowerCase();
    if (tag.isEmpty) return;
    widget.onChanged({...widget.selectedTags, tag});
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final customTags = widget.selectedTags.where((t) => !_defaultTagsLower.contains(t));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in AppTags.defaultCategories)
              TagChip(
                label: tag,
                selected: widget.selectedTags.contains(tag.toLowerCase()),
                onTap: () => _toggle(tag.toLowerCase()),
              ),
            for (final tag in customTags)
              TagChip(label: '#$tag', selected: true, onTap: () => _toggle(tag)),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _controller,
          decoration: const InputDecoration(hintText: 'Add a custom tag, e.g. #roadtrip'),
          textInputAction: TextInputAction.done,
          onSubmitted: _addCustomTag,
        ),
      ],
    );
  }
}
