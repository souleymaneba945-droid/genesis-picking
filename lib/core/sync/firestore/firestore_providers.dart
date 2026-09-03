import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Instance Firestore — la base de données centrale hébergée (voir
/// `main.dart`, initialisation Firebase). Ne remplace jamais la base
/// locale Drift : chaque appareil garde sa base locale comme source de
/// vérité pour son propre fonctionnement hors-ligne ; Firestore ne sert
/// qu'à faire circuler certaines données (comptes, tournées importées)
/// entre appareils d'un même compte.
///
/// Pas de provider Firebase Storage ici : les photos produit sont
/// compressées puis embarquées directement dans les documents Firestore
/// (voir `FirestoreTourRemoteSink`) plutôt que stockées à part — Storage
/// exige le forfait payant "Blaze", indisponible pour l'instant (carte
/// prépayée refusée par Google, décision du 29/08/2026).
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});
