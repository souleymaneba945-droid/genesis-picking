import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/core/providers/core_providers.dart';
import 'package:genesis_picking/core/theme/app_colors.dart';
import 'package:genesis_picking/core/theme/app_dimensions.dart';
import 'package:genesis_picking/core/theme/app_typography.dart';
import 'package:genesis_picking/core/widgets/buttons/primary_button.dart';
import 'package:genesis_picking/features/administration/administration_providers.dart';
import 'package:genesis_picking/features/import/data/import_format.dart';
import 'package:genesis_picking/features/import/data/import_report.dart';
import 'package:genesis_picking/features/import/data/import_source.dart';
import 'package:genesis_picking/features/import/import_providers.dart';

/// Écran d'import d'une picking list — Refonte UI + autonomie préparateur.
///
/// Deux façons de l'ouvrir :
/// - Depuis l'Administrateur (`fixedPreparateurId` absent) : un sélecteur
///   choisit le préparateur destinataire, comme avant.
/// - Depuis un Préparateur (`fixedPreparateurId` = son propre id) : aucun
///   sélecteur, l'import lui est directement destiné — il n'a plus besoin
///   de passer par l'Administrateur pour récupérer sa propre tournée.
///
/// Un fichier réel exporté par le logiciel de gestion — soit glissé-
/// déposé directement sur la zone (`desktop_drop`, desktop et web), soit
/// choisi via le sélecteur natif (`file_picker`, toutes plateformes).
/// Les deux chemins, et les deux rôles, alimentent exactement le même
/// [ImportEngine] : aucune nouvelle règle métier, juste qui peut
/// déclencher l'import et pour qui. Le rapport (Directive : "Produire un
/// rapport d'import") s'affiche immédiatement après, avec toutes les
/// erreurs et avertissements détectés.
class ImportTourScreen extends ConsumerStatefulWidget {
  const ImportTourScreen({this.fixedPreparateurId, super.key});

  /// Si fourni, l'import est directement destiné à ce préparateur (son
  /// propre compte) : aucun sélecteur n'est affiché.
  final String? fixedPreparateurId;

  @override
  ConsumerState<ImportTourScreen> createState() => _ImportTourScreenState();
}

class _ImportTourScreenState extends ConsumerState<ImportTourScreen> {
  String? _fileName;
  Uint8List? _fileBytes;
  ImportFormat? _detectedFormat;
  bool _isDragging = false;
  String? _selectedPreparateurId;
  bool _isImporting = false;
  ImportReport? _lastReport;

  // Progression réelle (voir `ImportEngine.import`/`PdfParser.parse`) —
  // seul un import PDF volumineux la fait vraiment avancer par paliers ;
  // les autres formats (rapides) passent directement de rien à terminé.
  int? _progressDone;
  int? _progressTotal;
  DateTime? _importStartedAt;

  static const List<String> _allowedExtensions = ['pdf', 'xlsx', 'csv', 'json'];

  bool get _autonome => widget.fixedPreparateurId != null;

  @override
  void initState() {
    super.initState();
    _selectedPreparateurId = widget.fixedPreparateurId;
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
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
    if (!_allowedExtensions.contains(extension)) return;

    final bytes = await dropped.readAsBytes();
    _setFile(name: dropped.name, bytes: bytes);
  }

  void _setFile({required String name, required Uint8List bytes}) {
    setState(() {
      _fileName = name;
      _fileBytes = bytes;
      _detectedFormat = _formatFromExtension(name.split('.').last);
      _lastReport = null;
    });
  }

  ImportFormat? _formatFromExtension(String? extension) {
    return switch (extension?.toLowerCase()) {
      'pdf' => ImportFormat.pdf,
      'xlsx' => ImportFormat.excel,
      'csv' => ImportFormat.csv,
      'json' => ImportFormat.json,
      _ => null,
    };
  }

  Future<void> _import() async {
    final bytes = _fileBytes;
    final name = _fileName;
    final format = _detectedFormat;
    final preparateurId = _selectedPreparateurId;
    if (bytes == null ||
        name == null ||
        format == null ||
        preparateurId == null) {
      return;
    }

    setState(() {
      _isImporting = true;
      _progressDone = null;
      _progressTotal = null;
      _importStartedAt = DateTime.now();
    });

    final importateurId = ref.read(sessionProvider)?.userId ?? 'inconnu';
    final report = await ref.read(importEngineProvider).import(
          format: format,
          source: ImportSource(bytes: bytes, fileName: name),
          preparateurId: preparateurId,
          importedByUserId: importateurId,
          onProgress: (done, total) {
            if (!mounted) return;
            setState(() {
              _progressDone = done;
              _progressTotal = total;
            });
          },
        );

    if (!mounted) return;
    setState(() {
      _isImporting = false;
      _lastReport = report;
    });
  }

