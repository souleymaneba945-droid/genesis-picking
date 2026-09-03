import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_picking/core/errors/app_exception.dart';
import 'package:genesis_picking/core/errors/error_handler.dart';

void main() {
  group('ErrorHandler.userMessageFor', () {
    test('NetworkException produit le message hors-ligne validé (PRD 9)', () {
      const exception = NetworkException('erreur technique interne');
      expect(
        ErrorHandler.userMessageFor(exception),
        'Pas de connexion. Votre travail est enregistré et sera transmis '
        'automatiquement.',
      );
    });

    test('ValidationException conserve le message métier tel quel', () {
      const exception = ValidationException('Quantité invalide, veuillez vérifier.');
      expect(
        ErrorHandler.userMessageFor(exception),
        'Quantité invalide, veuillez vérifier.',
      );
    });

    test('StorageException produit le message générique validé (PRD 9)', () {
      const exception = StorageException('disque plein');
      expect(
        ErrorHandler.userMessageFor(exception),
        'Une erreur est survenue. Vos données sont conservées. Réessayez.',
      );
    });

    test('UnknownException produit le même message générique que Storage', () {
      const exception = UnknownException('cause imprévue');
      expect(
        ErrorHandler.userMessageFor(exception),
        ErrorHandler.userMessageFor(const StorageException('x')),
      );
    });
  });
}
