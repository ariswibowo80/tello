import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// One tile in a [MediaGrid]. Exactly one of [localFile] / [networkUrl]
/// should be set: [localFile] for a photo/video just picked on-device
/// (possibly still uploading), [networkUrl] for media already in Storage.
class MediaGridItem {
  const MediaGridItem({
    required this.id,
    this.localFile,
    this.networkUrl,
    this.isVideo = false,
    this.progress,
    this.error,
    this.onRemove,
  });

  final String id;
  final File? localFile;
  final String? networkUrl;
  final bool isVideo;

  /// 0.0–1.0 while uploading, null once finished (or if not applicable).
  final double? progress;
  final String? error;
  final VoidCallback? onRemove;
}

class MediaGrid extends StatelessWidget {
  const MediaGrid({
    super.key,
    required this.items,
    this.onAddTap,
    this.canAddMore = true,
  });

  final List<MediaGridItem> items;
  final VoidCallback? onAddTap;
  final bool canAddMore;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: items.length + (canAddMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == items.length) {
          return _AddTile(onTap: onAddTap);
        }
        return _MediaTile(item: items[index]);
      },
    );
  }
}

class _MediaTile extends StatelessWidget {
  const _MediaTile({required this.item});
  final MediaGridItem item;

  @override
  Widget build(BuildContext context) {
    final isUploading = item.progress != null && item.progress! < 1.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (item.localFile != null)
            Image.file(item.localFile!, fit: BoxFit.cover)
          else if (item.networkUrl != null)
            CachedNetworkImage(imageUrl: item.networkUrl!, fit: BoxFit.cover)
          else
            Container(color: AppColors.primaryLight),
          if (item.isVideo)
            const Center(
              child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 32),
            ),
          if (isUploading)
            Container(
              color: Colors.black.withValues(alpha: 0.4),
              child: Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    value: item.progress,
                    strokeWidth: 3,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          if (item.error != null)
            Container(
              color: AppColors.error.withValues(alpha: 0.7),
              child: const Center(
                child: Icon(Icons.error_outline_rounded, color: Colors.white),
              ),
            ),
          if (item.onRemove != null)
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: item.onRemove,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primaryLight,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: const Center(
          child: Icon(Icons.add_a_photo_rounded, color: AppColors.primary),
        ),
      ),
    );
  }
}
