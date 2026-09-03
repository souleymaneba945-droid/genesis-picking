import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_picking/core/errors/app_exception.dart';
import 'package:genesis_picking/core/errors/result.dart';

void main() {
  group('Result', () {
    test('Success expose la valeur et isSuccess=true', () {
      final result = Result<int>.success(42);
      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
    });

    test('Failure expose isFailure=true', () {
      final result = Result<int>.failure(const NetworkException('hors ligne'));
      expect(result.isFailure, isTrue);
      expect(result.isSuccess, isFalse);
    });

    test('map transforme la valeur en cas de succès', () {
      final result = Result<int>.success(2).map((value) => value * 10);
      final value = result.when(success: (v) => v, failure: (_) => -1);
      expect(value, 20);
    });

    test('map propage l\'échec sans exécuter la transformation', () {
      var callCount = 0;
      final result = Result<int>.failure(
        const StorageException('erreur locale'),
      ).map((value) {
        callCount++;
        return value * 10;
      });
      expect(callCount, 0);
      expect(result.isFailure, isTrue);
    });

    test('when appelle la bonne branche selon le cas', () {
      final success = Result<String>.success('ok');
      final failure = Result<String>.failure(
        const ValidationException('quantité invalide'),
      );

      expect(
        success.when(success: (v) => v, failure: (_) => 'erreur'),
        'ok',
      );
      expect(
        failure.when(success: (v) => v, failure: (e) => e.message),
        'quantité invalide',
      );
    });
  });
}
