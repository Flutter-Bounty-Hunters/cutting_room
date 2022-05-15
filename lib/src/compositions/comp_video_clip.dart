import 'package:collection/collection.dart' show IterableExtension;
import 'package:cutting_room/src/move_to_ffmpeg_cli.dart';
import 'package:cutting_room/src/timing.dart';
import 'package:ffmpeg_cli/ffmpeg_cli.dart';

import 'compositions.dart';

/// A clip from a larger video, which spans from `start` to `end`.
class VideoClipComposition implements Composition {
  VideoClipComposition({
    String? videoPath,
    List<TimeSpan>? spans,
  })  : assert(videoPath != null && videoPath.isNotEmpty),
        assert(spans != null && spans.isNotEmpty),
        _videoPath = videoPath,
        _spans = spans {
    // Ensure that all spans before the final span include an
    // explicit end time.
    for (int i = 0; i < _spans!.length - 1; ++i) {
      if (_spans![i].end == null) {
        throw Exception('A span is missing an end time. Only the final span can omit the end time. Span: '
            '${_spans![i]}');
      }
    }
  }

  // TODO: make the path non-null
  final String? _videoPath;
  // TODO: make the spans non-null, even if they're empty
  final List<TimeSpan>? _spans;

  @override
  Future<bool> hasVideo() async {
    final videoDetails = await Ffprobe.run(_videoPath!);
    return videoDetails.streams!.firstWhereOrNull((element) => (element.codecType ?? '') == 'video') != null;
  }

  @override
  Future<bool> hasAudio() async {
    final videoDetails = await Ffprobe.run(_videoPath!);
    return videoDetails.streams!.firstWhereOrNull((element) => (element.codecType ?? '') == 'audio') != null;
  }

  @override
  Future<Duration> computeIntrinsicDuration() async {
    Duration videoDuration = Duration.zero;
    if (_spans!.last.end == null) {
      final videoDetails = await Ffprobe.run(_videoPath!);
      videoDuration = videoDetails.format!.duration!;
    }

    Duration accumulation = Duration.zero;
    for (final span in _spans!) {
      // Note: the constructor includes a check to ensure that no spans
      //       before the final span have a null end time. If the end
      //       value is null, it must be the final span, in which case
      //       using the natural video duration is acceptable.
      final end = span.end ?? videoDuration;
      accumulation += (end - span.start);
    }
    return accumulation;
  }

  @override
  Future<VideoSize> computeIntrinsicSize() async {
    final videoSize = await probeVideoSize(_videoPath!);
    return videoSize ?? const VideoSize(width: 0, height: 0);
  }

  @override
  DiagnosticsNode createDiagnosticsNode() {
    return DiagnosticsNode(
      name: 'VideoClipComposition',
      properties: [
        PropertyNode(name: 'video path: $_videoPath'),
        for (final span in _spans!) PropertyNode(name: span.toString()),
      ],
    );
  }

  @override
  Future<FfmpegStream> build(FfmpegBuilder builder, CompositionSettings settings) async {
    print("Building VideoClipComposition: $_videoPath");
    // TODO: trim clip to match settings.duration

    final assetStream = builder.addAsset(_videoPath!);
    final outStreams = <FfmpegStream>[];

    final hasVideo = await this.hasVideo();
    final hasAudio = await this.hasAudio();
    Duration accumulatedTime = Duration.zero;
    for (int i = 0; i < _spans!.length; ++i) {
      if (accumulatedTime >= settings.duration) {
        // We've accumulated as much video as we're allowed to, for
        // the given build settings. We're done.
        break;
      }
      final remainingTime = settings.duration - accumulatedTime;

      final span = _spans![i];
      Duration? endTime = span.end;
      endTime ??= await computeIntrinsicDuration() + span.start;
      endTime = (endTime - span.start) <= remainingTime ? endTime : (span.start + remainingTime);
      print("Building segment $i, selecting clip end time:");
      print(" - accumulated time: $accumulatedTime");
      print(" - remaining time: $remainingTime");
      print(" - start time: ${span.start}");
      print(" - scheduled end time: ${span.end}");
      print(" - chosen end time: $endTime");

      final outStream = builder.createStream(
        hasVideo: hasVideo,
        hasAudio: hasAudio,
      );
      outStreams.add(outStream);

      if (hasVideo) {
        final resizeFilters = await _createResizeFiltersIfNeeded(settings);

        print(" - adding segment trim filter: ${span.start} -> $endTime");
        builder.addFilterChain(
          FilterChain(
            inputs: [assetStream.videoOnly],
            filters: [
              if (resizeFilters.isNotEmpty) ...resizeFilters,
              TrimFilter(
                start: span.start,
                end: endTime,
              ),
              const SetPtsFilter.startPts(),
            ],
            outputs: [outStream.videoOnly],
          ),
        );
      }

      if (hasAudio) {
        builder.addFilterChain(
          FilterChain(
            inputs: [assetStream.audioOnly],
            filters: [
              ATrimFilter(
                start: span.start,
                end: endTime,
              ),
              const ASetPtsFilter.startPts(),
            ],
            outputs: [outStream.audioOnly],
          ),
        );
      }
    }

    if (_spans!.length > 1) {
      final concatOutStream = builder.createStream();
      builder.addFilterChain(
        FilterChain(
          inputs: outStreams.fold(
            <FfmpegStream>[],
            (inputs, outStream) => List.from([...inputs, outStream.videoId, outStream.audioId]),
          ),
          filters: [
            ConcatFilter(
              segmentCount: outStreams.length,
              outputVideoStreamCount: 1,
              outputAudioStreamCount: 1,
            )
          ],
          outputs: [concatOutStream],
        ),
      );

      return concatOutStream;
    } else {
      return outStreams.last;
    }
  }

  Future<List<Filter>> _createResizeFiltersIfNeeded(CompositionSettings settings) async {
    final videoInfo = await Ffprobe.run(_videoPath!);
    final videoStream = videoInfo.streams!.firstWhereOrNull((element) => element.codecType == 'video');
    if (videoStream == null) {
      throw Exception("Couldn't find video stream for VideoClipComposition.");
    }

    // TODO: I commented this out to get AlignComposition working, to avoid auto
    //       scaling the content that I want to center. Bring this back in some
    //       form that's useful
    // if (videoStream.width != contentDimensions.width || videoStream.height != contentDimensions.height) {
    //   print(
    //       'WARNING: Video source "$_videoPath" has incompatible dimensions (${videoStream.width}x${videoStream.height}). Resizing and cropping to ${contentDimensions.width}x${contentDimensions.height}');
    //
    //   final finalSize = settings.videoDimensions;
    //   final scaleFilter = (finalSize.width / finalSize.height) > (contentDimensions.width / contentDimensions.height)
    //       ? ScaleFilter(
    //           width: finalSize.width as int?,
    //           height: -1,
    //         )
    //       : ScaleFilter(
    //           width: -1,
    //           height: finalSize.height as int?,
    //         );
    //   final cropFilter = CropFilter(width: finalSize.width as int, height: finalSize.height as int);
    //   final setSarFilter = SetSarFilter(sar: '1/1');
    //
    //   return [
    //     scaleFilter,
    //     cropFilter,
    //     setSarFilter,
    //   ];
    // }
    return [];
  }

  @override
  String toString() => "[VideoClipComposition] - $_videoPath";
}
