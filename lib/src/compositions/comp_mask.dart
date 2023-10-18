import 'package:ffmpeg_cli/ffmpeg_cli.dart';

import 'compositions.dart';

/// Composition that masks the [content] with the given [mask].
///
/// The opaque pixels of the [mask] will retain the pixels of the
/// [content].
class MaskComposition extends ProxyComposition {
  MaskComposition({
    required Composition content,
    required this.mask,
  }) : super(content: content);

  final Composition mask;

  @override
  Future<FfmpegStream> build(FfmpegBuilder builder, CompositionSettings settings) async {
    final alphaMergeFilter = CustomFilter("alphamerge");

    final contentStream = await content.build(builder, settings);
    final maskStream = await mask.build(builder, settings);
    final maskPadDuration = (await content.computeIntrinsicDuration()) - (await mask.computeIntrinsicDuration());

    // TODO: add a check to only pad the mask when its shorter than the content
    final paddedMask = builder.createStream(hasVideo: true, hasAudio: false);
    final outStream = builder.createStream(hasVideo: true, hasAudio: await hasAudio());

    // Create a stream that shows the mask video, and then clones the
    // last frame of the mask for as long as needed to complete the
    // main content. Without this, the main video playback will freeze
    // as soon as the mask video is finished.
    builder.addFilterChain(
      FilterChain(
        inputs: [maskStream.videoOnly],
        filters: [
          TPadFilter(
            stopDuration: maskPadDuration,
            stopMode: 'clone',
          )
        ],
        outputs: [paddedMask.videoOnly],
      ),
    );

    // Create the masked video.
    builder.addFilterChain(
      FilterChain(
        inputs: [contentStream.videoOnly, paddedMask.videoOnly],
        filters: [alphaMergeFilter],
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

  @override
  DiagnosticsNode createDiagnosticsNode() {
    return DiagnosticsNode(name: "Mask");
  }
}
