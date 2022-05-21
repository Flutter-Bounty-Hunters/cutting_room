import 'package:cutting_room/src/move_to_ffmpeg_cli.dart';
import 'package:ffmpeg_cli/ffmpeg_cli.dart';
import 'comp_transparent.dart';
import 'compositions.dart';

/// Composition that mimics the kind of video layout achieved in
/// programs like Premier and After Effects.
///
/// A [LayeredComposition] is comprised of 1 or more [Layer]s. [Layer]s
/// are stacked on top of one another in the z-index of the screen.
///
/// Each [Layer] may contain any number of [LayerSpan]s that take up
/// time within the [Layer]. [LayerSpan]s may not overlap each other,
/// but empty space is permitted between [LayerSpan]s, allowing for
/// easy and precise positioning of a given clip in time. Whatever
/// empty space exists is in a [Layer] is automatically filled with
/// [TransparentComposition]s because FFMPEG requires that all time
/// be filled.
class LayeredComposition implements Composition {
  LayeredComposition({
    required this.layers,
  });

  final List<Layer> layers;

  // TODO: infer total length from layers
  // TODO: some comps may have implied start/end times that match the comp,
  //       throw an error if all comps are implied, because that would
  //       prevent computation of a real composition length.

  @override
  Future<bool> hasVideo() async {
    for (final layer in layers) {
      if (await layer.hasVideo()) {
        return true;
      }
    }
    return false;
  }

  @override
  Future<bool> hasAudio() async {
    for (final layer in layers) {
      if (await layer.hasAudio()) {
        return true;
      }
    }
    return false;
  }

  @override
  Future<Duration> computeIntrinsicDuration() async {
    Duration endTime = Duration.zero;

    for (final layer in layers) {
      final layerEndTime = await layer.computeEndTime();
      if (layerEndTime > endTime) {
        endTime = layerEndTime;
      }
    }

    return endTime;
  }

  @override
  Future<VideoSize> computeIntrinsicSize() async {
    VideoSize largestSize = const VideoSize(width: 0, height: 0);

    for (final layer in layers) {
      for (final span in layer.spans) {
        final spanVideoSize = await span.composition.computeIntrinsicSize();
        largestSize = largestSize.expandTo(spanVideoSize);
      }
    }

    return largestSize;
  }

  @override
  DiagnosticsNode createDiagnosticsNode() {
    final children = <DiagnosticsNode>[];
    for (final layer in layers) {
      children.add(layer.createDiagnosticsNode());
    }

    return DiagnosticsNode(
      name: 'LayeredComposition',
      children: children,
    );
  }

