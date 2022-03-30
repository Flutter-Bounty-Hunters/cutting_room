class TimeSpan {
  const TimeSpan({
    required this.start,
    required this.end,
  });

  final Duration start;
  final Duration? end;

  @override
  String toString() => '[TimeSpan] - start: $start, end: $end';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeSpan && runtimeType == other.runtimeType && start == other.start && end == other.end;

  @override
  int get hashCode => start.hashCode ^ end.hashCode;
}
