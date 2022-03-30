import 'package:cutting_room/src/assets.dart';
import 'package:ffmpeg_cli/ffmpeg_cli.dart';

import 'compositions.dart';

// TODO: figure out how to generate a color composition that plays nice
//       with video timing. Currently it causes video rendering to go
//       on forever. That's why white and black use associated PNGs.
class ColorComposition implements Composition {
  ColorComposition({
    required FfmpegColor color,
  }) : _color = color;

  final FfmpegColor _color;

  @override
  Future<bool> hasVideo() async {
    return true;
  }

  @override
  Future<bool> hasAudio() async {
    return false;
  }

  @override
  Future<Duration> computeIntrinsicDuration() async {
    return Duration.zero;
  }

  @override
  DiagnosticsNode createDiagnosticsNode() {
    return DiagnosticsNode(
      name: 'ColorComposition',
      properties: [
        PropertyNode(name: 'color: $_color'),
      ],
    );
  }

  @override
  Future<FfmpegStream> build(FfmpegBuilder builder, CompositionSettings settings) async {
    print('ColorComposition duration: ${settings.duration}');

    final colorStream = builder.addVideoVirtualDevice(
      "color=color=${_color.toCli()}:size=${settings.videoDimensions.width}x${settings.videoDimensions.height}:rate=30:duration='${settings.duration.inMilliseconds / 1000}'",
    );
    final audioStream = builder.addNullAudio();
    final colorWithDurationStream = builder.createStream(hasVideo: true, hasAudio: true);

    builder.addFilterChain(
      FilterChain(
        inputs: [colorStream.videoOnly],
        filters: [FpsFilter(fps: 30), TrimFilter(duration: settings.duration)],
        outputs: [colorWithDurationStream.videoOnly],
      ),
    );

    builder.addFilterChain(
      FilterChain(
        inputs: [audioStream.audioOnly],
        filters: [const ANullFilter()],
        outputs: [colorWithDurationStream.audioOnly],
      ),
    );

    return colorWithDurationStream;
  }
}

class ColorBitmapComposition implements Composition {
  ColorBitmapComposition.white({
    bool hasAudio = true,
  })  : _bitmapFileName = 'white.png',
        _hasAudio = hasAudio;

  ColorBitmapComposition.black({
    bool hasAudio = true,
  })  : _bitmapFileName = 'black.png',
        _hasAudio = hasAudio;

  ColorBitmapComposition._({required String bitmapPath, bool hasAudio = true})
      : _bitmapFileName = bitmapPath,
        _hasAudio = hasAudio;

  final bool _hasAudio;
  final String _bitmapFileName;

  @override
  Future<bool> hasVideo() async {
    return true;
  }

  @override
  Future<bool> hasAudio() async {
    return _hasAudio;
  }

  @override
  Future<Duration> computeIntrinsicDuration() async {
    return Duration.zero;
  }

  @override
  DiagnosticsNode createDiagnosticsNode() {
    return DiagnosticsNode(
      name: 'ColorBitmapComposition',
      properties: [
        PropertyNode(name: 'file name: $_bitmapFileName'),
      ],
    );
  }

  @override
  Future<FfmpegStream> build(FfmpegBuilder builder, CompositionSettings settings) async {
    print('Building ColorComposition with bitmap: $_bitmapFileName');
    final compStream = builder.createStream(hasVideo: true, hasAudio: _hasAudio);

    final absoluteBitmapPath = Assets.instance.getAssetPath(_bitmapFileName);

    final colorVideoStream = builder.addAsset(absoluteBitmapPath, hasAudio: false);
    builder.addFilterChain(FilterChain(
      inputs: [colorVideoStream.videoOnly],
      filters: [
        SetSarFilter(sar: '1/1'),
        TPadFilter(
          stopDuration: settings.duration,
          stopMode: 'clone',
        ),
      ],
      outputs: [compStream.videoOnly],
    ));

    if (_hasAudio) {
      final nullAudioStream = builder.addNullAudio();
      builder.addFilterChain(
        FilterChain(
          inputs: [nullAudioStream.audioOnly],
          filters: [ATrimFilter(duration: settings.duration)],
          outputs: [compStream.audioOnly],
        ),
      );
    }

    return compStream;
  }
}
