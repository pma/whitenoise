import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:whitenoise/l10n/l10n.dart';
import 'package:whitenoise/theme.dart';
import 'package:whitenoise/widgets/wn_icon.dart';

/// Shows the attach options bottom sheet and returns when dismissed.
///
/// [onGallery] is called when the user picks "Gallery" (images & videos).
/// [onFile] is called when the user picks "File" (any file type).
Future<void> showAttachBottomSheet({
  required BuildContext context,
  required VoidCallback onGallery,
  required VoidCallback onFile,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.colors.backgroundPrimary,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
    ),
    builder: (_) => _AttachBottomSheet(onGallery: onGallery, onFile: onFile),
  );
}

class _AttachBottomSheet extends StatelessWidget {
  const _AttachBottomSheet({
    required this.onGallery,
    required this.onFile,
  });

  final VoidCallback onGallery;
  final VoidCallback onFile;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typographyScaled;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AttachOption(
              key: const Key('attach_gallery'),
              icon: WnIcons.image,
              label: context.l10n.attachGallery,
              onTap: () {
                Navigator.of(context).pop();
                onGallery();
              },
              colors: colors,
              typography: typography,
            ),
            _AttachOption(
              key: const Key('attach_file'),
              icon: WnIcons.file,
              label: context.l10n.attachFile,
              onTap: () {
                Navigator.of(context).pop();
                onFile();
              },
              colors: colors,
              typography: typography,
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachOption extends StatelessWidget {
  const _AttachOption({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.colors,
    required this.typography,
  });

  final WnIcons icon;
  final String label;
  final VoidCallback onTap;
  final SemanticColors colors;
  final AppTypography typography;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
        child: Row(
          children: [
            WnIcon(icon, size: 24.sp, color: colors.backgroundContentPrimary),
            SizedBox(width: 16.w),
            Text(
              label,
              style: typography.medium16.copyWith(
                color: colors.backgroundContentPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
