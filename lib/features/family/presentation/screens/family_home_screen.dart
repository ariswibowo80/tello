import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../providers/family_asset_providers.dart';
import '../providers/family_member_providers.dart';
import '../widgets/family_asset_card.dart';
import '../widgets/family_member_card.dart';

class FamilyHomeScreen extends ConsumerStatefulWidget {
  const FamilyHomeScreen({super.key});

  @override
  ConsumerState<FamilyHomeScreen> createState() => _FamilyHomeScreenState();
}

class _FamilyHomeScreenState extends ConsumerState<FamilyHomeScreen> with SingleTickerProviderStateMixin {
  late final _tabController = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Keluarga & Aset'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Keluarga'),
            Tab(text: 'Aset'),
          ],
        ),
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (context, _) => FloatingActionButton(
          onPressed: () async {
            if (_tabController.index == 0) {
              await context.push<bool>(AppRoutes.familyMemberForm);
            } else {
              await context.push<bool>(AppRoutes.familyAssetForm);
            }
          },
          child: const Icon(Icons.add),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _MembersTab(),
          _AssetsTab(),
        ],
      ),
    );
  }
}

class _MembersTab extends ConsumerWidget {
  const _MembersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(familyMembersListProvider);
    return membersAsync.when(
      loading: () => const LoadingState(),
      error: (e, _) => ErrorState(
        message: e is AppException ? e.message : 'Gagal memuat anggota keluarga.',
        onRetry: () => ref.invalidate(familyMembersListProvider),
      ),
      data: (members) {
        if (members.isEmpty) {
          return const EmptyState(
            icon: Icons.family_restroom_rounded,
            title: 'Belum ada anggota keluarga',
            message: 'Tambah anggota keluarga untuk menyimpan data dan dokumen mereka.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 12),
          itemCount: members.length,
          itemBuilder: (context, i) {
            final member = members[i];
            return FamilyMemberCard(
              member: member,
              onTap: () => context.push(AppRoutes.familyMemberDetail.replaceFirst(':id', member.id)),
            );
          },
        );
      },
    );
  }
}

class _AssetsTab extends ConsumerWidget {
  const _AssetsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assetsAsync = ref.watch(familyAssetsListProvider);
    return assetsAsync.when(
      loading: () => const LoadingState(),
      error: (e, _) => ErrorState(
        message: e is AppException ? e.message : 'Gagal memuat aset.',
        onRetry: () => ref.invalidate(familyAssetsListProvider),
      ),
      data: (assets) {
        if (assets.isEmpty) {
          return const EmptyState(
            icon: Icons.inventory_2_rounded,
            title: 'Belum ada aset',
            message: 'Tambah rumah, kendaraan, atau aset lain untuk menyimpan dokumennya.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 12),
          itemCount: assets.length,
          itemBuilder: (context, i) {
            final asset = assets[i];
            return FamilyAssetCard(
              asset: asset,
              onTap: () => context.push(AppRoutes.familyAssetDetail.replaceFirst(':id', asset.id)),
            );
          },
        );
      },
    );
  }
}
