import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/core/errors/error_handler.dart';
import 'package:genesis_picking/core/theme/app_colors.dart';
import 'package:genesis_picking/core/theme/app_dimensions.dart';
import 'package:genesis_picking/core/theme/app_typography.dart';
import 'package:genesis_picking/core/widgets/feedback/app_snackbar.dart';
import 'package:genesis_picking/core/widgets/status/status_pill.dart';
import 'package:genesis_picking/features/warehouse_location/data/brand_warehouse_location.dart';
import 'package:genesis_picking/features/warehouse_location/domain/brand_location_import.dart';
import 'package:genesis_picking/features/warehouse_location/presentation/create_brand_location_screen.dart';
import 'package:genesis_picking/features/warehouse_location/presentation/edit_brand_location_dialog.dart';
import 'package:genesis_picking/features/warehouse_location/warehouse_location_providers.dart';

/// Gestion des emplacements entrepôt par marque (Module 5 v2, Rubrique 2)
/// — même schéma que `UserManagementScreen` : créer, modifier, supprimer,
/// et depuis le 13/09/2026 (maquette v0.dev `brand-locations-screen.tsx`)
/// importer en masse depuis un fichier `.csv`/`.xlsx` plutôt que marque
/// par marque uniquement.
///
/// Onglet à part entière de `AdminShell` depuis le 13/09/2026 (retour
/// terrain : l'accès via une icône raccourci dans "Utilisateurs" passait
/// inaperçue) — plus aucun accès via `UserManagementScreen`.
class WarehouseLocationManagementScreen extends ConsumerStatefulWidget {
  const WarehouseLocationManagementScreen({super.key});

  @override
  ConsumerState<WarehouseLocationManagementScreen> createState() =>
      _WarehouseLocationManagementScreenState();
}

