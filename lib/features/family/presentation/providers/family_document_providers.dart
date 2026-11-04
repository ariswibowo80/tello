import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../household/presentation/providers/household_providers.dart';
import '../../data/repositories/firestore_family_document_repository.dart';
import '../../domain/entities/family_document.dart';
import '../../domain/repositories/family_document_repository.dart';

final familyDocumentRepositoryProvider = Provider<FamilyDocumentRepository>((ref) {
  final householdId = ref.watch(householdIdProvider).valueOrNull;
  if (householdId == null) {
    throw StateError('familyDocumentRepositoryProvider read before householdId is known.');
  }
  return FirestoreFamilyDocumentRepository(householdId: householdId);
});

/// Key for [familyDocumentsProvider] — a parent type + its doc ID.
typedef DocumentParentKey = (DocumentParentType type, String parentId);

final familyDocumentsProvider = StreamProvider.family<List<FamilyDocument>, DocumentParentKey>(
  (ref, key) {
    final (type, parentId) = key;
    return ref.watch(familyDocumentRepositoryProvider).watchDocuments(type, parentId);
  },
);
