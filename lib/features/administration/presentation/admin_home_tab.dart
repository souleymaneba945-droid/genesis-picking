import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/core/theme/app_colors.dart';
import 'package:genesis_picking/core/theme/app_dimensions.dart';
import 'package:genesis_picking/core/theme/app_typography.dart';
import 'package:genesis_picking/core/widgets/status/stat_card.dart';
import 'package:genesis_picking/features/administration/administration_providers.dart';
import 'package:genesis_picking/features/courier/data/courier_request.dart';
import 'package:genesis_picking/features/courier/data/courier_request_status.dart';
import 'package:genesis_picking/features/profile/presentation/profile_screen.dart';
import 'package:genesis_picking/features/tours/data/tour.dart';

/// Onglet "Tableau de bord" de l'Administrateur (Refonte UI) — vue
/// d'ensemble en tuiles, plutôt qu'une bannière + une liste : le détail des
/// tournées vit dans l'onglet "Tournées", le détail des demandes coursier
/// dans "Suivi". Réutilise exactement les mêmes appels
/// [AdministrationService] que l'ancien tableau de bord.
///
/// L'Administrateur n'a pas d'onglet "Profil" dédié (seulement 4 onglets) —
/// l'accès au profil/mot de passe reste disponible ici, en action rapide.
class AdminHomeTab extends ConsumerStatefulWidget {
  const AdminHomeTab({super.key});

  @override
  ConsumerState<AdminHomeTab> createState() => _AdminHomeTabState();
}

class _AdminHomeTabState extends ConsumerState<AdminHomeTab> {
  late Future<List<Tour>> _toursFuture;
  late Future<List<CourierRequest>> _demandesFuture;

  @override
  void initState() {
    super.initState();
    _toursFuture = ref.read(administrationServiceProvider).tourneesEnCours();
    _demandesFuture =
        ref.read(administrationServiceProvider).toutesLesDemandes();
  }

  void _refresh() {
    setState(() {
      _toursFuture = ref.read(administrationServiceProvider).tourneesEnCours();
      _demandesFuture =
          ref.read(administrationServiceProvider).toutesLesDemandes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        _refresh();
        await _toursFuture;
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.spacingLg,
          AppDimensions.spacingSm,
          AppDimensions.spacingLg,
          AppDimensions.spacingLg,
        ),
        children: [
          Row(
            children: [
              const Expanded(
                child:
                    Text('Tableau de bord', style: AppTypography.screenTitle),
              ),
              IconButton(
                icon: const Icon(Icons.person_outline),
                tooltip: 'Profil',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: FutureBuilder<List<Tour>>(
                    future: _toursFuture,
                    builder: (context, snapshot) => StatCard(
                      value: '${snapshot.data?.length ?? '—'}',
                      label: 'tournées actives',
                      icon: Icons.local_shipping_outlined,
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingSm),
                Expanded(
                  child: FutureBuilder<List<CourierRequest>>(
                    future: _demandesFuture,
                    builder: (context, snapshot) {
                      final ouvertes = (snapshot.data ?? const [])
                          .where(
                            (d) =>
                                d.etat != CourierRequestStatus.traitee &&
                                d.etat != CourierRequestStatus.terminee,
                          )
                          .length;
                      return StatCard(
                        value: '$ouvertes',
                        label: 'demandes ouvertes',
                        icon: Icons.support_agent_outlined,
                        color: ouvertes > 0
                            ? AppColors.warning
                            : AppColors.success,
                      );
                    },
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
