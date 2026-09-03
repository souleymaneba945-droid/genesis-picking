import 'package:flutter/widgets.dart';

/// Widget racine permettant un "redémarrage" complet de l'application —
/// l'équivalent logiciel de fermer puis relancer l'appli, ce que
/// l'utilisateur faisait manuellement (en redémarrant tout l'ordinateur)
/// quand l'appli restait bloquée en attente d'une réponse réseau qui ne
/// venait jamais (voir le correctif `.timeout(...)` dans
/// `firestore_tour_remote_source.dart` et les fichiers associés, qui
/// traite la cause ; ce bouton reste un filet de sécurité pour tout autre
/// cas imprévu).
///
/// Reconstruit tout l'arbre de widgets en dessous — donc aussi le
/// `ProviderScope` placé à l'intérieur de [builder] par `main.dart`, donc
/// TOUT l'état Riverpod, y compris la session active — en changeant sa
/// [Key] : c'est le mécanisme standard de Flutter pour ce besoin, sans
/// dépendre d'un plugin natif supplémentaire (le projet a déjà eu son lot
/// de dépendances natives fragiles à faire fonctionner, voir l'historique
/// de la mise en place d'Android/Windows).
class AppRestart extends StatefulWidget {
  const AppRestart({required this.builder, super.key});

  final WidgetBuilder builder;

  /// Déclenche un redémarrage complet depuis n'importe quel écran
  /// descendant (voir `SettingsScreen`). Sans effet si [context] n'a pas
  /// [AppRestart] comme ancêtre (ne devrait jamais arriver : `main.dart`
  /// l'installe à la racine de toute l'application).
  static void restart(BuildContext context) {
    context.findAncestorStateOfType<_AppRestartState>()?._restart();
  }

  @override
  State<AppRestart> createState() => _AppRestartState();
}

class _AppRestartState extends State<AppRestart> {
  Key _key = UniqueKey();

  void _restart() {
    setState(() => _key = UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: _key, child: widget.builder(context));
  }
}
