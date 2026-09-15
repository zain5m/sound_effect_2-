class MasterSettings {
  double speed;
  int pitch;

  MasterSettings({this.speed = 1.0, this.pitch = 0});

  bool get hasEffects => speed != 1.0 || pitch != 0;

  MasterSettings copyWith({double? speed, int? pitch}) {
    return MasterSettings(
      speed: speed ?? this.speed,
      pitch: pitch ?? this.pitch,
    );
  }
}
