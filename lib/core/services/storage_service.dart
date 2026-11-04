import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:uuid/uuid.dart';

import '../../features/moments/domain/entities/moment.dart' show MediaItem, MediaType;
import '../errors/app_exception.dart';

/// A live progress stream (0.0–1.0) plus a Future that resolves to the
/// finished [MediaItem], or throws an [AppException] if the upload
/// ultimately fails (after retrying once).
class MediaUploadTask {
  MediaUploadTask({required this.progress, required this.result});
  final Stream<double> progress;
  final Future<MediaItem> result;
}

/// Where a document file ended up after upload — just enough to build a
/// [FamilyDocument] (no thumbnail; scanned IDs/PDFs don't need one).
class DocumentUploadResult {
  const DocumentUploadResult({required this.url, required this.storagePath, required this.isPdf});
  final String url;
  final String storagePath;
  final bool isPdf;
}

class DocumentUploadTask {
  DocumentUploadTask({required this.progress, required this.result});
  final Stream<double> progress;
  final Future<DocumentUploadResult> result;
}

/// Handles compression, thumbnail generation, and upload of photos/videos
/// to Firebase Storage. Kept out of repositories/widgets so Moments and
/// Plans share one implementation of "attach media to a thing".
class StorageService {
  StorageService({FirebaseStorage? storage, Uuid? uuid})
      : _storage = storage ?? FirebaseStorage.instance,
        _uuid = uuid ?? const Uuid();

  final FirebaseStorage _storage;
  final Uuid _uuid;

  /// Mirrors the 25MB cap enforced in storage.rules — checked client-side
  /// too so the person gets immediate feedback instead of a rules-denied
  /// error after a slow upload.
  static const int maxUploadBytes = 25 * 1024 * 1024;

  MediaUploadTask uploadImage({required File file, required String folderPath}) {
    final controller = StreamController<double>.broadcast();
    final id = _uuid.v4();

    Future<MediaItem> run() async {
      try {
        return await _withRetry(() async {
          final fullBytes = await FlutterImageCompress.compressWithFile(
                file.absolute.path,
                quality: 82,
                minWidth: 1600,
                minHeight: 1600,
              ) ??
              await file.readAsBytes();

          if (fullBytes.lengthInBytes > maxUploadBytes) {
            throw const ValidationException(
                "That photo is too large, even after compression. Please choose a smaller file.");
          }

          final thumbBytes = await FlutterImageCompress.compressWithFile(
                file.absolute.path,
                quality: 60,
                minWidth: 320,
                minHeight: 320,
              ) ??
              fullBytes;

          final fullRef = _storage.ref('$folderPath/$id.jpg');
          final thumbRef = _storage.ref('$folderPath/${id}_thumb.jpg');

          final uploadTask = fullRef.putData(
            Uint8List.fromList(fullBytes),
            SettableMetadata(contentType: 'image/jpeg'),
          );
          final progressSub = uploadTask.snapshotEvents.listen((snapshot) {
            if (snapshot.totalBytes > 0 && !controller.isClosed) {
              controller.add(snapshot.bytesTransferred / snapshot.totalBytes);
            }
          });
          await uploadTask;
          await progressSub.cancel();

          await thumbRef.putData(
            Uint8List.fromList(thumbBytes),
            SettableMetadata(contentType: 'image/jpeg'),
          );

          final url = await fullRef.getDownloadURL();
          final thumbUrl = await thumbRef.getDownloadURL();

          return MediaItem(
            url: url,
            storagePath: fullRef.fullPath,
            type: MediaType.image,
            thumbnailUrl: thumbUrl,
            thumbnailStoragePath: thumbRef.fullPath,
            createdAt: DateTime.now(),
          );
        });
      } finally {
        await controller.close();
      }
    }

    return MediaUploadTask(progress: controller.stream, result: run());
  }

