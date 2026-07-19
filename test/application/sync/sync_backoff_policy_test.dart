import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/application/sync/sync_backoff_policy.dart';

void main() {
  group('ExponentialBackoffPolicy', () {
    test('doubles delay and respects maximum', () {
      final policy = ExponentialBackoffPolicy(
        baseDelay: const Duration(seconds: 2),
        maxDelay: const Duration(seconds: 10),
        jitterSampler: () => 1,
      );

      expect(policy.delayForAttempt(1), const Duration(seconds: 2));
      expect(policy.delayForAttempt(2), const Duration(seconds: 4));
      expect(policy.delayForAttempt(3), const Duration(seconds: 8));
      expect(policy.delayForAttempt(4), const Duration(seconds: 10));
      expect(policy.delayForAttempt(20), const Duration(seconds: 10));
    });

    test('uses full jitter at zero, midpoint, and exponential cap', () {
      final zero = ExponentialBackoffPolicy(
        baseDelay: const Duration(seconds: 10),
        maxDelay: const Duration(minutes: 1),
        jitterSampler: () => 0,
      );
      final midpoint = ExponentialBackoffPolicy(
        baseDelay: const Duration(seconds: 10),
        maxDelay: const Duration(minutes: 1),
        jitterSampler: () => 0.5,
      );
      final cap = ExponentialBackoffPolicy(
        baseDelay: const Duration(seconds: 10),
        maxDelay: const Duration(seconds: 30),
        jitterSampler: () => 1,
      );

      expect(zero.delayForAttempt(1), Duration.zero);
      expect(midpoint.delayForAttempt(1), const Duration(seconds: 5));
      expect(cap.delayForAttempt(10), const Duration(seconds: 30));
    });

    test('rejects invalid attempts and sampler results', () {
      final policy = ExponentialBackoffPolicy(jitterSampler: () => 1.1);

      expect(() => policy.delayForAttempt(0), throwsArgumentError);
      expect(() => policy.delayForAttempt(1), throwsStateError);
    });
  });
}
