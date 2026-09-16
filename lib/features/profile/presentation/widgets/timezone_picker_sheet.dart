import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class _TimezoneOption {
  const _TimezoneOption(this.id, this.label);
  final String id;
  final String label;
}

const _timezoneOptions = [
  _TimezoneOption('Asia/Jakarta', 'Jakarta — WIB (UTC+7)'),
  _TimezoneOption('Asia/Makassar', 'Makassar — WITA (UTC+8)'),
  _TimezoneOption('Asia/Jayapura', 'Jayapura — WIT (UTC+9)'),
  _TimezoneOption('Asia/Singapore', 'Singapore (UTC+8)'),
  _TimezoneOption('Asia/Tokyo', 'Tokyo (UTC+9)'),
  _TimezoneOption('Australia/Sydney', 'Sydney'),
  _TimezoneOption('Europe/London', 'London'),
  _TimezoneOption('America/New_York', 'New York'),
  _TimezoneOption('America/Los_Angeles', 'Los Angeles'),
  _TimezoneOption('UTC', 'UTC'),
];

/// Shows a sheet for picking a timezone. Returns the chosen IANA
/// timezone ID (e.g. 'Asia/Jakarta'), or null if dismissed.
///
/// This is a curated list, not the full IANA database — see README known
/// limitations. Given TELLO's Indonesian market focus, the three
/// Indonesian timezones are listed first regardless of the person's
/// device locale.
Future<String?> showTimezonePickerSheet(BuildContext context, {String? current}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _TimezonePickerSheet(current: current),
  );
}

class _TimezonePickerSheet extends StatelessWidget {
  const _TimezonePickerSheet({this.current});
  final String? current;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Text('Timezone', style: Theme.of(context).textTheme.titleLarge),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _timezoneOptions.length,
                itemBuilder: (context, i) {
                  final option = _timezoneOptions[i];
                  final isSelected = option.id == current;
                  return ListTile(
                    title: Text(option.label),
                    trailing: isSelected ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
                    onTap: () => Navigator.of(context).pop(option.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
