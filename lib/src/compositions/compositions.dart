import 'package:ffmpeg_cli/ffmpeg_cli.dart';

/// A node in a composition tree, which represents a video that can be
/// composed with FFMPEG.
///
/// To render a composition with FFMPEG, pass an `FfmpegBuilder` to the
/// root `Composition` of a composition tree. That builder is passed
/// down the tree, adding inputs and filters until the entire composition
/// tree is represented within the `FfmpegBuilder`. Use the returned
/// `FfmpegStream`, along with the `FfmpegBuilder` to generate the
/// corresponding FFMPEG CLI command.
abstract class Composition {
  /// Whether this composition includes any video frames.
  Future<bool> hasVideo();

  /// Whether this composition includes any audio streams.
  Future<bool> hasAudio();

  /// Computes the natural, or intrinsic, duration of this composition.
  ///
  /// A composition that wraps a video file would have an intrinsic
  /// duration equal to the duration of the video in the file. A composition
  /// that slices a piece of a video would have an intrinsic duration
  /// equivalent to the length of that slice.
  Future<Duration> computeIntrinsicDuration();

  DiagnosticsNode createDiagnosticsNode();

  /// Adds this composition to the composition tree in the given [builder].
  Future<FfmpegStream> build(FfmpegBuilder builder, CompositionSettings settings);
}

/// Composition configuration.
class CompositionSettings {
  const CompositionSettings({
    required this.videoDimensions,
    required this.duration,
  });

  /// The dimensions of the composition.
  final Size videoDimensions;

  /// The duration of the composition.
  final Duration duration;
  // TODO: consider adding video and audio codec requirements in here.
  //       Those requirements can come from a global inspection of
  //       assets.

  CompositionSettings copyWith({
    Size? videoDimensions,
    Duration? duration,
  }) {
    return CompositionSettings(
      videoDimensions: videoDimensions ?? this.videoDimensions,
      duration: duration ?? this.duration,
    );
  }
}

class Size {
  const Size(this.width, this.height);

  final num width;
  final num height;

  @override
  String toString() => '[Size]: ${width}x$height';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Size && runtimeType == other.runtimeType && width == other.width && height == other.height;

  @override
  int get hashCode => width.hashCode ^ height.hashCode;
}

abstract class ProxyComposition implements Composition {
  ProxyComposition({
    required this.content,
  });

  final Composition content;

  @override
  Future<bool> hasVideo() async {
    return await content.hasVideo();
  }

  @override
  Future<bool> hasAudio() async {
    return await content.hasAudio();
  }

  @override
  Future<Duration> computeIntrinsicDuration() async {
    return await content.computeIntrinsicDuration();
  }

  @override
  Future<FfmpegStream> build(FfmpegBuilder builder, CompositionSettings settings);
}

class DiagnosticsNode {
  DiagnosticsNode({
    required this.name,
    List<DiagnosticsNode> properties = const [],
    List<DiagnosticsNode> children = const [],
  })  : _properties = properties,
        _children = children;

  final String name;

  final List<DiagnosticsNode> _properties;
  List<DiagnosticsNode> getProperties() => _properties;

  final List<DiagnosticsNode> _children;
  List<DiagnosticsNode> getChildren() => _children;

  void printDeep([String indent = '']) {
    print('$indent$name');

    for (final prop in getProperties()) {
      prop.printDeep(indent + ' / ');
    }

    for (final child in getChildren()) {
      child.printDeep(indent + '-- ');
    }
  }
}

class PropertyNode extends DiagnosticsNode {
  PropertyNode({
    this.name = '',
    this.value = '',
  }) : super(name: name);

  final String name;
  final String value;

  @override
  List<PropertyNode> getChildren() => [];

  @override
  void printDeep([String indent = '']) {
    print('$indent$name: $value');
  }
}
