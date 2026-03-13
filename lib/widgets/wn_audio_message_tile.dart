import 'dart:io';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:whitenoise/hooks/use_media_download.dart';
import 'package:whitenoise/src/rust/api/media_files.dart';
import 'package:whitenoise/theme.dart';
import 'package:whitenoise/widgets/wn_audio_player.dart';
import 'package:whitenoise/widgets/wn_media_error_placeholder.dart';

class WnAudioMessageTile extends HookWidget {
  final MediaFile mediaFile;
  final bool isOutgoing;

  const WnAudioMessageTile({
    super.key,
    required this.mediaFile,
    this.isOutgoing = false,
  });

  @override
  Widget build(BuildContext context) {
    final (:status, :localPath, :retry) = useMediaDownload(mediaFile: mediaFile);
    final colors = context.colors;

    return switch (status) {
      MediaDownloadStatus.loading => Padding(
          key: const Key('audio_loading'),
          padding: EdgeInsets.symmetric(vertical: 8.h),
          child: Row(
            children: [
              SizedBox(
                width: 32.r,
                height: 32.r,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.fillContentSecondary,
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                'Loading audio…',
                style: context.typographyScaled.medium12,
              ),
            ],
          ),
        ),
      MediaDownloadStatus.error => WnMediaErrorPlaceholder(
          key: const Key('audio_error'),
          onRetry: retry!,
          blurhash: null,
        ),
      MediaDownloadStatus.success => Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: WnAudioPlayer(
                key: Key('audio_player_${mediaFile.id}'),
                localPath: localPath!,
                isOutgoing: isOutgoing,
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.download_outlined,
                size: 20.r,
                color: colors.fillContentSecondary,
              ),
              tooltip: 'Save to Downloads',
              onPressed: () => _saveAudio(context, localPath!, mediaFile.mimeType),
            ),
          ],
        ),
    };
  }

  Future<void> _saveAudio(
    BuildContext context,
    String localPath,
    String mimeType,
  ) async {
    try {
      final bytes = await File(localPath).readAsBytes();
      final fileName = localPath.split('/').last;
      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: bytes,
        mimeType: MimeType.other,
        customMimeType: mimeType,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved to Downloads')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save file')),
        );
      }
    }
  }
}
