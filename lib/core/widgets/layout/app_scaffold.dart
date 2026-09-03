import 'package:flutter/material.dart';
import 'package:genesis_picking/core/theme/app_dimensions.dart';
import 'package:genesis_picking/core/widgets/status/sync_status_indicator.dart';

/// Squelette d'écran commun à toute l'application.
///
/// Garantit deux choses systématiquement, conformément au Document UX/UI :
/// - l'indicateur de synchronisation est toujours visible (dans l'AppBar) ;
/// - le contenu bénéficie d'un espacement standard, jamais codé en dur
///   dans chaque écran.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.title,
    required this.body,
    super.key,
    this.actions,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          ...?actions,
          const Padding(
            padding: EdgeInsets.only(right: AppDimensions.spacingMd),
            child: Center(child: SyncStatusIndicator()),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMd),
        child: body,
      ),
    );
  }
}
