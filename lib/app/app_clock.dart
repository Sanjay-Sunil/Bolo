/// Monotonic clock shared by metrics, playback scheduling and the UI.
final appClock = Stopwatch()..start();

Duration get now => appClock.elapsed;