  MediaUploadTask uploadVideo({required File file, required String folderPath}) {
    final controller = StreamController<double>.broadcast();
    final id = _uuid.v4();

    Future<MediaItem> run() async {
      try {
        return await _withRetry(() async {
          final size = await file.length();
          if (size > maxUploadBytes) {
            throw const ValidationException('That video is too large. Please choose a smaller file.');
          }

          final ref = _storage.ref('$folderPath/$id.mp4');
          final uploadTask = ref.putFile(file, SettableMetadata(contentType: 'video/mp4'));
          final progressSub = uploadTask.snapshotEvents.listen((snapshot) {
            if (snapshot.totalBytes > 0 && !controller.isClosed) {
              controller.add(snapshot.bytesTransferred / snapshot.totalBytes);
            }
          });
          await uploadTask;
          await progressSub.cancel();

          final url = await ref.getDownloadURL();
          return MediaItem(
            url: url,
            storagePath: ref.fullPath,
            type: MediaType.video,
            createdAt: DateTime.now(),
          );
        });
      } finally {
        await controller.close();
      }
    }

    return MediaUploadTask(progress: controller.stream, result: run());
  }

  /// Uploads a family/asset document file — a compressed JPEG if [isPdf]
  /// is false (reusing the same compression path as [uploadImage], since
  /// a photographed KTP/STNK is still just a photo), or the raw PDF bytes
  /// otherwise. No thumbnail is generated either way.
  DocumentUploadTask uploadDocument({required File file, required String folderPath, required bool isPdf}) {
    final controller = StreamController<double>.broadcast();
    final id = _uuid.v4();

    Future<DocumentUploadResult> run() async {
      try {
        return await _withRetry(() async {
          final Uint8List bytes;
          final String extension;
          final String contentType;

          if (isPdf) {
            bytes = Uint8List.fromList(await file.readAsBytes());
            extension = 'pdf';
            contentType = 'application/pdf';
          } else {
            bytes = Uint8List.fromList(
              await FlutterImageCompress.compressWithFile(
                    file.absolute.path,
                    quality: 85,
                    minWidth: 1600,
                    minHeight: 1600,
                  ) ??
                  await file.readAsBytes(),
            );
            extension = 'jpg';
            contentType = 'image/jpeg';
          }

          if (bytes.lengthInBytes > maxUploadBytes) {
            throw const ValidationException('That file is too large. Please choose a smaller file.');
          }

          final ref = _storage.ref('$folderPath/$id.$extension');
          final uploadTask = ref.putData(bytes, SettableMetadata(contentType: contentType));
          final progressSub = uploadTask.snapshotEvents.listen((snapshot) {
            if (snapshot.totalBytes > 0 && !controller.isClosed) {
              controller.add(snapshot.bytesTransferred / snapshot.totalBytes);
            }
          });
          await uploadTask;
          await progressSub.cancel();

          final url = await ref.getDownloadURL();
          return DocumentUploadResult(url: url, storagePath: ref.fullPath, isPdf: isPdf);
        });
      } finally {
        await controller.close();
      }
    }

    return DocumentUploadTask(progress: controller.stream, result: run());
  }

  Future<void> deleteMedia(String storagePath) async {
    try {
      await _storage.ref(storagePath).delete();
    } on FirebaseException catch (e) {
      // Already gone is fine — nothing left to clean up.
      if (e.code != 'object-not-found') {
        throw mapFirebaseErrorCode(e.code, cause: e);
      }
    }
  }

  /// Retries once on a transient Firebase/network failure. Validation
  /// failures (file too large) are not retried — retrying won't help.
  Future<T> _withRetry<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on ValidationException {
      rethrow;
    } on FirebaseException catch (e) {
      if (e.code == 'canceled') rethrow;
      try {
        return await action();
      } on FirebaseException catch (e2) {
        throw mapFirebaseErrorCode(e2.code, cause: e2);
      }
    }
  }
}
