import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:just_audio/just_audio.dart';
import 'package:whitenoise/theme.dart';

class WnAudioPlayer extends HookWidget {
  final String localPath;
  final bool isOutgoing;

  const WnAudioPlayer({
    super.key,
    required this.localPath,
    required this.isOutgoing,
  });

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final player = useMemoized(() => AudioPlayer(), []);
    final isPlaying = useState(false);
    final position = useState(Duration.zero);
    final duration = useState(Duration.zero);
    final isLoaded = useState(false);
    final loadError = useState(false);

    useEffect(() {
      isLoaded.value = false;
      loadError.value = false;
      player
          .setFilePath(localPath)
          .then((_) {
            duration.value = player.duration ?? Duration.zero;
            isLoaded.value = true;
          })
          .catchError((Object e) {
            loadError.value = true;
          });
      final posSub = player.positionStream.listen((p) => position.value = p);
      final playingSub = player.playingStream.listen((p) => isPlaying.value = p);
      player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          player.seek(Duration.zero);
          player.pause();
        }
      });
      return () {
        posSub.cancel();
        playingSub.cancel();
        player.dispose();
      };
    }, [localPath]);

    if (loadError.value) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, size: 24.r, color: colors.fillDestructive),
          SizedBox(width: 8.w),
          Text(
            'Unable to play audio',
            style: context.typographyScaled.medium12.copyWith(
              color: colors.backgroundContentSecondary,
            ),
          ),
        ],
      );
    }

    final progress = duration.value.inMilliseconds > 0
        ? position.value.inMilliseconds / duration.value.inMilliseconds
        : 0.0;

    final fgColor = isOutgoing
        ? colors.fillContentQuaternary
        : colors.fillContentPrimary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          key: const Key('audio_play_pause'),
          onTap: isLoaded.value
              ? () => isPlaying.value ? player.pause() : player.play()
              : null,
          child: Icon(
            isPlaying.value ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: 32.r,
            color: fgColor,
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 3.h,
              thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6.r),
              overlayShape: SliderComponentShape.noOverlay,
              activeTrackColor: fgColor,
              inactiveTrackColor: fgColor.withOpacity(0.3),
              thumbColor: fgColor,
            ),
            child: Slider(
              key: const Key('audio_progress_slider'),
              value: progress.clamp(0.0, 1.0),
              onChanged: isLoaded.value
                  ? (v) => player.seek(
                        Duration(
                          milliseconds:
                              (v * duration.value.inMilliseconds).round(),
                        ),
                      )
                  : null,
            ),
          ),
        ),
        SizedBox(width: 8.w),
        Text(
          _formatDuration(
            isPlaying.value || position.value > Duration.zero
                ? position.value
                : duration.value,
          ),
          key: const Key('audio_duration'),
          style: context.typographyScaled.medium12.copyWith(color: fgColor),
        ),
      ],
    );
  }
}
