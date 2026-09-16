import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bodyStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5);
    final headingStyle = Theme.of(context)
        .textTheme
        .titleMedium
        ?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700);

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Your data is private by default', style: headingStyle),
          const SizedBox(height: 8),
          Text(
            'Every Moment, Plan, Place, and Person you add is stored under your '
            "account and isolated by Firebase's security rules, keyed to your "
            'signed-in identity. No one else can read or write your data — there is '
            'currently no feature to share a Moment, Plan, or your timeline with '
            'anyone else.',
            style: bodyStyle,
          ),
          const SizedBox(height: 24),
          Text('Photos and videos', style: headingStyle),
          const SizedBox(height: 8),
          Text(
            'Media you upload is stored in Firebase Storage under the same '
            'per-account isolation. Deleting a Moment or Plan also deletes its '
            'photos from Storage.',
            style: bodyStyle,
          ),
          const SizedBox(height: 24),
          Text('Notifications', style: headingStyle),
          const SizedBox(height: 8),
          Text(
            "If you enable notifications, this device's push token is stored on "
            'your profile so reminders can reach you. You can turn any category '
            'of reminder off from Notification Settings at any time.',
            style: bodyStyle,
          ),
          const SizedBox(height: 24),
          Text('Deleting your account', style: headingStyle),
          const SizedBox(height: 8),
          Text(
            'Deleting your account removes your Moments, Plans, People, and '
            'settings, along with your uploaded photos. This is permanent and '
            "cannot be undone — see Delete Account in this app's Profile screen.",
            style: bodyStyle,
          ),
        ],
      ),
    );
  }
}
