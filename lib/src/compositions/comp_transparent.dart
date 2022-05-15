import 'package:cutting_room/src/assets.dart';
import 'package:ffmpeg_cli/ffmpeg_cli.dart';

import 'compositions.dart';

/// Transparent composition with silent audio.
///
/// Generating silent audio has proven to be a very difficult and buggy
/// thing to do with FFMPEG. To do things in a way that seems to play
/// nice with FFMPEG, this composition combines two different tools to
/// generate silent audio.
///
/// First, one second of audio is taken from "invisible.mov", a transparent
/// and silent video that plays for one second.
///
/// Second, an [anullsrc] audio stream is tacked on after the real audio
/// sample to fill up any remaining time for this composition.
///
/// This approach came from an investigation into why noise was appearing
/// in videos after a silent portion, when that silent portion is the very
/// first thing to appear in a given FFMPEG stream. My theory is that FFMPEG
/// is choosing a very low bitrate, or a weird encoding, or a bad sample size
/// based on the fact that the first audio sample is [anullsrc], and then that
/// same decision is applied to the real video that follows, which degrades
/// the video's audio.
///
/// Therefore, by playing 1 second (or any length) of real, silent audio, and then
/// introducing [anullsrc] after that, we convince FFMPEG to use audio settings
/// that are good enough for video. So that's the approach taken with this
/// composition when it comes to silent audio.
///
/// This is all a theory based on debugging. I'm not sure about the root cause,
/// but the silent audio + [anullsrc] seems to solve the problem.
class TransparentComposition implements Composition {
  TransparentComposition({bool hasVideo = true, bool hasAudio = true, required Duration duration})
      : assert(
            duration >= const Duration(seconds: 1),
            'Can\'t render less than 1 second of silence because '
            'TransparentComposition uses a 1-second silent video at the beginning of its stream'),
        _hasVideo = hasVideo,
        _hasAudio = hasAudio,
        _duration = duration;

  final bool _hasVideo;
  final bool _hasAudio;
  final Duration _duration;

  @override
  Future<bool> hasVideo() async {
    return _hasVideo;
  }

  @override
  Future<bool> hasAudio() async {
    return _hasAudio;
  }

  @override
  Future<Duration> computeIntrinsicDuration() async {
    return _duration;
  }

  @override
  Future<VideoSize> computeIntrinsicSize() async => const VideoSize(width: 0, height: 0);

  @override
  DiagnosticsNode createDiagnosticsNode() {
    return DiagnosticsNode(
      name: 'TransparentComposition',
      properties: [
        PropertyNode(name: 'has video: $_hasVideo'),
        PropertyNode(name: 'has audio: $_hasAudio'),
        PropertyNode(name: 'duration: $_duration'),
      ],
    );
  }

  @override
  Future<FfmpegStream> build(FfmpegBuilder builder, CompositionSettings settings) async {
    final compStream = builder.createStream(hasVideo: _hasVideo, hasAudio: _hasAudio);

    if (_hasVideo) {
      final absoluteBitmapPath = Assets.instance.getAssetPath('empty.png');

      final emptyVideoStream = builder.addAsset(absoluteBitmapPath, hasAudio: false);
      builder.addFilterChain(FilterChain(
        inputs: [emptyVideoStream.videoOnly],
        filters: [
          SetSarFilter(sar: '1/1'),
          TPadFilter(
            stopDuration: _duration,
            stopMode: 'clone',
          ),
        ],
        outputs: [compStream.videoOnly],
      ));
    }

    if (_hasAudio) {
      final emptyVideoAbsolutePath = Assets.instance.getAssetPath('invisible.mov');
      final emptyVideoStream = builder.addAsset(emptyVideoAbsolutePath, hasAudio: true);

      final nullAudioStream = builder.addNullAudio();

      builder.addFilterChain(
        FilterChain(
          inputs: [emptyVideoStream.audioOnly, nullAudioStream.audioOnly],
          filters: [
            ConcatFilter(segmentCount: 2, outputVideoStreamCount: 0, outputAudioStreamCount: 1),
            ATrimFilter(duration: _duration),
          ],
          outputs: [compStream.audioOnly],
        ),
      );
    }

    return compStream;
  }
}
