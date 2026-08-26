class SplitSettings {
  double threshold;
  double minSilence;
  double windowMs;

  SplitSettings({
    this.threshold = 0.001,
    this.minSilence = 0.3,
    this.windowMs = 20,
  });

  SplitSettings copyWith({
    double? threshold,
    double? minSilence,
    double? windowMs,
  }) {
    return SplitSettings(
      threshold: threshold ?? this.threshold,
      minSilence: minSilence ?? this.minSilence,
      windowMs: windowMs ?? this.windowMs,
    );
  }
}
