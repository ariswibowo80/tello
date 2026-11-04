import '../entities/family_asset.dart';

abstract class FamilyAssetRepository {
  String newAssetId();
  Stream<List<FamilyAsset>> watchAssets();
  Stream<FamilyAsset?> watchAsset(String assetId);
  Future<FamilyAsset> createAsset(FamilyAsset asset);
  Future<void> updateAsset(FamilyAsset asset);
  Future<void> deleteAsset(String assetId);
}
