import 'package:ffmpeg_cli/ffmpeg_cli.dart';

import 'compositions.dart';

class LoudnormComposition implements Composition {
  LoudnormComposition({
    this.integratedLoudness,
    this.truePeak,
    this.rangeTarget,
    this.content,
  });

  /// Range is [-70.0, -5.0]. Default is -24.0.
  final double? integratedLoudness;

  /// Range is [-9.0, 0.0].
  final double? truePeak;

  /// Range is [1.0 - 20.0].
  final double? rangeTarget;

  final Composition? content;

  @override
  Future<bool> hasVideo() {
    return content!.hasAudio();
  }

  @override
  Future<bool> hasAudio() async {
    return true;
  }

  @override
  Future<Duration> computeIntrinsicDuration() {
    return content!.computeIntrinsicDuration();
  }

  @override
  Future<VideoSize> computeIntrinsicSize() async {
    return content != null ? await content!.computeIntrinsicSize() : const VideoSize(width: 0, height: 0);
  }

  @override
  DiagnosticsNode createDiagnosticsNode() {
    return DiagnosticsNode(
      name: 'LoudnormComposition',
      properties: [
        PropertyNode(name: 'integrated loudness: $integratedLoudness'),
        PropertyNode(name: 'true peak: $truePeak'),
        PropertyNode(name: 'range target: $rangeTarget'),
      ],
      children: [
        content!.createDiagnosticsNode(),
      ],
    );
  }

  @override
  Future<FfmpegStream> build(FfmpegBuilder builder, CompositionSettings settings) async {
    if (!(await content!.hasAudio())) {
      throw Exception('Tried to build a LoudnormComposition with content that doesn\'t have audio.');
    }

    print('Building loudnorm composition');
    final contentStream = await content!.build(builder, settings);
    final outputStream = builder.createStream(hasVideo: await hasVideo(), hasAudio: true);

    if (await hasVideo()) {
      builder.addFilterChain(
        FilterChain(
          inputs: [contentStream.videoOnly],
          filters: [const CopyFilter()],
          outputs: [outputStream.videoOnly],
        ),
      );
    }

    builder.addFilterChain(
      FilterChain(
        inputs: [contentStream.audioOnly],
        filters: [
          LoudnormFilter(
            integratedLoudness: integratedLoudness,
            truePeak: truePeak,
            rangeTarget: rangeTarget,
          )
        ],
        outputs: [outputStream.audioOnly],
      ),
    );

    return outputStream;
  }
}

// TODO: move this filter into flutter_ffmpeg with other filters
class LoudnormFilter implements Filter {
  LoudnormFilter({
    this.integratedLoudness,
    this.truePeak,
    this.rangeTarget,
  });

  /// Range is [-70.0, -5.0]. Default is -24.0.
  final double? integratedLoudness;

  /// Range is [-9.0, 0.0].
  final double? truePeak;

  /// Range is [1.0 - 20.0].
  final double? rangeTarget;

  @override
  String toCli() {
    final params = [
      if (integratedLoudness != null) 'i=$integratedLoudness',
      if (truePeak != null) 'tp=$truePeak',
      if (rangeTarget != null) 'lra=$rangeTarget',
    ].join(':');

    if (params.isNotEmpty) {
      return ['loudnorm', params].join('=');
    } else {
      return 'loudnorm';
    }
  }
}
