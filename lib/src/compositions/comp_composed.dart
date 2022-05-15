import 'package:ffmpeg_cli/ffmpeg_cli.dart';

import 'compositions.dart';

/// A [Composition] that is fully represented by composing other
/// [Composition]s, rather than building custom FFMPEG streams.
abstract class ComposedComposition implements Composition {
  Composition? _cachedComposition;

  /// Returns a [Composition] that's composed of other [Composition]s.
  ///
  /// This method is similar to a Flutter Widget's `build()` method, where
  /// other widgets are composed together and returned.
  Future<Composition> compose();

  @override
  Future<bool> hasVideo() async {
    _cachedComposition ??= await compose();

    return await _cachedComposition!.hasVideo();
  }

  @override
  Future<bool> hasAudio() async {
    _cachedComposition ??= await compose();

    return await _cachedComposition!.hasAudio();
  }

  @override
  Future<Duration> computeIntrinsicDuration() async {
    _cachedComposition ??= await compose();

    return await _cachedComposition!.computeIntrinsicDuration();
  }

  @override
  Future<VideoSize> computeIntrinsicSize() async {
    _cachedComposition ??= await compose();

    return await _cachedComposition!.computeIntrinsicSize();
  }

  @override
  Future<FfmpegStream> build(FfmpegBuilder builder, CompositionSettings settings) async {
    if (_cachedComposition != null) {
      _cachedComposition = await compose();
    }

    return _cachedComposition!.build(builder, settings);
  }

  @override
  DiagnosticsNode createDiagnosticsNode() {
    return DiagnosticsNode(name: "ComposedComposition");
  }
}
