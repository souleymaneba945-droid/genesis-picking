import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/core/providers/core_providers.dart';
import 'package:genesis_picking/core/session/user_role.dart';
import 'package:genesis_picking/features/courier/courier_providers.dart';
import 'package:genesis_picking/features/courier/data/courier_request.dart';

/// Alerte le coursier connecté (notification système — bannière + son,
/// voir `core/notifications/`) dès qu'une NOUVELLE demande lui est
/// assignée, pendant que l'app tourne. Répond au problème "il faut
/// prévenir le coursier à la voix qu'une demande est arrivée" : jusqu'ici,
/// seule la liste de l'écran "Demandes" se mettait à jour toute seule
/// (voir [CourierController]), sans rien qui attire l'attention du
/// coursier si l'app n'est pas déjà à l'écran.
///
/// S'abonne au même flux temps réel que [CourierController]
/// (`courierRequestsWatchProvider`), mais ne s'occupe que de détecter les
/// arrivées — jamais de l'affichage de la liste, qui reste entièrement du
/// ressort de [CourierController].
///
/// Activé une seule fois pour toute la session, depuis la racine de l'app
/// (`GenesisPickingApp`, toujours montée) plutôt que depuis
/// [CoursierShell] : une demande doit pouvoir déclencher une notification
/// même si le coursier a un écran de détail ouvert par-dessus, pas
/// seulement quand la coquille à onglets est directement visible.
///
/// La première émission du flux sert uniquement de référence ("déjà
/// connu") — jamais de notification à ce moment-là, pour ne pas renotifier
/// tout l'historique existant à chaque ouverture de l'app. Seules les
/// arrivées ultérieures (nouvel identifiant jamais vu) déclenchent une
/// notification.
class CourierNotificationWatcher extends Notifier<void> {
  /// `null` tant qu'aucune première émission n'a été reçue pour la session
  /// en cours — distinct d'un `Set` vide (aucune demande ouverte), qui est
  /// une référence valide.
  Set<String>? _demandesConnues;

  @override
  void build() {
    final session = ref.watch(sessionProvider);
    if (session == null || session.role != UserRole.coursier) {
      _demandesConnues = null;
      return;
    }

    // Fire-and-forget : `initialize()` est idempotent et journalise déjà
    // ses propres échecs (voir `LocalNotificationService`) — jamais
    // bloquant pour la connexion du coursier.
    unawaited(ref.read(localNotificationServiceProvider).initialize());

    ref.listen(courierRequestsWatchProvider(session.userId), (_, next) {
      next.whenData(_onRequestsChanged);
    });
  }

  void _onRequestsChanged(List<CourierRequest> requests) {
    final idsActuels = {for (final r in requests) r.id};
    final connues = _demandesConnues;
    _demandesConnues = idsActuels;

    if (connues == null) return; // Référence de départ seulement.

    final service = ref.read(localNotificationServiceProvider);
    for (final request in requests) {
      if (connues.contains(request.id)) continue;
      unawaited(
        service.show(
          id: request.id.hashCode,
          title: 'Nouvelle demande coursier',
          body: request.produitNom == null
              ? 'Un préparateur a besoin de vous pour un produit introuvable.'
              : '${request.produitNom} — quantité ${request.quantiteDemandee}',
        ),
      );
    }
  }
}

final courierNotificationWatcherProvider = NotifierProvider<
  CourierNotificationWatcher,
  void
>(CourierNotificationWatcher.new);
