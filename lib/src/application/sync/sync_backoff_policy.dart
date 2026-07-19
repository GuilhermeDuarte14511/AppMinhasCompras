import 'dart:math';

typedef JitterSampler = double Function();

final class ExponentialBackoffPolicy {
  ExponentialBackoffPolicy({
    this.baseDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(minutes: 5),
    JitterSampler? jitterSampler,
  }) : _jitterSampler = jitterSampler ?? _randomSample {
    if (baseDelay <= Duration.zero) {
      throw ArgumentError.value(baseDelay, 'baseDelay', 'Must be positive.');
    }
    if (maxDelay < baseDelay) {
      throw ArgumentError.value(
        maxDelay,
        'maxDelay',
        'Must be greater than or equal to baseDelay.',
      );
    }
  }

  final Duration baseDelay;
  final Duration maxDelay;

  final JitterSampler _jitterSampler;

  /// Returns a full-jitter delay between zero and the exponential attempt cap.
  Duration delayForAttempt(int attempt) {
    if (attempt < 1) {
      throw ArgumentError.value(attempt, 'attempt', 'Must be at least 1.');
    }

    final cappedDelay = _cappedExponentialDelay(attempt);
    final sample = _jitterSampler();
    if (!sample.isFinite || sample < 0 || sample > 1) {
      throw StateError('The jitter sampler must return a value from 0 to 1.');
    }

    final jitteredMilliseconds = (cappedDelay.inMilliseconds * sample).round();
    return Duration(milliseconds: jitteredMilliseconds);
  }

  DateTime nextAttemptAt({required DateTime failedAt, required int attempt}) {
    return failedAt.add(delayForAttempt(attempt));
  }

  Duration _cappedExponentialDelay(int attempt) {
    var milliseconds = baseDelay.inMilliseconds;
    for (var exponent = 1; exponent < attempt; exponent++) {
      if (milliseconds >= maxDelay.inMilliseconds) {
        return maxDelay;
      }
      milliseconds = (milliseconds * 2).clamp(0, maxDelay.inMilliseconds);
    }
    return Duration(milliseconds: milliseconds);
  }

  static final Random _random = Random();

  static double _randomSample() => _random.nextDouble();
}
