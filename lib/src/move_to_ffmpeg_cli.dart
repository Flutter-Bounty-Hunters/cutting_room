import 'package:ffmpeg_cli/ffmpeg_cli.dart';

Future<VideoSize?> probeVideoSize(String videoPath) async {
  final videoDetails = await Ffprobe.run(videoPath);
  if (videoDetails.streams == null || videoDetails.streams!.isEmpty) {
    // No stream data. Even audio files should have streams, so this
    // seems strange.
    // ignore: avoid_print
    print("WARNING: Tried to compute intrinsic size for a file that has no streams: $videoPath");
    return null;
  }

  Stream? videoStream;
  for (final stream in videoDetails.streams!) {
    if (stream.codecType == "video") {
      videoStream = stream;
      break;
    }
  }
  if (videoStream == null) {
    // Couldn't find a video stream. Maybe this is an audio file?
    // ignore: avoid_print
    print("WARNING: Tried to compute intrinsic size for a file that has no video stream: $videoPath");
    return null;
  }

  if (videoStream.width == null || videoStream.height == null) {
    // ignore: avoid_print
    print(
        "WARNING: Tried to compute intrinsic size for a video, but its width and/or height are missing: width - ${videoStream.width}, height - ${videoStream.height}");
    return null;
  }

  return VideoSize(
    width: videoStream.width!,
    height: videoStream.height!,
  );
}

extension VideoSizeExtensions on VideoSize {
  VideoSize expandTo(VideoSize other) {
    return VideoSize(
      width: width > other.width ? width : other.width,
      height: height > other.height ? height : other.height,
    );
  }
}
