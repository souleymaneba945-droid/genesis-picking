import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/core/session/user_role.dart';
import 'package:genesis_picking/core/theme/app_colors.dart';
import 'package:genesis_picking/core/theme/app_dimensions.dart';
import 'package:genesis_picking/core/theme/app_typography.dart';
import 'package:genesis_picking/core/widgets/branding/initials_avatar.dart';
import 'package:genesis_picking/core/widgets/status/stat_card.dart';
import 'package:genesis_picking/core/widgets/status/status_pill.dart';
import 'package:genesis_picking/features/administration/administration_providers.dart';
import 'package:genesis_picking/features/auth/auth_providers.dart';
import 'package:genesis_picking/features/auth/data/user_account.dart';
import 'package:genesis_picking/features/courier/data/courier_request.dart';
import 'package:genesis_picking/features/courier/data/courier_request_status.dart';
import 'package:genesis_picking/features/settings/presentation/settings_screen.dart';
import 'package:genesis_picking/features/tours/data/tour.dart';

/// Onglet "Tableau de bord" de l'Administrateur (Refonte UI) — vue
/// d'ensemble en tuiles, plutôt qu'une bannière + une liste : le détail des
/// tournées vit dans l'onglet "Tournées", le détail des demandes coursier
/// dans "Suivi". Réutilise exactement les mêmes appels
/// [AdministrationService] que l'ancien tableau de bord.
///
/// L'Administrateur n'a pas d'onglet "Profil" dédié (seulement 4 onglets) —
/// l'accès à Paramètres (profil/mot de passe, synchronisation, diagnostic,
/// actualiser, redémarrer) reste disponible ici, en action rapide.
class AdminHomeTab extends ConsumerStatefulWidget {
  const AdminHomeTab({super.key});

  @override
  ConsumerState<AdminHomeTab> createState() => _AdminHomeTabState();
}

