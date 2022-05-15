import 'package:collection/collection.dart' show IterableExtension;
import 'package:cutting_room/src/move_to_ffmpeg_cli.dart';
import 'package:ffmpeg_cli/ffmpeg_cli.dart';

import 'compositions.dart';

/// The full video at `videoPath`.
class FullVideoComposition implements Composition {
  FullVideoComposition({
    required String videoPath,
    bool hasTransparency = false,
    Duration? audioFadeInDuration,
    Duration? audioFadeOutDuration,
  })  : _videoPath = videoPath,
        _hasTransparency = hasTransparency,
        _audioFadeInDuration = audioFadeInDuration,
        _audioFadeOutDuration = audioFadeOutDuration;

  final String _videoPath;
  final bool _hasTransparency;
  final Duration? _audioFadeInDuration;
  final Duration? _audioFadeOutDuration;

  @override
  Future<bool> hasVideo() async {
    final videoDetails = await Ffprobe.run(_videoPath);
    return videoDetails.streams!.firstWhereOrNull((element) => (element.codecType ?? '') == 'video') != null;
  }

  @override
  Future<bool> hasAudio() async {
    final videoDetails = await Ffprobe.run(_videoPath);
    return videoDetails.streams!.firstWhereOrNull((element) => (element.codecType ?? '') == 'audio') != null;
  }

  @override
  Future<Duration> computeIntrinsicDuration() async {
    final videoDetails = await Ffprobe.run(_videoPath);
    return videoDetails.format!.duration!;
  }

  @override
  Future<VideoSize> computeIntrinsicSize() async {
    final videoSize = await probeVideoSize(_videoPath);
    return videoSize ?? const VideoSize(width: 0, height: 0);
  }

  @override
  DiagnosticsNode createDiagnosticsNode() {
    return DiagnosticsNode(
      name: 'FullVideoComposition',
      properties: [
        PropertyNode(name: 'video: $_videoPath'),
        PropertyNode(name: 'audio fade in: $_audioFadeInDuration'),
        PropertyNode(name: 'audio fade out: $_audioFadeOutDuration'),
      ],
    );
  }

  @override
  Future<FfmpegStream> build(FfmpegBuilder builder, CompositionSettings settings) async {
    print('Building FullVideoComposition');
    // TODO: trim to limit duration to given settings.duration.

    final hasVideo = await this.hasVideo();
    final hasAudio = await this.hasAudio();
    final assetStream = builder.addAsset(_videoPath, hasVideo: hasVideo, hasAudio: hasAudio);

    if (hasAudio && (_audioFadeInDuration != null || _audioFadeOutDuration != null)) {
      FfmpegStream? fadedStream = assetStream;

      // Apply a fade-in.
      if (_audioFadeInDuration != null) {
        final fadeInStream = builder.createStream(hasVideo: hasVideo, hasAudio: true);

        builder.addFilterChain(
          FilterChain(
            inputs: [fadedStream.audioOnly],
            filters: [
              AFadeFilter(
                type: 'in',
                startTime: Duration.zero,
                duration: _audioFadeInDuration!,
              ),
            ],
            outputs: [fadeInStream.audioOnly],
          ),
        );

        fadedStream = fadeInStream;
      }

      // Apply a fade-out.
      if (_audioFadeOutDuration != null) {
        final fadeOutStream = builder.createStream(hasVideo: hasVideo, hasAudio: true);

        builder.addFilterChain(
          FilterChain(
            inputs: [fadedStream.audioOnly],
            filters: [
              AFadeFilter(
                type: 'out',
                startTime: settings.duration - _audioFadeOutDuration!,
                duration: _audioFadeOutDuration!,
              ),
            ],
            outputs: [fadeOutStream.audioOnly],
          ),
        );

        fadedStream = fadeOutStream;
      }

      // Copy the video to the new output stream.
      builder.addFilterChain(
        FilterChain(
          inputs: [assetStream.videoOnly],
          filters: [const NullFilter()],
          outputs: [fadedStream.videoOnly],
        ),
      );

      return fadedStream;
    } else {
      print('Full video does not need editing. Returning the asset.');
      return assetStream;
    }
  }
}