class _WarehouseLocationManagementScreenState
    extends ConsumerState<WarehouseLocationManagementScreen> {
  late Future<List<BrandWarehouseLocation>> _locationsFuture;
  List<BrandWarehouseLocation> _locations = [];

  static const List<String> _extensionsAcceptees = ['csv', 'xlsx'];

  // État de l'import en masse — jamais mélangé avec l'état de la liste
  // déjà enregistrée ci-dessous (Module 5 v2, Rubrique 2 : deux notions
  // d'emplacement distinctes ; ici, deux ÉTATS d'écran distincts).
  bool _isDragging = false;
  String? _fileName;
  List<BrandLocationImportRow>? _rows;
  String? _parseError;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _locationsFuture = _load();
  }

  Future<List<BrandWarehouseLocation>> _load() async {
    final locations = await ref.read(brandWarehouseLocationRepositoryProvider).listAll();
    if (mounted) setState(() => _locations = locations);
    return locations;
  }

  void _refresh() {
    setState(() => _locationsFuture = _load());
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreateBrandLocationScreen()),
    );
    if (created == true) _refresh();
  }

  Future<void> _openEdit(BrandWarehouseLocation location) async {
    final edited = await showDialog<bool>(
      context: context,
      builder: (_) => EditBrandLocationDialog(location: location),
    );
    if (edited == true) _refresh();
  }

  Future<void> _confirmerSuppression(BrandWarehouseLocation location) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Supprimer "${location.marque}" ?'),
        content: const Text(
          'Cet emplacement sera définitivement supprimé, sur cet appareil '
          'et sur celui de chaque coursier. Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirme != true) return;

    final result = await ref
        .read(brandWarehouseLocationRepositoryProvider)
        .delete(location.id);
    if (!mounted) return;
    result.when(
      success: (_) {
        _refresh();
        AppSnackbar.showSuccess(context, 'Emplacement supprimé.');
      },
      failure: (exception) =>
          AppSnackbar.showError(context, ErrorHandler.userMessageFor(exception)),
    );
  }

  // --- Import en masse ------------------------------------------------

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _extensionsAcceptees,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.bytes == null) return;
    _setFile(name: file.name, bytes: file.bytes!);
  }

  Future<void> _handleDrop(DropDoneDetails details) async {
    setState(() => _isDragging = false);
    if (details.files.isEmpty) return;
    final dropped = details.files.first;
    final extension = dropped.name.split('.').last.toLowerCase();
    if (!_extensionsAcceptees.contains(extension)) return;
    final bytes = await dropped.readAsBytes();
    _setFile(name: dropped.name, bytes: bytes);
  }

  void _setFile({required String name, required Uint8List bytes}) {
    setState(() {
      _fileName = name;
      _rows = null;
      _parseError = null;
    });
    try {
      final rows = parseBrandLocationImportFile(
        bytes: bytes,
        fileName: name,
        existants: _locations,
      );
      setState(() => _rows = rows);
    } on BrandLocationImportException catch (e) {
      setState(() => _parseError = e.message);
    }
  }

  void _resetImport() {
    setState(() {
      _fileName = null;
      _rows = null;
      _parseError = null;
    });
  }

  Future<void> _confirmerImport() async {
    final rows = _rows;
    if (rows == null || _isImporting) return;
    setState(() => _isImporting = true);

    final existantesParNomMinuscule = {
      for (final e in _locations) e.marque.toLowerCase(): e,
    };
    final repository = ref.read(brandWarehouseLocationRepositoryProvider);
    var reussies = 0;

    for (final row in rows) {
      if (row.statut == BrandLocationImportStatus.erreur) continue;

      final existante = existantesParNomMinuscule[row.marque.toLowerCase()];
      final result = existante != null
          ? await repository.update(
              id: existante.id,
              marque: row.marque,
              emplacement: row.emplacement,
            )
          : await repository.create(marque: row.marque, emplacement: row.emplacement);

      result.when(success: (_) => reussies++, failure: (_) {});
    }

    if (!mounted) return;
    setState(() => _isImporting = false);
    _resetImport();
    _refresh();
    AppSnackbar.showSuccess(
      context,
      reussies > 1 ? '$reussies marques importées.' : '$reussies marque importée.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Pas d'AppBar propre (Modernisation visuelle, 13/09/2026) : cet
      // écran est maintenant un onglet de `AdminShell`, sous la barre
      // supérieure déjà fournie par `RoleShell` — même principe que
      // `SettingsScreen`/`MyToursScreen`. Fond transparent pour ne pas
      // recouvrir le fond de `RoleShell` derrière ce `Scaffold` imbriqué.
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        // Tag explicite : les 5 onglets du shell Administrateur sont
        // montés simultanément (IndexedStack) — voir la même note dans
        // `my_tours_screen.dart`/`admin_dashboard_screen.dart`, où ce bug
        // a été découvert.
        heroTag: 'admin-emplacements-fab',
        onPressed: _openCreate,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Ajouter'),
      ),
      body: FutureBuilder<List<BrandWarehouseLocation>>(
        future: _locationsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Impossible de charger les emplacements.'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final locations = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.spacingLg,
              AppDimensions.spacingMd,
              AppDimensions.spacingLg,
              AppDimensions.spacingXl * 2,
            ),
            children: [
              const Text('Emplacements entrepôt', style: AppTypography.screenTitle),
              const SizedBox(height: AppDimensions.spacingXs),
              const Text(
                'Importez en masse les associations marque → emplacement '
                'depuis un fichier.',
                style: AppTypography.secondaryLabel,
              ),
              const SizedBox(height: AppDimensions.spacingMd),
              const _WarningBanner(),
              const SizedBox(height: AppDimensions.spacingMd),
              if (_rows == null)
                DropTarget(
                  onDragEntered: (_) => setState(() => _isDragging = true),
                  onDragExited: (_) => setState(() => _isDragging = false),
                  onDragDone: _handleDrop,
                  child: _ImportDropZone(isDragging: _isDragging, onBrowse: _pickFile),
                ),
              if (_parseError != null) ...[
                const SizedBox(height: AppDimensions.spacingSm),
                Container(
                  padding: const EdgeInsets.all(AppDimensions.spacingSm),
                  decoration: BoxDecoration(
                    color: AppColors.errorSoft,
                    borderRadius: BorderRadius.circular(AppDimensions.cornerRadius),
                  ),
                  child: Text(
                    _parseError!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              if (_rows != null) ...[
                _ImportPreview(
                  fileName: _fileName!,
                  rows: _rows!,
                  isImporting: _isImporting,
                  onCancel: _resetImport,
                  onConfirm: _confirmerImport,
                ),
              ],
              const SizedBox(height: AppDimensions.spacingLg),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: AppDimensions.spacingXs),
                  const Text('Associations enregistrées', style: AppTypography.sectionTitle),
                  const Spacer(),
                  StatusPill(
                    label: '${locations.length}',
                    background: AppColors.primarySoft,
                    foreground: AppColors.primary,
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacingSm),
              if (locations.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppDimensions.spacingLg),
                  child: Center(
                    child: Text(
                      'Aucun emplacement défini. Les coursiers verront '
                      '"Emplacement entrepôt non renseigné" tant qu\'aucune '
                      'marque n\'est ajoutée ici.',
                      textAlign: TextAlign.center,
                      style: AppTypography.secondaryLabel,
                    ),
                  ),
                )
              else
                for (final location in locations) ...[
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.storefront_outlined),
                      title: Text(
                        location.marque,
                        style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(location.emplacement),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') _openEdit(location);
                          if (value == 'delete') _confirmerSuppression(location);
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'edit', child: Text('Modifier')),
                          PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingSm),
                ],
            ],
          );
        },
      ),
    );
  }
}

