import 'package:ffmpeg_cli/ffmpeg_cli.dart';

import 'comp_fade.dart';
import 'compositions.dart';

/// Concatenates all the given `compositions` into a single `Composition`.
class SeriesComposition implements Composition {
  SeriesComposition({
    Duration? transitionDuration,
    FfmpegColor? transitionColor,
    bool fadeInFirstSegment = false,
    bool fadeOutLastSegment = false,
    required List<Composition?> compositions,
  })  : _transitionDuration = transitionDuration,
        _transitionColor = transitionColor,
        _fadeInFirstSegment = fadeInFirstSegment,
        _fadeOutLastSegment = fadeOutLastSegment,
        _compositions = compositions;

  final Duration? _transitionDuration;
  final bool _fadeInFirstSegment;
  final bool _fadeOutLastSegment;
  final FfmpegColor? _transitionColor;
  final List<Composition?> _compositions;

  @override
  Future<bool> hasVideo() async {
    for (final composition in _compositions) {
      if (await composition!.hasVideo()) {
        return true;
      }
    }

    return false;
  }

  @override
  Future<bool> hasAudio() async {
    for (final composition in _compositions) {
      if (await composition!.hasAudio()) {
        return true;
      }
    }

    return false;
  }

  @override
  Future<Duration> computeIntrinsicDuration() async {
    Duration duration = Duration.zero;
    for (final composition in _compositions) {
      duration += await composition!.computeIntrinsicDuration();
    }
    return duration;
  }

  @override
  DiagnosticsNode createDiagnosticsNode() {
    return DiagnosticsNode(
      name: 'SeriesComposition',
      properties: [
        PropertyNode(name: 'transition duration: $_transitionColor'),
        PropertyNode(name: 'transition color: $_transitionColor'),
        PropertyNode(name: 'fade in first: $_fadeInFirstSegment'),
        PropertyNode(name: 'fade out last: $_fadeOutLastSegment'),
      ],
      children: [
        for (final composition in _compositions) composition!.createDiagnosticsNode(),
      ],
    );
  }

  @override
  Future<FfmpegStream> build(FfmpegBuilder builder, CompositionSettings settings) async {
    // TODO: trim to match settings duration
    // TODO: handle possibility of just audio or just video

    final inputs = <FfmpegStream>[];
    for (final composition in _compositions) {
      final segmentSettings = settings.copyWith(duration: await composition!.computeIntrinsicDuration());
      final inputStream = await _buildSegmentStream(
        builder,
        segmentSettings,
        composition,
        composition == _compositions.first,
        composition == _compositions.last,
      );
      inputs.add(inputStream);
    }

    final outStream = builder.createStream();

    builder.addFilterChain(
      FilterChain(
        inputs: inputs,
        filters: [
          ConcatFilter(
            segmentCount: _compositions.length,
            outputAudioStreamCount: 1,
            outputVideoStreamCount: 1,
          ),
        ],
        outputs: [outStream],
      ),
    );

    return outStream;
  }

  Future<FfmpegStream> _buildSegmentStream(FfmpegBuilder builder, CompositionSettings settings,
      Composition? segmentComposition, bool isFirst, bool isLast) async {
    if (_transitionDuration == null || _transitionColor == null) {
      return await segmentComposition!.build(builder, settings);
    }

    // Apply transition fades.
    final fadedComposition = FadeComposition(
      color: _transitionColor!,
      fadeInDuration: !isFirst || _fadeInFirstSegment ? _transitionDuration! : null,
      fadeOutDuration: !isLast || _fadeOutLastSegment ? _transitionDuration! : null,
      content: segmentComposition!,
    );

    return fadedComposition.build(builder, settings);
  }
}
