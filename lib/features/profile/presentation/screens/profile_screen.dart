import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/storage_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../household/domain/entities/household_invite.dart';
import '../../../household/presentation/providers/household_providers.dart';
import '../../../moments/presentation/providers/moment_providers.dart';
import '../../../plans/presentation/providers/plan_providers.dart';
import '../../domain/entities/user_profile.dart';
import '../providers/user_profile_providers.dart';
import '../widgets/timezone_picker_sheet.dart';
import 'privacy_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isUploadingPhoto = false;
  bool _isExporting = false;

  Future<void> _changePhoto() async {
    if (_isUploadingPhoto) return;
    final xfile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (xfile == null) return;

    setState(() => _isUploadingPhoto = true);
    try {
      final userId = ref.read(currentUserProvider)!.id;
      final storage = ref.read(storageServiceProvider);
      final task = storage.uploadImage(
        file: File(xfile.path),
        folderPath: StoragePaths.profilePhoto(userId),
      );
      final item = await task.result;
      await ref.read(userProfileRepositoryProvider).updateProfile(photoUrl: item.url);
    } on AppException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _editName(UserProfile? profile) async {
    final controller = TextEditingController(text: profile?.displayName ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: AppLimits.maxTitleLength,
          decoration: const InputDecoration(hintText: 'Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;
    try {
      await ref.read(userProfileRepositoryProvider).updateProfile(displayName: result);
    } on AppException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _changeTimezone(UserProfile? profile) async {
    final selected = await showTimezonePickerSheet(context, current: profile?.timezone);
    if (selected == null) return;
    try {
      await ref.read(userProfileRepositoryProvider).updateProfile(timezone: selected);
    } on AppException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _invitePartner() async {
    final controller = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Invite your partner'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(hintText: 'Their email address'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Send invite'),
          ),
        ],
      ),
    );
    if (email == null || email.isEmpty) return;

    final householdId = ref.read(householdIdProvider).valueOrNull;
    final uid = ref.read(currentUserProvider)?.id;
    if (householdId == null || uid == null) return;

    try {
      await ref.read(householdRepositoryProvider).sendInvite(
            householdId: householdId,
            email: email,
            invitedByUid: uid,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invited \$email — they\'ll see it next time they sign in.')),
        );
      }
    } on AppException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _acceptInvite(HouseholdInvite invite) async {
    final uid = ref.read(currentUserProvider)?.id;
    if (uid == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Join this household?'),
        content: const Text(
          "You'll start sharing Plans and Moments with them. Your own existing "
          "Plans and Moments stay where they are and won't be visible here anymore.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Not now')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Join')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(householdRepositoryProvider).acceptInvite(invite: invite, uid: uid);
    } on AppException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _leaveHousehold() async {
    final household = ref.read(householdProvider).valueOrNull;
    final uid = ref.read(currentUserProvider)?.id;
    final email = ref.read(currentUserProvider)?.email;
    if (household == null || uid == null) return;

    final isOnlyMember = household.members.length <= 1;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave this household?'),
        content: Text(
          isOnlyMember
              ? "You're the only member, so this just resets your household — nothing to leave."
              : "You'll stop seeing shared Plans and Moments. You'll get a fresh, empty "
                  'household of your own afterwards.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(isOnlyMember ? 'Reset' : 'Leave', style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(householdRepositoryProvider).removeMember(
            householdId: household.id,
            memberUid: uid,
            memberEmail: email ?? '',
          );
    } on AppException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _removeMember(String memberUid, String memberEmail) async {
    final household = ref.read(householdProvider).valueOrNull;
    if (household == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove \$memberEmail?'),
        content: const Text(
          "They'll stop seeing these shared Plans and Moments, and get a fresh, "
          'empty household of their own afterwards.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(householdRepositoryProvider).removeMember(
            householdId: household.id,
            memberUid: memberUid,
            memberEmail: memberEmail,
          );
    } on AppException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _exportData() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final momentsPage = await ref.read(momentRepositoryProvider).fetchMoments(limit: 1000);
      final plansPage = await ref.read(planRepositoryProvider).fetchPlans(limit: 1000);

      final export = {
        'exportedAt': DateTime.now().toIso8601String(),
        'moments': [
          for (final m in momentsPage.items)
            {
              'id': m.id,
              'title': m.title,
              'description': m.description,
              'startDate': m.startDate.toIso8601String(),
              'endDate': m.endDate?.toIso8601String(),
              'location': m.location == null
                  ? null
                  : {
                      'name': m.location!.name,
                      'address': m.location!.address,
                      'latitude': m.location!.latitude,
                      'longitude': m.location!.longitude,
                    },
              'tags': m.tags,
              'notes': m.notes,
              'photoUrls': m.media.map((med) => med.url).toList(),
            },
        ],
        'plans': [
          for (final p in plansPage.items)
            {
              'id': p.id,
              'title': p.title,
              'category': p.category.name,
              'status': p.status.name,
              'startDate': p.startDate.toIso8601String(),
              'endDate': p.endDate?.toIso8601String(),
              'notes': p.notes,
            },
        ],
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(export);
      await Share.share(jsonString, subject: 'TELLO data export');
    } on AppException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Sign Out')),
        ],
      ),
    );
    if (confirmed != true) return;
    // GoRouter's redirect handles navigation once authStateProvider emits
    // null — no manual navigation needed here.
    await ref.read(authRepositoryProvider).signOut();
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'This permanently deletes your Moments, Plans, People, photos, and '
          "settings. This can't be undone.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete Account', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(authRepositoryProvider).deleteAccount();
    } on AppException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final authUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: profileAsync.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(
          message: e is AppException ? e.message : 'Something went wrong. Please try again.',
          onRetry: () => ref.invalidate(userProfileProvider),
        ),
        data: (profile) {
          final displayName = (profile?.displayName?.isNotEmpty == true)
              ? profile!.displayName!
              : (authUser?.displayName ?? 'Your name');
          final email = profile?.email ?? authUser?.email ?? '';
          final hasPhoto = profile?.photoUrl != null && profile!.photoUrl!.isNotEmpty;

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _changePhoto,
                      child: SizedBox(
                        width: 88,
                        height: 88,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 44,
                              backgroundColor: AppColors.primaryLight,
                              backgroundImage: hasPhoto ? NetworkImage(profile.photoUrl!) : null,
                              child: !hasPhoto
                                  ? Text(
                                      profile?.initials ?? '?',
                                      style: const TextStyle(
                                        fontSize: 28,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    )
                                  : null,
                            ),
                            if (_isUploadingPhoto)
                              const Positioned.fill(
                                child: Center(
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                ),
                              )
                            else
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => _editName(profile),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(displayName, style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(width: 6),
                          const Icon(Icons.edit_rounded, size: 16, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(email, style: const TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.family_restroom_rounded),
                title: const Text('Keluarga & Aset'),
                subtitle: const Text('Anggota keluarga, rumah, kendaraan, dan dokumennya'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push(AppRoutes.family),
              ),
              const Divider(),
              Consumer(
                builder: (context, ref, _) {
                  final invites = ref.watch(pendingInvitesProvider).valueOrNull ?? const [];
                  if (invites.isEmpty) return const SizedBox.shrink();
                  return Column(
                    children: [
                      for (final invite in invites)
                        Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          color: AppColors.primaryLight,
                          child: ListTile(
                            leading: const Icon(Icons.group_add_rounded, color: AppColors.primary),
                            title: const Text("You've been invited to a shared household"),
                            subtitle: const Text('Tap to join and start sharing Plans & Moments'),
                            onTap: () => _acceptInvite(invite),
                          ),
                        ),
                      const SizedBox(height: 8),
                    ],
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.favorite_border_rounded),
                title: const Text('Invite partner'),
                subtitle: const Text('Share Plans & Moments with someone'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _invitePartner,
              ),
              Consumer(
                builder: (context, ref, _) {
                  final household = ref.watch(householdProvider).valueOrNull;
                  final myUid = ref.watch(currentUserProvider)?.id;
                  if (household == null || household.members.length <= 1) {
                    return const SizedBox.shrink();
                  }
                  final isOwner = household.ownerUid == myUid;
                  // memberEmails is appended in lockstep with members in
                  // every write path (invite accept, member creation), so
                  // parallel indices line up here.
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Sharing with', style: TextStyle(color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        for (var i = 0; i < household.members.length; i++)
                          if (household.members[i] != myUid)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.person_outline_rounded),
                              title: Text(
                                i < household.memberEmails.length ? household.memberEmails[i] : 'Member',
                              ),
                              trailing: isOwner
                                  ? IconButton(
                                      icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.error),
                                      onPressed: () => _removeMember(
                                        household.members[i],
                                        i < household.memberEmails.length ? household.memberEmails[i] : '',
                                      ),
                                    )
                                  : null,
                            ),
                      ],
                    ),
                  );
                },
              ),
              Consumer(
                builder: (context, ref, _) {
                  final household = ref.watch(householdProvider).valueOrNull;
                  if (household == null || household.members.length <= 1) {
                    return const SizedBox.shrink();
                  }
                  return ListTile(
                    leading: const Icon(Icons.logout_rounded, color: AppColors.error),
                    title: const Text('Leave household', style: TextStyle(color: AppColors.error)),
                    onTap: _leaveHousehold,
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.notifications_none_rounded),
                title: const Text('Notification settings'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push(AppRoutes.notificationSettings),
              ),
              ListTile(
                leading: const Icon(Icons.schedule_rounded),
                title: const Text('Timezone'),
                subtitle: Text(profile?.timezone ?? 'Not set'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _changeTimezone(profile),
              ),
              const ListTile(
                leading: Icon(Icons.palette_outlined),
                title: Text('Theme'),
                subtitle: Text('Light — dark mode coming soon'),
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PrivacyScreen()),
                ),
              ),
              ListTile(
                leading: _isExporting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.download_rounded),
                title: const Text('Export data'),
                onTap: _isExporting ? null : _exportData,
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout_rounded),
                title: const Text('Sign out'),
                onTap: _signOut,
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever_rounded, color: AppColors.error),
                title: const Text('Delete account', style: TextStyle(color: AppColors.error)),
                onTap: _deleteAccount,
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}