/// Bandeau rappelant que cet emplacement est INDÉPENDANT de celui du PDF
/// — reprend le texte de la maquette source, jamais raccourci : c'est la
/// règle la plus importante de tout ce module (voir `MODULE_5_V2.md`).
class _WarningBanner extends StatelessWidget {
  const _WarningBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingSm),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(AppDimensions.cornerRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.warningText, size: 20),
          const SizedBox(width: AppDimensions.spacingSm),
          Expanded(
            child: RichText(
              text: const TextSpan(
                style: TextStyle(color: AppColors.warningText, fontSize: 13, height: 1.4),
                children: [
                  TextSpan(text: 'Cet emplacement entrepôt est '),
                  TextSpan(text: 'indépendant', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: ' de l\'emplacement de la tournée (PDF) — jamais fusionné.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportDropZone extends StatelessWidget {
  const _ImportDropZone({required this.isDragging, required this.onBrowse});

  final bool isDragging;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onBrowse,
      borderRadius: BorderRadius.circular(AppDimensions.cornerRadiusLg),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          vertical: AppDimensions.spacingXl,
          horizontal: AppDimensions.spacingLg,
        ),
        decoration: BoxDecoration(
          color: isDragging ? AppColors.primarySoft : AppColors.surfaceAlt,
          border: Border.all(
            color: isDragging ? AppColors.primary : AppColors.divider,
            width: isDragging ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(AppDimensions.cornerRadiusLg),
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.upload_outlined, color: AppColors.primary, size: 28),
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            const Text(
              'Glissez un fichier ou cliquez pour parcourir',
              style: TextStyle(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spacingXs),
            const Text(
              'Colonnes attendues : Marque, Emplacement',
              style: AppTypography.secondaryLabel,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppDimensions.cornerRadiusPill),
              ),
              child: const Text(
                '.csv ou .xlsx',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Aperçu des lignes lues avant confirmation — chaque ligne montre son
/// statut (nouveau/mise à jour/erreur), jamais importé silencieusement
/// sans que l'admin ait vu ce qui allait changer.
class _ImportPreview extends StatelessWidget {
  const _ImportPreview({
    required this.fileName,
    required this.rows,
    required this.isImporting,
    required this.onCancel,
    required this.onConfirm,
  });

  final String fileName;
  final List<BrandLocationImportRow> rows;
  final bool isImporting;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final importables = rows.where((r) => r.statut != BrandLocationImportStatus.erreur).length;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimensions.spacingSm),
            child: Row(
              children: [
                const Icon(Icons.description_outlined, size: 18, color: AppColors.primary),
                const SizedBox(width: AppDimensions.spacingXs),
                Expanded(
                  child: Text(
                    fileName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: isImporting ? null : onCancel,
                  icon: const Icon(Icons.close, size: 18),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          for (final row in rows) ...[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spacingSm,
                vertical: AppDimensions.spacingXs,
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      row.marque.isEmpty ? '—' : row.marque,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      row.emplacement.isEmpty ? '—' : row.emplacement,
                      style: AppTypography.secondaryLabel,
                    ),
                  ),
                  _RowStatusLabel(statut: row.statut),
                ],
              ),
            ),
            const Divider(height: 1),
          ],
          Padding(
            padding: const EdgeInsets.all(AppDimensions.spacingSm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: isImporting ? null : onCancel,
                  child: const Text('Annuler'),
                ),
                const SizedBox(width: AppDimensions.spacingSm),
                FilledButton(
                  onPressed: importables == 0 || isImporting ? null : onConfirm,
                  child: isImporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          'Importer $importables marque${importables > 1 ? 's' : ''}',
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RowStatusLabel extends StatelessWidget {
  const _RowStatusLabel({required this.statut});

  final BrandLocationImportStatus statut;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (statut) {
      BrandLocationImportStatus.nouveau => (Icons.check_circle, AppColors.success, 'Nouveau'),
      BrandLocationImportStatus.miseAJour => (Icons.sync, AppColors.primary, 'Mise à jour'),
      BrandLocationImportStatus.erreur => (Icons.cancel, AppColors.error, 'Erreur'),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}
