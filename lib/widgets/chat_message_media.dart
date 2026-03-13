import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:whitenoise/hooks/use_media_download.dart';
import 'package:whitenoise/src/rust/api/media_files.dart';
import 'package:whitenoise/widgets/wn_audio_message_tile.dart';
import 'package:whitenoise/widgets/wn_blurhash_placeholder.dart';
import 'package:whitenoise/widgets/wn_media_error_placeholder.dart';
import 'package:whitenoise/widgets/wn_message_media.dart';

class ChatMessageMedia extends StatelessWidget {
  final List<MediaFile> mediaFiles;
  final ValueChanged<int>? onMediaTap;
  final bool isOutgoing;

  const ChatMessageMedia({
    super.key,
    required this.mediaFiles,
    this.onMediaTap,
    this.isOutgoing = false,
  });

  @override
  Widget build(BuildContext context) {
    final audioFiles =
        mediaFiles.where((f) => f.mimeType.startsWith('audio/')).toList();
    final imageFiles =
        mediaFiles.where((f) => !f.mimeType.startsWith('audio/')).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (imageFiles.isNotEmpty)
          WnMessageMedia(
            tiles: imageFiles
                .map((mf) => _ChatMessageMediaTile(mediaFile: mf))
                .toList(),
            onTileTap: onMediaTap,
          ),
        ...audioFiles.map(
          (mf) => WnAudioMessageTile(
            key: Key('audio_tile_${mf.id}'),
            mediaFile: mf,
            isOutgoing: isOutgoing,
          ),
        ),
      ],
    );
  }
}

class _ChatMessageMediaTile extends HookWidget {
  final MediaFile mediaFile;

  const _ChatMessageMediaTile({required this.mediaFile});

  @override
  Widget build(BuildContext context) {
    final (:status, :localPath, :retry) = useMediaDownload(mediaFile: mediaFile);
    final fadeController = useAnimationController(
      duration: const Duration(milliseconds: 300),
    );

    useEffect(() {
      if (status == MediaDownloadStatus.success) {
        fadeController.forward();
      } else {
        fadeController.reset();
      }
      return null;
    }, [status]);

    if (status == MediaDownloadStatus.error) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4.r),
        child: WnMediaErrorPlaceholder(
          key: const Key('error_placeholder'),
          onRetry: retry!,
          blurhash: mediaFile.fileMetadata?.blurhash,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(4.r),
      child: Stack(
        fit: StackFit.expand,
        children: [
          WnBlurhashPlaceholder(
            key: const Key('loading_placeholder'),
            blurhash: mediaFile.fileMetadata?.blurhash,
          ),
          if (status == MediaDownloadStatus.success)
            FadeTransition(
              key: const Key('fade_transition'),
              opacity: fadeController,
              child: Image.file(
                File(localPath!),
                key: const Key('media_image'),
                fit: BoxFit.cover,
              ),
            ),
        ],
      ),
    );
  }
}
