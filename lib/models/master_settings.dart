class MasterSettings {
  double speed;
  int pitch;

  /// Keeps the original vocal character while the pitch moves.
  bool preserveFormants;

  MasterSettings({
    this.speed = 1.0,
    this.pitch = 0,
    this.preserveFormants = true,
  });

  bool get hasEffects => speed != 1.0 || pitch != 0;

  MasterSettings copyWith({double? speed, int? pitch, bool? preserveFormants}) {
    return MasterSettings(
      speed: speed ?? this.speed,
      pitch: pitch ?? this.pitch,
      preserveFormants: preserveFormants ?? this.preserveFormants,
    );
  }
}
