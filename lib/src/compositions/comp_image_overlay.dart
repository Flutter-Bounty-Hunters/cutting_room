import 'package:ffmpeg_cli/ffmpeg_cli.dart';

import 'compositions.dart';

class ImageComposition implements Composition {
  ImageComposition({
    this.imagePath,
  });

  final String? imagePath;

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
      name: 'ImageComposition',
      properties: [
        PropertyNode(name: 'image path: $imagePath'),
      ],
    );
  }

  @override
  Future<FfmpegStream> build(FfmpegBuilder builder, CompositionSettings settings) async {
    print('Image comp. build() - duration: ${settings.duration}');
    final assetStream = builder.addAsset(imagePath!, hasAudio: false);
    final outStream = builder.createStream(hasAudio: false);

    builder.addFilterChain(
      FilterChain(
        inputs: [assetStream.videoOnly],
        filters: [
          TPadFilter(
            stopDuration: settings.duration,
            stopMode: 'clone',
          ),
        ],
        outputs: [outStream.videoOnly],
      ),
    );

    return outStream;
  }
}

class ImageOverlayComposition implements Composition {
  ImageOverlayComposition({
    required Composition content,
    required String imageFilePath,
  })  : _content = content,
        _imageFilePath = imageFilePath;

  final Composition _content;
  final String _imageFilePath;

  @override
  Future<bool> hasVideo() async {
    return true;
  }

  @override
  Future<bool> hasAudio() async {
    return false;
  }

  @override
  Future<Duration> computeIntrinsicDuration() {
    return _content.computeIntrinsicDuration();
  }

  @override
  DiagnosticsNode createDiagnosticsNode() {
    return DiagnosticsNode(
      name: 'ImageOverlayComposition',
      properties: [
        PropertyNode(name: 'image file path: $_imageFilePath'),
      ],
      children: [
        _content.createDiagnosticsNode(),
      ],
    );
  }

  @override
  Future<FfmpegStream> build(FfmpegBuilder builder, CompositionSettings settings) async {
    final contentStream = await _content.build(builder, settings);
    final overlayImageStream = builder.addAsset(_imageFilePath, hasAudio: false);
    final outStream = builder.createStream();

    builder.addFilterChain(
      FilterChain(
        inputs: [contentStream.videoOnly, overlayImageStream.videoOnly],
        filters: [
          const OverlayFilter(),
        ],
        outputs: [outStream.videoOnly],
      ),
    );

    return FfmpegStream(
      videoId: outStream.videoId,
      audioId: contentStream.audioId,
    );
  }
}
