import 'package:ffmpeg_cli/ffmpeg_cli.dart';

import 'compositions.dart';

class FadeComposition extends ProxyComposition {
  FadeComposition({
    required Composition content,
    this.color = const FfmpegColor(0x00000000),
    required this.fadeInDuration,
    required this.fadeOutDuration,
  }) : super(content: content);

  final FfmpegColor color;
  final Duration? fadeInDuration;
  final Duration? fadeOutDuration;

  @override
  DiagnosticsNode createDiagnosticsNode() {
    return DiagnosticsNode(
      name: 'FadeComposition',
      properties: [
        PropertyNode(name: 'color: $color'),
        PropertyNode(name: 'fade in: $fadeInDuration'),
        PropertyNode(name: 'fade out: $fadeOutDuration'),
      ],
      children: [
        content.createDiagnosticsNode(),
      ],
    );
  }

  @override
  Future<FfmpegStream> build(FfmpegBuilder builder, CompositionSettings settings) async {
    final contentStream = await content.build(builder, settings);
    if (!await hasVideo()) {
      // No video to fade. Return original content.
      return contentStream;
    }

    final outStream = builder.createStream(
      hasVideo: await hasVideo(),
      hasAudio: await hasAudio(),
    );

    final alpha = color.isTranslucent ? 1 : 0;
    final fadeIn = fadeInDuration != null && fadeInDuration != Duration.zero
        ? FadeFilter(
            type: 'in',
            alpha: alpha,
            color: color.toCli(),
            startTime: Duration.zero,
            duration: fadeInDuration!,
          )
        : null;
    final fadeOut = fadeOutDuration != null && fadeOutDuration != Duration.zero
        ? FadeFilter(
            type: 'out',
            alpha: alpha,
            color: color.toCli(),
            startTime: settings.duration - fadeOutDuration!,
            duration: fadeOutDuration!,
          )
        : null;
    final filters = [if (fadeIn != null) fadeIn, if (fadeOut != null) fadeOut];

    builder.addFilterChain(
      FilterChain(
        inputs: [contentStream.videoOnly],
        filters: filters,
        outputs: [outStream.videoOnly],
      ),
    );

    if (await hasAudio()) {
      builder.addFilterChain(
        FilterChain(
          inputs: [contentStream.audioOnly],
          filters: [const ACopyFilter()],
          outputs: [outStream.audioOnly],
        ),
      );
    }

    return outStream;
  }
}
