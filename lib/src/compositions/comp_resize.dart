import 'package:ffmpeg_cli/ffmpeg_cli.dart';

import 'compositions.dart';

class ResizeComposition extends ProxyComposition {
  ResizeComposition({
    required Composition content,
    this.contentDimensions,
  }) : super(content: content);

  final Size? contentDimensions;

  @override
  DiagnosticsNode createDiagnosticsNode() {
    return DiagnosticsNode(
      name: 'ResizeComposition',
      properties: [
        PropertyNode(name: 'content dimensions: $contentDimensions'),
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
      // No video to resize. Return original content.
      return contentStream;
    }

    final outStream = builder.createStream(
      hasVideo: await hasVideo(),
      hasAudio: await hasAudio(),
    );

    final finalSize = settings.videoDimensions;
    final scaleFilter = (finalSize.width / finalSize.height) > (contentDimensions!.width / contentDimensions!.height)
        ? ScaleFilter(
            width: finalSize.width as int?,
            height: -1,
          )
        : ScaleFilter(
            width: -1,
            height: finalSize.height as int?,
          );
    final cropFilter = CropFilter(width: finalSize.width as int, height: finalSize.height as int);
    final setSarFilter = SetSarFilter(sar: '1/1');

    builder.addFilterChain(
      FilterChain(
        inputs: [contentStream.videoOnly],
        filters: [scaleFilter, cropFilter, setSarFilter],
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
