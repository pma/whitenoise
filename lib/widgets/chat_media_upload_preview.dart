import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:whitenoise/hooks/use_media_upload.dart' show MediaUploadItem, MediaUploadStatus;
import 'package:whitenoise/theme.dart';
import 'package:whitenoise/widgets/wn_icon.dart';
import 'package:whitenoise/widgets/wn_media_preview.dart';
import 'package:whitenoise/widgets/wn_spinner.dart';

class ChatMediaUploadPreview extends HookWidget {
  const ChatMediaUploadPreview({
    super.key,
    required this.items,
    required this.onRemove,
  });

  final List<MediaUploadItem> items;
  final void Function(String filePath) onRemove;

  static final _imageExts = {
    'jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'heif', 'bmp',
  };

  static bool _isImage(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    return _imageExts.contains(ext);
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final imageItems = items.where((i) => _isImage(i.filePath)).toList();
    final fileItems = items.where((i) => !_isImage(i.filePath)).toList();

    final selectedIndex = useState(0);

    useEffect(() {
      if (selectedIndex.value >= imageItems.length) {
        selectedIndex.value = imageItems.isNotEmpty ? imageItems.length - 1 : 0;
      }
      return null;
    }, [imageItems.length]);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (imageItems.isNotEmpty)
          _ImagePreviewSection(
            items: imageItems,
            selectedIndex: selectedIndex.value,
            onSelectedChanged: (i) => selectedIndex.value = i,
            onRemove: onRemove,
          ),
        if (fileItems.isNotEmpty) ...[
          if (imageItems.isNotEmpty) SizedBox(height: 6.h),
          _FileChipList(items: fileItems, onRemove: onRemove),
        ],
      ],
    );
  }
}

// ── Image section (large preview, unchanged behaviour) ──────────────────────

class _ImagePreviewSection extends StatelessWidget {
  const _ImagePreviewSection({
    required this.items,
    required this.selectedIndex,
    required this.onSelectedChanged,
    required this.onRemove,
  });

  final List<MediaUploadItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelectedChanged;
  final void Function(String) onRemove;

  @override
  Widget build(BuildContext context) {
    final currentItem = items[selectedIndex];
    return Stack(
      children: [
        WnMediaPreview(
          key: const Key('chat_media_upload_preview'),
          selectedIndex: selectedIndex,
          onSelectedChanged: onSelectedChanged,
          onDelete: () => onRemove(currentItem.filePath),
          children: items
              .map(
                (item) => Image.file(
                  File(item.filePath),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              )
              .toList(),
        ),
        if (currentItem.status == MediaUploadStatus.uploading)
          const Positioned.fill(
            child: _UploadingOverlay(key: Key('main_uploading_overlay')),
          ),
        if (currentItem.status == MediaUploadStatus.error)
          Positioned.fill(
            child: _ErrorOverlay(
              key: const Key('main_error_overlay'),
              onRetry: currentItem.retry,
            ),
          ),
      ],
    );
  }
}

// ── File chips (compact horizontal row for non-image files) ─────────────────

class _FileChipList extends StatelessWidget {
  const _FileChipList({required this.items, required this.onRemove});

  final List<MediaUploadItem> items;
  final void Function(String) onRemove;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6.w,
      runSpacing: 4.h,
      children: items.map((item) => _FileChip(item: item, onRemove: onRemove)).toList(),
    );
  }
}

class _FileChip extends StatelessWidget {
  const _FileChip({required this.item, required this.onRemove});

  final MediaUploadItem item;
  final void Function(String) onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final name = item.filePath.split('/').last;

    Widget leading;
    switch (item.status) {
      case MediaUploadStatus.uploading:
        leading = SizedBox(
          width: 16.r,
          height: 16.r,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: colors.backgroundContentSecondary,
          ),
        );
      case MediaUploadStatus.error:
        leading = GestureDetector(
          onTap: item.retry,
          child: WnIcon(WnIcons.error, size: 16.sp, color: colors.fillDestructive),
        );
      case MediaUploadStatus.uploaded:
        leading = WnIcon(WnIcons.file, size: 16.sp, color: colors.backgroundContentSecondary);
    }

    return Container(
      key: Key('file_chip_${item.filePath}'),
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: colors.fillSecondary,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: item.status == MediaUploadStatus.error
              ? colors.fillDestructive
              : colors.borderSecondary,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading,
          SizedBox(width: 6.w),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 160.w),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.typographyScaled.medium12.copyWith(
                color: colors.backgroundContentPrimary,
              ),
            ),
          ),
          SizedBox(width: 6.w),
          GestureDetector(
            onTap: () => onRemove(item.filePath),
            child: WnIcon(
              WnIcons.closeSmall,
              size: 14.sp,
              color: colors.backgroundContentTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadingOverlay extends StatelessWidget {
  const _UploadingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          color: colors.backgroundPrimary.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(4.r),
        ),
        child: const Center(child: WnSpinner()),
      ),
    );
  }
}

class _ErrorOverlay extends StatelessWidget {
  const _ErrorOverlay({
    super.key,
    this.onRetry,
  });

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return GestureDetector(
      onTap: onRetry,
      child: Container(
        decoration: BoxDecoration(
          color: colors.fillDestructive.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(4.r),
        ),
        child: Center(
          child: WnIcon(
            WnIcons.error,
            color: colors.backgroundContentPrimary,
            size: 48.sp,
          ),
        ),
      ),
    );
  }
}
