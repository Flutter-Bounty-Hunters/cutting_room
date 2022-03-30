import 'package:ffmpeg_cli/ffmpeg_cli.dart';

import 'compositions.dart';

/// Pads the front and back of a composition that only takes up
/// part of the total available time.
class PartialComposition implements Composition {
  const PartialComposition({
    required Composition content,
    required Duration duration,
    required Duration start,
    required Duration end,
  })  : _content = content,
        _duration = duration,
        _start = start,
        _end = end;

  final Composition _content;
  final Duration _duration;
  final Duration _start;
  final Duration _end;

  @override
  Future<bool> hasVideo() async {
    return await _content.hasVideo();
  }

  @override
  Future<bool> hasAudio() async {
    return await _content.hasAudio();
  }

  @override
  Future<Duration> computeIntrinsicDuration() async {
    return _duration + _start;
  }

  @override
  DiagnosticsNode createDiagnosticsNode() {
    return DiagnosticsNode(
      name: 'PartialComposition',
      properties: [
        PropertyNode(name: 'duration: $_duration'),
        PropertyNode(name: 'start: $_start'),
        PropertyNode(name: 'end: $_end'),
      ],
      children: [
        _content.createDiagnosticsNode(),
      ],
    );
  }

  @override
  Future<FfmpegStream> build(FfmpegBuilder builder, CompositionSettings settings) async {
    // TODO: trim based on settings duration

    final contentStream = await _content.build(builder, settings);
    final outStream = builder.createStream();

    builder.addFilterChain(
      FilterChain(
        inputs: [contentStream.videoOnly],
        filters: [
          TPadFilter(
            startDuration: _start,
            stopDuration: _end,
            color: '0x00000000',
          ),
        ],
        outputs: [outStream.videoOnly],
      ),
    );

    // TODO: add if-statement to check for presence of audio
    builder.addFilterChain(
      FilterChain(
        inputs: [contentStream.audioOnly],
        filters: [
          ADelayFilter(
            delay: _start,
          ),
        ],
        outputs: [outStream.audioOnly],
      ),
    );

    return outStream;
  }
}
