import 'package:genesis_picking/core/session/user_role.dart';

/// Représentation d'un compte utilisateur, indépendante de la technologie
/// de stockage (Drift). Les couches `presentation` ne manipulent jamais
/// directement une ligne Drift : toujours ce modèle.
class UserAccount {
  const UserAccount({
    required this.id,
    required this.identifiant,
    required this.nomAffichage,
    required this.role,
    required this.actif,
    required this.creeLe,
  });

  final String id;
  final String identifiant;
  final String nomAffichage;
  final UserRole role;
  final bool actif;
  final DateTime creeLe;

  UserAccount copyWith({bool? actif}) {
    return UserAccount(
      id: id,
      identifiant: identifiant,
      nomAffichage: nomAffichage,
      role: role,
      actif: actif ?? this.actif,
      creeLe: creeLe,
    );
  }
}