  @override
  Future<FfmpegStream> build(FfmpegBuilder builder, CompositionSettings settings) async {
    if (layers.isEmpty) {
      throw Exception('LayerComposition needs to have at least 1 layer to build()');
    }

    if (layers.length == 1) {
      // There is only 1 layer. No need to use overlays. Return the layer's
      // FFMPEG stream, directly.
      return await layers.first.build(builder, settings);
    }

    // Stack the layers in overlay filters
    final audioStreamIds = <FfmpegStream>[];

    FfmpegStream previousLayerStream = await layers.first.build(builder, settings);
    if (await layers.first.hasAudio()) {
      audioStreamIds.add(previousLayerStream.audioOnly);
    }

    for (int i = 1; i < layers.length; ++i) {
      // TODO: Done:
      //      1. The null source video needs to use a transparent format.
      //           - Tried nullsrc but it's always green
      //           - Tried color but couldn't get it to be transparent
      //           - Went with a blank PNG image that's 1920x1080
      //             - Issue: image has to be the right size
      //             - Issue: have to manually setsar to 1/1
      //      2. The image overlay only lasts a moment. It should last as
      //         long as the parent composition. This may require adding
      //         a parameter to all build() methods.
      //      3. Add multiple image overlays and ensure that works.
      //      4. Add the subscribe video overlay.
      //      5. Render 2 of these steps back to back.
      //      6. Add transitions between the steps with configurable colors
      //      7. Use layers to solve the overlapping outro problem
      //      8. Use layers to solve the overlapping intro problem
      //      9. Multiply volume up for all amix uses
      //      * Move all current raw filters to superdeclarative_ffmpeg
      //      * Replace current video steps with shorter steps for faster test rendering
      //      * Remove superfluous compositions like overlap intro/outro and temp overlay

      // TODO:
      //       * Put white.png, black.png, and empty.png in a place that can be used
      //         by bin/ scripts
      //       * Combine FullVideoComposition and VideoClipComposition
      //       * Cleanup demos
      //       * Name composition streams based on what they are: empty, color, etc.
      //       ...eventually...
      //       *. Audit all compositions to ensure they handle:
      //          - CompositionSettings duration
      //          - Presence/absence of video/audio streams
      //       *. What is going wrong with the audio when the video begins
      //          with anullsrc?
      //       *. Why does nullsrc specify additional video size parameters in
      //          in the stream configuration? And why does it cause a slightly
      //          different frame rate?
      //       *. Using "color" virtual device at the end of a Layer with 2+
      //          layers causes the video encoding to go on forever. Why? I had
      //          to switch to a black PNG, like the empty PNG solution.
      //       *. Can we make any adjustments to lower file size without losing
      //          quality?
      //       *. Can we make any adjustments to get faster rendering without
      //          losing quality? Maybe a different container, or codecs?
      //       *. Support multiple video and audio streams to avoid future
      //          compatibility with FFMPEG and unusual videos and audio

      final newLayerStream = await layers[i].build(builder, settings);
      final newLayerHasAudio = await layers[i].hasAudio();
      if (newLayerHasAudio) {
        audioStreamIds.add(newLayerStream.audioOnly);
      }

      final newCompStream = builder.createStream(
        hasVideo: await layers[i].hasVideo(),
        // Only the final stream might have audio. All the streams before
        // the final one are just video overlay streams. The final stream
        // is the output for this entire composition and it needs to mix
        // all the audio, if there is any.
        hasAudio: i == layers.length - 1 ? audioStreamIds.isNotEmpty : false,
      );

      if (await layers[i].hasVideo()) {
        builder.addFilterChain(
          FilterChain(
            inputs: [previousLayerStream.videoOnly, newLayerStream.videoOnly],
            filters: [const OverlayFilter()],
            outputs: [newCompStream.videoOnly],
          ),
        );
      }

      previousLayerStream = newCompStream;
    }

    if (audioStreamIds.length >= 2) {
      builder.addFilterChain(
        FilterChain(
          inputs: audioStreamIds,
          filters: [
            AMixFilter(inputCount: audioStreamIds.length),
            VolumeFilter(volume: 1.0 * audioStreamIds.length),
          ],
          outputs: [previousLayerStream.audioOnly],
        ),
      );
    } else if (audioStreamIds.length == 1) {
      builder.addFilterChain(
        FilterChain(
          inputs: [audioStreamIds.first],
          filters: [
            const ACopyFilter(),
          ],
          outputs: [previousLayerStream.audioOnly],
        ),
      );
    }

    return previousLayerStream;
  }
}

/// Single layer within a [LayeredComposition], comprised of 1+
/// [LayerSpan]s, which render given video and audio during the
/// duration of those spans.
///
/// [LayerSpan]s within a single [Layer] are not allowed to overlap,
/// but [LayerSpans] can have empty time in between.
class Layer {
  Layer({
    required this.spans,
  });

  final List<LayerSpan> spans;

  Future<bool> hasVideo() async {
    for (final span in spans) {
      if (await span.composition.hasVideo()) {
        return true;
      }
    }
    return false;
  }

  Future<bool> hasAudio() async {
    for (final span in spans) {
      if (await span.composition.hasAudio()) {
        return true;
      }
    }
    return false;
  }

  Future<Duration> computeEndTime() async {
    Duration endTime = Duration.zero;

    for (final span in spans) {
      final spanEndTime = span.end != null ? span.end! : await span.composition.computeIntrinsicDuration() + span.start;
      if (spanEndTime > endTime) {
        endTime = spanEndTime;
      }
    }

    return endTime;
  }

  DiagnosticsNode createDiagnosticsNode() {
    final children = <DiagnosticsNode>[];
    for (final span in spans) {
      children.add(
        DiagnosticsNode(
          name: '${span.start} -> ${span.end}',
          children: [
            span.composition.createDiagnosticsNode(),
          ],
        ),
      );
    }

    return DiagnosticsNode(
      name: 'Layer',
      children: children,
    );
  }

