import 'package:flutter/material.dart';

/// Bouton d'action secondaire (ex. "Annuler", "Retour").
///
/// Visuellement en retrait par rapport à [PrimaryButton], jamais adjacent
/// à un bouton principal de poids visuel égal sur les écrans critiques
/// (Document UX/UI, section 6).
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({required this.label, required this.onPressed, super.key});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(onPressed: onPressed, child: Text(label)),
    );
  }
}