class _AdminHomeTabState extends ConsumerState<AdminHomeTab> {
  late Future<List<Tour>> _toursFuture;
  late Future<List<Tour>> _historiqueFuture;
  late Future<List<CourierRequest>> _demandesFuture;
  late Future<List<UserAccount>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _toursFuture = ref.read(administrationServiceProvider).tourneesEnCours();
    _historiqueFuture =
        ref.read(administrationServiceProvider).historiqueTournees();
    _demandesFuture =
        ref.read(administrationServiceProvider).toutesLesDemandes();
    _usersFuture = ref.read(userRepositoryProvider).listAll();
  }

  void _refresh() {
    setState(() {
      _toursFuture = ref.read(administrationServiceProvider).tourneesEnCours();
      _historiqueFuture =
          ref.read(administrationServiceProvider).historiqueTournees();
      _demandesFuture =
          ref.read(administrationServiceProvider).toutesLesDemandes();
      _usersFuture = ref.read(userRepositoryProvider).listAll();
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Console d\'administration', style: AppTypography.screenTitle),
                    Text(
                      'Supervision des préparations et de l\'équipe.',
                      style: AppTypography.secondaryLabel,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.person_outline),
                tooltip: 'Paramètres',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      // `SettingsScreen` n'a plus son propre AppBar
                      // (Modernisation visuelle, 12/09/2026) — normalement
                      // fourni par `RoleShell` pour les onglets Préparateur/
                      // Coursier ; ici, en écran séparé, c'est cet appelant
                      // qui doit le fournir.
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text('Paramètres')),
                        body: const SettingsScreen(),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          // Deux `Row` de `Expanded`, jamais un `GridView.count` à
          // `childAspectRatio` fixe — voir la même note dans
          // `preparateur_home_tab.dart` (bug constaté 13/09/2026 : tuiles
          // démesurément hautes sur une fenêtre large).
          Row(
            children: [
              Expanded(
                child: FutureBuilder<List<Tour>>(
                  future: _toursFuture,
                  builder: (context, snapshot) => StatCard(
                    // '—' aussi bien pendant le chargement qu'en cas
                    // d'erreur (jamais un 0 qui laisserait croire à
                    // "aucune commande" — voir revue Cursor du 16/09/2026,
                    // §FutureBuilder sans hasError).
                    value: snapshot.hasError ? '—' : '${snapshot.data?.length ?? '—'}',
                    label: 'Commandes',
                    icon: Icons.assignment_outlined,
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.spacingSm),
              Expanded(
                child: FutureBuilder<List<Tour>>(
                  future: _historiqueFuture,
                  builder: (context, snapshot) => StatCard(
                    value: snapshot.hasError ? '—' : '${snapshot.data?.length ?? '—'}',
                    label: 'Terminées',
                    icon: Icons.inventory_2_outlined,
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          Row(
            children: [
              Expanded(
                child: FutureBuilder<List<CourierRequest>>(
                  future: _demandesFuture,
                  builder: (context, snapshot) {
                    // Jamais un 0 en cas d'échec de chargement : ça
                    // laisserait croire "aucune vérification active" alors
                    // que la donnée est simplement indisponible — voir
                    // revue Cursor du 16/09/2026, §FutureBuilder sans
                    // hasError.
                    if (snapshot.hasError) {
                      return const StatCard(
                        value: '—',
                        label: 'Vérifs actives',
                        icon: Icons.local_shipping_outlined,
                        color: AppColors.textSecondary,
                      );
                    }
                    final ouvertes = (snapshot.data ?? const [])
                        .where(
                          (d) =>
                              d.etat != CourierRequestStatus.traitee &&
                              d.etat != CourierRequestStatus.terminee,
                        )
                        .length;
                    return StatCard(
                      value: '$ouvertes',
                      label: 'Vérifs actives',
                      icon: Icons.local_shipping_outlined,
                      color: ouvertes > 0 ? AppColors.warning : AppColors.success,
                    );
                  },
                ),
              ),
              const SizedBox(width: AppDimensions.spacingSm),
              Expanded(
                child: FutureBuilder<List<CourierRequest>>(
                  future: _demandesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const StatCard(
                        value: '—',
                        label: 'Introuvables',
                        icon: Icons.monitor_heart_outlined,
                        color: AppColors.textSecondary,
                      );
                    }
                    final introuvables = (snapshot.data ?? const [])
                        .where((d) => d.resultat == CourierRequestResult.nonRetrouve)
                        .length;
                    return StatCard(
                      value: '$introuvables',
                      label: 'Introuvables',
                      icon: Icons.monitor_heart_outlined,
                      color: introuvables > 0 ? AppColors.error : AppColors.success,
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingLg),
          FutureBuilder<List<Tour>>(
            future: _toursFuture,
            builder: (context, snapshot) {
              // Erreur ou chargement : pas de carte plutôt qu'une carte à
              // 0% trompeuse — la tuile "Commandes" ci-dessus porte déjà
              // le signal d'erreur explicite pour cette même donnée.
              if (snapshot.hasError) return const SizedBox.shrink();
              final tours = snapshot.data;
              if (tours == null || tours.isEmpty) return const SizedBox.shrink();
              final traites = tours.fold<int>(0, (s, t) => s + t.produitsTraites);
              final total = tours.fold<int>(0, (s, t) => s + t.nombreTotalProduits);
              return _GlobalProgressCard(traites: traites, total: total);
            },
          ),
          const SizedBox(height: AppDimensions.spacingLg),
          const Row(
            children: [
              Icon(Icons.people_outline, size: 18, color: AppColors.textSecondary),
              SizedBox(width: AppDimensions.spacingXs),
              Text('Équipe', style: AppTypography.sectionTitle),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          FutureBuilder<List<UserAccount>>(
            future: _usersFuture,
            builder: (context, snapshot) {
              // Sans ce cas, une erreur laissait tourner
              // `CircularProgressIndicator()` indéfiniment (`users` reste
              // `null` pour toujours) — voir revue Cursor du 16/09/2026,
              // §FutureBuilder sans hasError.
              if (snapshot.hasError) {
                return const Text(
                  'Impossible de charger l\'équipe.',
                  style: AppTypography.secondaryLabel,
                );
              }
              final users = snapshot.data;
              if (users == null) {
                return const Center(child: CircularProgressIndicator());
              }
              if (users.isEmpty) {
                return const Text(
                  'Aucun compte.',
                  style: AppTypography.secondaryLabel,
                );
              }
              return Column(
                children: [
                  for (final user in users) ...[
                    _TeamMemberRow(user: user),
                    const SizedBox(height: AppDimensions.spacingSm),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Carte "Taux d'avancement global" (Modernisation visuelle, 12/09/2026,
/// maquette v0.dev) — agrège les tournées ACTIVES déjà chargées par
/// [AdministrationService.tourneesEnCours] (jamais un nouvel appel : même
/// donnée que les tuiles au-dessus, jamais deux sources qui pourraient
/// diverger). Une tournée terminée ne compte plus dans ce total : une fois
/// à 100%, elle sort du périmètre "en cours" comme le reste du tableau de
/// bord.
class _GlobalProgressCard extends StatelessWidget {
  const _GlobalProgressCard({required this.traites, required this.total});

  final int traites;
  final int total;

  @override
  Widget build(BuildContext context) {
    final progression = total == 0 ? 0.0 : traites / total;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Taux d\'avancement global', style: AppTypography.sectionTitle),
                      const SizedBox(height: 2),
                      Text(
                        '$traites produits validés sur $total',
                        style: AppTypography.secondaryLabel,
                      ),
                    ],
                  ),
                ),
                Text(
                  '${(progression * 100).round()}%',
                  style: AppTypography.statValue.copyWith(color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.cornerRadiusPill),
              child: LinearProgressIndicator(
                value: progression,
                minHeight: 8,
                backgroundColor: AppColors.surfaceAlt,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Une ligne "Équipe" : avatar, nom, rôle, statut Actif/Inactif — un
/// résumé en lecture seule (la gestion complète, elle, reste dans l'onglet
/// "Utilisateurs"/`UserManagementScreen`, jamais dupliquée ici).
class _TeamMemberRow extends StatelessWidget {
  const _TeamMemberRow({required this.user});

  final UserAccount user;

  String get _roleLabel => switch (user.role) {
        UserRole.administrateur => 'Administrateur',
        UserRole.preparateur => 'Préparateur',
        UserRole.coursier => 'Coursier',
      };

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingSm),
        child: Row(
          children: [
            InitialsAvatar(name: user.nomAffichage),
            const SizedBox(width: AppDimensions.spacingSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(user.nomAffichage, style: AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
                  Text(_roleLabel, style: AppTypography.secondaryLabel),
                ],
              ),
            ),
            StatusPill(
              label: user.actif ? 'Actif' : 'Inactif',
              background: user.actif ? AppColors.successSoft : AppColors.surfaceAlt,
              foreground: user.actif ? AppColors.success : AppColors.textSecondary,
              icon: user.actif ? Icons.circle : null,
            ),
          ],
        ),
      ),
    );
  }
}
