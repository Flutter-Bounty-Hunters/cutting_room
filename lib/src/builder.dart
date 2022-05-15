import 'package:ffmpeg_cli/ffmpeg_cli.dart';

import 'compositions/compositions.dart';

/// Builds video [Compositions] into [FfmpegCommand]s that can be run
/// in a process to render the desired video.
class CompositionBuilder {
  CompositionBuilder({
    this.logLevel = LogLevel.warning,
  });

  final LogLevel logLevel;

  // TODO: add FFMPEG vsync property

  /// Builds an [FfmpegCommand] that renders the given [composition].
  Future<FfmpegCommand> build(Composition composition) async {
    final ffmpegBuilder = FfmpegBuilder();
    final outputStream = await composition.build(
      ffmpegBuilder,
      CompositionSettings(
        videoDimensions: const Size(1920, 1080),
        duration: await composition.computeIntrinsicDuration(),
      ),
    );

    return ffmpegBuilder.build(
      args: [
        CliArg.logLevel(logLevel),
        CliArg(name: 'map', value: outputStream.videoId!),
        CliArg(name: 'map', value: outputStream.audioId!),
        // TODO: need to generalize knowledge of when to use vsync -2
        const CliArg(name: 'vsync', value: '2'),
      ],
      mainOutStream: outputStream,
      outputFilepath: "output/test_render.mp4",
    );
  }
}