  /// "≈ 45 s restantes" — extrapolation simple à partir du temps déjà
  /// écoulé et de la part déjà faite : chaque produit prenant à peu près
  /// le même temps (même opération répétée), l'estimation reste fiable
  /// même si elle se rapproche de zéro qu'en toute fin.
  String? _tempsRestantEstime() {
    final debut = _importStartedAt;
    final done = _progressDone;
    final total = _progressTotal;
    if (debut == null || done == null || total == null || done == 0) {
      return null;
    }
    final ecoule = DateTime.now().difference(debut);
    final restant = Duration(
      microseconds: ecoule.inMicroseconds * (total - done) ~/ done,
    );
    if (restant.inSeconds <= 0) return null;
    if (restant.inSeconds < 60) return '≈ ${restant.inSeconds} s restantes';
    return '≈ ${restant.inMinutes} min restantes';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_autonome ? 'Importer ma tournée' : 'Importer une tournée'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropTarget(
              onDragEntered: (_) => setState(() => _isDragging = true),
              onDragExited: (_) => setState(() => _isDragging = false),
              onDragDone: _handleDrop,
              child: _DropZone(
                fileName: _fileName,
                isDragging: _isDragging,
                formatUnrecognized:
                    _fileName != null && _detectedFormat == null,
                onBrowse: _pickFile,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            if (_autonome)
              // Import autonome (préparateur) : il n'y a rien à choisir,
              // c'est forcément pour lui-même — pas de sélecteur.
              const _AutonomeBanner()
            else
              FutureBuilder<List<({String id, String nom})>>(
                future: ref
                    .read(administrationServiceProvider)
                    .preparateursActifs(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Text(
                      'Impossible de charger les préparateurs.',
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final preparateurs = snapshot.data!;
                  if (preparateurs.isEmpty) {
                    // Sans ceci, le champ se contente d'apparaître vide et
                    // le bouton "Importer" reste grisé sans aucune
                    // explication — source de confusion vérifiée (le
                    // fichier est pourtant bien accepté à cette étape).
                    return Container(
                      padding: const EdgeInsets.all(AppDimensions.cardPadding),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.1),
                        borderRadius:
                            BorderRadius.circular(AppDimensions.cornerRadius),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: AppColors.warning),
                          SizedBox(width: AppDimensions.spacingSm),
                          Expanded(
                            child: Text(
                              'Aucun préparateur actif. Créez-en un depuis '
                              'l\'onglet Utilisateurs avant d\'importer.',
                              style: AppTypography.body,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return DropdownButtonFormField<String>(
                    initialValue: _selectedPreparateurId,
                    decoration: const InputDecoration(
                      labelText: 'Préparateur destinataire',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final p in preparateurs)
                        DropdownMenuItem(value: p.id, child: Text(p.nom)),
                    ],
                    onChanged: (value) =>
                        setState(() => _selectedPreparateurId = value),
                  );
                },
              ),
            const SizedBox(height: AppDimensions.spacingLg),
            PrimaryButton(
              label: 'Importer',
              isLoading: _isImporting,
              onPressed: (_fileBytes != null &&
                      _detectedFormat != null &&
                      _selectedPreparateurId != null)
                  ? _import
                  : null,
            ),
            if (_isImporting && _progressDone != null && _progressTotal != null) ...[
              const SizedBox(height: AppDimensions.spacingMd),
              _ImportProgressBar(
                done: _progressDone!,
                total: _progressTotal!,
                tempsRestant: _tempsRestantEstime(),
              ),
            ],
            if (_lastReport != null) ...[
              const SizedBox(height: AppDimensions.spacingLg),
              _ImportReportView(report: _lastReport!),
            ],
          ],
        ),
      ),
    );
  }
}

/// Progression réelle d'un import volumineux — pourcentage et temps
/// restant estimé, plutôt qu'un simple indicateur "ça charge" qui pouvait
/// donner l'impression d'une appli bloquée sur une grosse picking list
/// (des centaines de produits, plusieurs dizaines de secondes).
class _ImportProgressBar extends StatelessWidget {
  const _ImportProgressBar({
    required this.done,
    required this.total,
    required this.tempsRestant,
  });

  final int done;
  final int total;
  final String? tempsRestant;

