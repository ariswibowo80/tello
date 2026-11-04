import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../household/presentation/providers/household_providers.dart';
import '../../data/repositories/firestore_family_asset_repository.dart';
import '../../domain/entities/family_asset.dart';
import '../../domain/repositories/family_asset_repository.dart';

final familyAssetRepositoryProvider = Provider<FamilyAssetRepository>((ref) {
  final householdId = ref.watch(householdIdProvider).valueOrNull;
  if (householdId == null) {
    throw StateError('familyAssetRepositoryProvider read before householdId is known.');
  }
  return FirestoreFamilyAssetRepository(householdId: householdId);
});

final familyAssetsListProvider = StreamProvider<List<FamilyAsset>>((ref) {
  return ref.watch(familyAssetRepositoryProvider).watchAssets();
});

final familyAssetProvider = StreamProvider.family<FamilyAsset?, String>((ref, assetId) {
  return ref.watch(familyAssetRepositoryProvider).watchAsset(assetId);
});
