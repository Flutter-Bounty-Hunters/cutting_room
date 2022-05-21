// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:cutting_room/cutting_room.dart';
import 'package:ffmpeg_cli/ffmpeg_cli.dart';
import 'package:logging/logging.dart';

void main() async {
  CuttingRoomLogs.instance.initAllLogs(Level.FINEST);

  // Compose the desired video and build an FFMPEG command
  // to render it.
  final cliCommand = await CompositionBuilder().build(
    // This is your declarative video composition, much like
    // a widget tree in Flutter.
    SeriesComposition(
      compositions: [
        FullVideoComposition(
          videoPath: "assets/Butterfly-209.mp4",
        ),
        FullVideoComposition(
          videoPath: "assets/bee.mp4",
        ),
      ],
    ),
    size: const Size(1280, 720),
    outputPath: "output/test_render.mp4",
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