  Future<FfmpegStream> build(FfmpegBuilder builder, CompositionSettings settings) async {
    if (spans.isEmpty) {
      throw Exception('Layer needs at least 1 LayerSpan to build()');
    }

    spans.sort((span1, span2) => span1.start.inMilliseconds - span2.start.inMilliseconds);

    // Ensure that no spans overlap.
    for (int i = 0; i < spans.length - 1; ++i) {
      if (await spans[i].computeEndTime() > await spans[i + 1].computeEndTime()) {
        throw Exception(
            'LayerSpans cannot overlap. Span 1: ${spans[i].start} -> ${await spans[i].computeEndTime()}, Span 2: ${spans[i + 1].start} -> ${await spans[i + 1].computeEndTime()}');
      }
    }

    return _buildWithTransparentSpacers(builder, settings);
  }

  Future<FfmpegStream> _buildWithTransparentSpacers(FfmpegBuilder builder, CompositionSettings settings) async {
    // Build streams for all the content and gaps and concatenate them.
    final concatStreams = <FfmpegStream>[];
    final _hasVideo = await hasVideo();
    final _hasAudio = await hasAudio();

    if (spans.first.start > Duration.zero) {
      // Create an empty span at the beginning.
      final blankComposition = TransparentComposition(
        hasVideo: _hasVideo,
        hasAudio: _hasAudio,
        duration: spans.first.start,
      );

      concatStreams.add(
        await blankComposition.build(builder, settings.copyWith(duration: spans.first.start)),
      );
    }

    for (int i = 0; i < spans.length; ++i) {
      Duration spanDuration;
      if (spans[i].end != null) {
        spanDuration = spans[i].end! - spans[i].start;
      } else {
        final intrinsicSpanDuration = await spans[i].composition.computeIntrinsicDuration();
        spanDuration =
            intrinsicSpanDuration != Duration.zero ? intrinsicSpanDuration : settings.duration - spans[i].start;
      }
      final spanEndTime = spans[i].start + spanDuration;

      concatStreams.add(
        await spans[i].composition.build(
              builder,
              settings.copyWith(duration: spanDuration),
            ),
      );

      final nextCutPoint = i < spans.length - 1 ? spans[i + 1].start : settings.duration;

      if (nextCutPoint < spanEndTime) {
        throw Exception('A LayerSpan must not overlap the previous LayerSpan. Previous end time: $spanEndTime, next '
            'span start time: $nextCutPoint');
      }

      if (nextCutPoint != spanEndTime) {
        // There is a gap after this content. Add a blank composition.
        final blankComposition = TransparentComposition(
          hasVideo: _hasVideo,
          hasAudio: _hasAudio,
          duration: nextCutPoint - await spans[i].computeEndTime(),
        );

        // TODO: this is the source of the timing issue with the Clone Wars opener
        concatStreams.add(
          await blankComposition.build(
            builder,
            settings.copyWith(
              duration: nextCutPoint - await spans[i].computeEndTime(),
            ),
          ),
        );
      }
    }

    if (concatStreams.length == 1) {
      return concatStreams.first;
    }

    final outStream = builder.createStream();
    builder.addFilterChain(
      FilterChain(
        inputs: concatStreams,
        filters: [
          ConcatFilter(
            segmentCount: concatStreams.length,
            outputVideoStreamCount: _hasVideo ? 1 : 0,
            outputAudioStreamCount: _hasAudio ? 1 : 0,
          ),
        ],
        outputs: [
          if (_hasVideo && _hasAudio) //
            outStream //
          else if (_hasVideo) //
            outStream.videoOnly //
          else //
            outStream.audioOnly,
        ],
      ),
    );

    return outStream;
  }
}

/// A span within a [Layer] in a [LayerComposition].
///
/// Renders the given [composition] within the broader [LayerComposition]
/// starting at the given [start] time and ending either at the intrinsic
/// duration of [composition], or at the specified [end] time.
class LayerSpan {
  LayerSpan({
    required this.start,
    this.end,
    required this.composition,
  });

  final Duration start;
  final Duration? end;
  final Composition composition;

  Future<Duration> computeEndTime() async {
    return end ?? start + await composition.computeIntrinsicDuration();
  }
}
