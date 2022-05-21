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
    LayeredComposition(layers: [
      Layer(spans: [
        LayerSpan(
          // Start the main content just before the intro starts
          // transitioning.
          start: const Duration(milliseconds: 1750),
          composition: SeriesComposition(
            compositions: [
              FullVideoComposition(
                videoPath: "assets/Butterfly-209.mp4",
              ),
              FullVideoComposition(
                videoPath: "assets/bee.mp4",
              ),
            ],
          ),
        ),
      ]),
      // Intro + Outro layer, which sits on top of the main content.
      Layer(spans: [
        // Intro span, at the beginning of playback
        LayerSpan(
          start: Duration.zero,
          composition: FullVideoComposition(
            videoPath: "assets/example-intro.mov",
          ),
        ),
        // Outro span, at the end of playback
        LayerSpan(
          // Duration = intro transition + content - outro transition
          // These times are slightly nudged for internal reasons related to
          // transparency. Those issues might be resolved in the future.
          start: const Duration(milliseconds: 1750 + 11800 - 3000),
          composition: FullVideoComposition(
            videoPath: "assets/example-outro.mov",
          ),
        ),
      ]),
    ]),
    size: const Size(1280, 720),
    outputPath: "output/test_render_layered.mp4",
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
