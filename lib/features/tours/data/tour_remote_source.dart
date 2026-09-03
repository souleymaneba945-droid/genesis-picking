/// Contenu complet d'une tournée tel que fourni par sa source d'origine
/// (le logiciel de gestion — voir Directive Architecture fonctionnelle,
/// chapitre 2), avant tout stockage local.
class TourDownloadPayload {
  const TourDownloadPayload({
    required this.tourId,
    required this.numeroTournee,
    required this.preparateurId,
    required this.produits,
  });

  final String tourId;
  final String numeroTournee;
  final String preparateurId;
  final List<TourProductPayload> produits;
}

/// Ligne produit telle que fournie par la source d'origine — mêmes
/// champs que les lignes stockées localement (`TourProductLinesTable`),
/// mais côté "à télécharger" plutôt que "déjà stocké localement".
class TourProductPayload {
  const TourProductPayload({
    required this.ordre,
    required this.nom,
    required this.quantiteDemandee,
    required this.emplacement,
    this.description,
    this.imageUrl,
  });

  final int ordre;
  final String nom;
  final String? description;
  final String? imageUrl;
  final int quantiteDemandee;
  final String emplacement;
}

/// Source distante d'une tournée à télécharger.
///
/// Interface volontairement minimale et indépendante de toute
/// technologie réseau. [TourService] ne dépend que de cette interface,
/// jamais d'une implémentation concrète.
abstract interface class TourRemoteSource {
  /// Renvoie les tournées "Disponibles" assignées à ce préparateur, prêtes
  /// à être téléchargées. Ne renvoie que les métadonnées nécessaires à
  /// l'écran "Mes tournées" (Cahier des charges, écran 4.2) — pas encore
  /// le contenu complet (voir [fetchTourContent]).
  Future<List<({String tourId, String numeroTournee})>> listAvailableTours(
    String preparateurId,
  );

  /// Même contenu que [listAvailableTours], mais en flux continu : émet
  /// une nouvelle liste à chaque changement côté serveur (nouvelle
  /// tournée importée par un administrateur, par exemple), sans jamais
  /// avoir besoin de rouvrir un écran ou d'appuyer sur "Actualiser" — voir
  /// [TourService.watchTours], qui combine ce flux avec les données déjà
  /// connues localement.
  Stream<List<({String tourId, String numeroTournee})>> watchAvailableTours(
    String preparateurId,
  );

  /// Récupère le contenu complet d'une tournée (Processus 2, étape 2).
  /// Peut échouer (réseau, source indisponible) — [TourService] traduit
  /// cet échec en [NetworkException].
  Future<TourDownloadPayload> fetchTourContent(String tourId);
}

/// Implémentation "sans source distante active".
///
/// Depuis l'introduction du moteur d'import (voir `features/import/`),
/// les tournées n'arrivent plus par un mécanisme de "liste disponible à
/// télécharger" : l'Administrateur importe directement une picking list
/// (PDF aujourd'hui, un autre format demain), qui crée la tournée déjà
/// intégralement renseignée via `TourRepository.saveDownloadedTour`
/// (Module 3, inchangé) — voir `ImportEngine`.
///
/// Cette implémentation ne renvoie donc jamais de données de
/// démonstration : elle reflète honnêtement qu'aucune tournée n'est
/// "en attente d'être découverte" par ce mécanisme tant qu'aucune vraie
/// intégration API (option 5 de la Directive Import) n'existe. Le jour
/// où le logiciel de gestion pourra pousser directement ses tournées
/// (API), cette classe sera remplacée par une implémentation réelle,
/// sans qu'aucun autre fichier n'ait à changer.
class NoTourRemoteSource implements TourRemoteSource {
  const NoTourRemoteSource();

  @override
  Future<List<({String tourId, String numeroTournee})>> listAvailableTours(
    String preparateurId,
  ) async {
    return const [];
  }

  @override
  Stream<List<({String tourId, String numeroTournee})>> watchAvailableTours(
    String preparateurId,
  ) {
    return Stream.value(const []);
  }

  @override
  Future<TourDownloadPayload> fetchTourContent(String tourId) async {
    throw StateError(
      'Aucune source distante active : les tournées sont créées par '
      'import (ImportEngine), pas par téléchargement à distance.',
    );
  }
}
