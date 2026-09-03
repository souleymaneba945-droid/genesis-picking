import 'package:flutter/material.dart';

/// Bouton d'action principal, unique dans toute l'application.
///
/// Conforme au Document UX/UI : pleine largeur, hauteur généreuse (voir
/// `AppTheme` pour la hauteur minimale), jamais deux boutons de ce type
/// de même poids visuel sur un même écran (voir Spécification
/// Fonctionnelle, règles transverses).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(label),
      ),
    );
  }
}
