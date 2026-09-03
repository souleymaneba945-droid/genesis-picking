import 'dart:async';

import 'package:flutter/material.dart';
import 'package:genesis_picking/core/theme/app_colors.dart';
import 'package:genesis_picking/core/theme/app_dimensions.dart';
import 'package:genesis_picking/core/theme/app_typography.dart';

/// Chronomètre en direct — temps écoulé depuis [depuis], mis à jour
/// chaque seconde. Widget à état PROPRE et minimal (au lieu de rendre
/// tout [PickingScreen] "stateful" pour ça) : seul ce petit chip a besoin
/// de se reconstruire chaque seconde, jamais le reste de l'écran.
class LiveDurationChip extends StatefulWidget {
  const LiveDurationChip({required this.depuis, super.key});

  final DateTime depuis;

  @override
  State<LiveDurationChip> createState() => _LiveDurationChipState();
}

class _LiveDurationChipState extends State<LiveDurationChip> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ecoule = DateTime.now().difference(widget.depuis);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingSm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, size: 16, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            _formatDuree(ecoule),
            style: AppTypography.chipLabel.copyWith(color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  String _formatDuree(Duration d) {
    final heures = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final secondes = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (heures > 0) {
      return '${heures}h ${minutes.toString().padLeft(2, '0')}min';
    }
    return '${minutes}min ${secondes}s';
  }
}