  @override
  Widget build(BuildContext context) {
    final progression = total == 0 ? 0.0 : done / total;
    final pourcentage = (progression * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppDimensions.cornerRadius),
          child: LinearProgressIndicator(value: progression, minHeight: 8),
        ),
        const SizedBox(height: AppDimensions.spacingXs),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$pourcentage % — $done/$total produits',
              style: AppTypography.secondaryLabel,
            ),
            if (tempsRestant != null)
              Text(tempsRestant!, style: AppTypography.secondaryLabel),
          ],
        ),
      ],
    );
  }
}

class _AutonomeBanner extends StatelessWidget {
  const _AutonomeBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppDimensions.cornerRadius),
      ),
      child: const Row(
        children: [
          Icon(Icons.person_outline, color: AppColors.primary),
          SizedBox(width: AppDimensions.spacingSm),
          Expanded(
            child: Text(
              'Cette tournée sera ajoutée directement à votre compte.',
              style: AppTypography.body,
            ),
          ),
        ],
      ),
    );
  }
}

/// Zone de dépôt du fichier — dessinée, contour pointillé, réagit
/// visuellement au survol pendant un glisser-déposer.
class _DropZone extends StatelessWidget {
  const _DropZone({
    required this.fileName,
    required this.isDragging,
    required this.formatUnrecognized,
    required this.onBrowse,
  });

  final String? fileName;
  final bool isDragging;
  final bool formatUnrecognized;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onBrowse,
      borderRadius: BorderRadius.circular(AppDimensions.cornerRadiusLg),
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: isDragging ? AppColors.primary : AppColors.divider,
          radius: AppDimensions.cornerRadiusLg,
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            vertical: AppDimensions.spacingXl,
            horizontal: AppDimensions.spacingLg,
          ),
          decoration: BoxDecoration(
            color: isDragging ? AppColors.primarySoft : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(AppDimensions.cornerRadiusLg),
          ),
          child: Column(
            children: [
              Icon(
                fileName == null
                    ? Icons.upload_file_outlined
                    : Icons.insert_drive_file_outlined,
                size: 48,
                color: AppColors.primary,
              ),
              const SizedBox(height: AppDimensions.spacingMd),
              Text(
                fileName ?? 'Déposez votre picking list',
                style: AppTypography.body.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppDimensions.spacingXs),
              Text(
                fileName == null
                    ? 'Glissez-déposez votre fichier ou cliquez pour parcourir'
                    : 'Cliquez pour choisir un autre fichier',
                style: AppTypography.secondaryLabel,
                textAlign: TextAlign.center,
              ),
              if (formatUnrecognized) ...[
                const SizedBox(height: AppDimensions.spacingSm),
                const Text(
                  'Format non reconnu à partir de l\'extension du fichier.',
                  style: TextStyle(color: AppColors.error),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: AppDimensions.spacingMd),
              Text(
                'PDF, Excel, CSV, JSON',
                style: AppTypography.secondaryLabel.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    const dashWidth = 6.0;
    const dashSpace = 5.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dashWidth),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}

/// Affiche le rapport d'import (Directive : "Produire un rapport
/// d'import").
class _ImportReportView extends StatelessWidget {
  const _ImportReportView({required this.report});

  final ImportReport report;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: report.succes
          ? AppColors.success.withValues(alpha: 0.08)
          : AppColors.error.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  report.succes ? Icons.check_circle : Icons.error,
                  color: report.succes ? AppColors.success : AppColors.error,
                ),
                const SizedBox(width: AppDimensions.spacingSm),
                Text(
                  report.succes
                      ? (report.dejaImportee
                          ? 'Tournée déjà importée — rien dupliqué'
                          : 'Import réussi')
                      : 'Import refusé',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            if (report.numeroTournee != null)
              Text('Tournée : ${report.numeroTournee}'),
            Text('Produits détectés : ${report.nombreProduits}'),
            Text('Durée : ${report.duree.inMilliseconds} ms'),
            if (report.erreurs.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.spacingSm),
              const Text(
                'Erreurs :',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              for (final erreur in report.erreurs)
                Text(
                  '• ${erreur.message}'
                  '${erreur.ligneSource != null ? ' (ligne ${erreur.ligneSource})' : ''}',
                  style: const TextStyle(color: AppColors.error),
                ),
            ],
            if (report.avertissements.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.spacingSm),
              const Text(
                'Avertissements :',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              for (final avertissement in report.avertissements)
                Text(
                  '• ${avertissement.message}',
                  style: const TextStyle(color: AppColors.warning),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
