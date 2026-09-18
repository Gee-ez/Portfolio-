class AngleSmoother {
  final int windowSize;
  final List<double> _history = [];

  AngleSmoother({this.windowSize = 5});

  double update(double newAngle) {
    _history.add(newAngle);
    if (_history.length > windowSize) {
      _history.removeAt(0);
    }
    final sum = _history.reduce((a, b) => a + b);
    return sum / _history.length;
  }
}