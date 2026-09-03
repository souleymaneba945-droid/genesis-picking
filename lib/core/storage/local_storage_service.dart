/// Contrat abstrait du stockage local, indépendant de Drift.
///
/// Les modules métier (Module 3 et suivants) ne doivent jamais dépendre
/// directement de Drift : ils dépendent de cette interface, implémentée
/// par [LocalDatabase]. Cela permet de remplacer la technologie de
/// stockage plus tard sans modifier le code métier, et de fournir une
/// implémentation en mémoire dans les tests.
abstract interface class LocalStorageService {
  /// Doit être appelé une seule fois au démarrage, avant tout accès aux
  /// données locales.
  Future<void> open();

  /// Ferme proprement la connexion à la base locale (utile en test).
  Future<void> close();

  /// Vrai une fois [open] terminé avec succès.
  bool get isOpen;
}
