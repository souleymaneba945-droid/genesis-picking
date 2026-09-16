import 'package:flutter/material.dart';
import 'package:genesis_picking/core/theme/app_colors.dart';
import 'package:genesis_picking/core/theme/app_dimensions.dart';

/// Pictogramme de marque GENESIS PICKING — Modernisation visuelle
/// (12/09/2026), aligné sur le composant `Logo` du prototype de référence
/// v0.dev `genesis-picking-wa` (`components/genesis/ui.tsx`) : un carré
/// arrondi plein `primary` contenant une icône blanche (icône source :
/// `Boxes`, lucide-react — sans équivalent Material exact, remplacée par
/// [Icons.inventory_2_rounded], la plus proche sémantiquement), jamais
/// l'icône de lancement réelle de l'app (`assets/icon/icon.png`, un simple
/// repli "GP" texte qui n'a plus lieu d'être maintenant que la vraie
/// maquette est connue).
///
/// Deux présentations, choisies par [onDarkBackground] :
/// - `false` (par défaut, ex. barre supérieure sur fond clair) : carré
///   plein `AppColors.primary`.
/// - `true` (ex. en-tête connexion, déjà `AppColors.primary`) : médaillon
///   translucide blanc avec anneau — un carré plein de la même couleur
///   que son fond serait invisible (source : `bg-primary-foreground/15
///   ring-1 ring-primary-foreground/20` du prototype).
class AppLogoMark extends StatelessWidget {
  const AppLogoMark({super.key, this.size = 40, this.onDarkBackground = false});

  final double size;
  final bool onDarkBackground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: onDarkBackground ? Colors.white.withValues(alpha: 0.15) : AppColors.primary,
        borderRadius: BorderRadius.circular(AppDimensions.cornerRadiusSm),
        border: onDarkBackground
            ? Border.all(color: Colors.white.withValues(alpha: 0.2))
            : null,
      ),
      child: Icon(Icons.inventory_2_rounded, color: Colors.white, size: size * 0.5),
    );
  }
}
