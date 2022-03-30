// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:cinema/cutting_room.dart';
import 'package:ffmpeg_cli/ffmpeg_cli.dart';

void main() async {
  // Compose the desired video.
  final comp = SeriesComposition(compositions: [
    FullVideoComposition(
      videoPath: "assets/Butterfly-209.mp4",
    ),
    FullVideoComposition(
      videoPath: "assets/bee.mp4",
    ),
  ]);

  // Construct the FFMPEG filter graph from the composition tree.
  //
  // The filter graph will become a bunch of complicated arguments
  // that are given to FFMPEG in the CLI command.
  final builder = FfmpegBuilder();
  final outputStream = await comp.build(
    builder,
    CompositionSettings(
      videoDimensions: const Size(1920, 1080),
      duration: await comp.computeIntrinsicDuration(),
    ),
  );

  // Create the FFMPEG command so we can run it.
  final cliCommand = builder.build(
    args: [
      // Set the FFMPEG log level.
      CliArg.logLevel(LogLevel.info),
      // Our composition has video and audio. Map those streams to
      // FFMPEG's output.
      CliArg(name: 'map', value: outputStream.videoId!),
      CliArg(name: 'map', value: outputStream.audioId!),
      // TODO: need to generalize knowledge of when to use vsync -2
      const CliArg(name: 'vsync', value: '2'),
    ],
    mainOutStream: outputStream,
    outputFilepath: "output/test_render.mp4",
  );

  print('');
  print('Expected command input: ');
  print(cliCommand.expectedCliInput());
  print('');

  // Run the FFMPEG command.
  final process = await Ffmpeg().run(cliCommand);

  // Pipe the process output to the Dart console.
  process.stderr.transform(utf8.decoder).listen((data) {
    print(data);
  });

  // Allow the user to respond to FFMPEG queries, such as file overwrite
  // confirmations.
  stdin.pipe(process.stdin);

  await process.exitCode;
  print('DONE');
}
