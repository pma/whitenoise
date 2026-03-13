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
      MediaDownloadStatus.success => WnAudioPlayer(
          key: Key('audio_player_${mediaFile.id}'),
          localPath: localPath!,
          isOutgoing: isOutgoing,
        ),
    };
  }
}
