import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/core/errors/error_handler.dart';
import 'package:genesis_picking/core/providers/core_providers.dart';
import 'package:genesis_picking/core/theme/app_colors.dart';
import 'package:genesis_picking/core/theme/app_dimensions.dart';
import 'package:genesis_picking/core/theme/app_typography.dart';
import 'package:genesis_picking/core/widgets/branding/app_logo_mark.dart';
import 'package:genesis_picking/core/widgets/buttons/primary_button.dart';
import 'package:genesis_picking/core/widgets/feedback/app_snackbar.dart';
import 'package:genesis_picking/features/auth/auth_providers.dart';
import 'package:genesis_picking/features/auth/presentation/session_revocation_message.dart';

/// Écran de connexion (Processus 1).
///
/// Remplace `login_placeholder_screen.dart` du Module 1. Volontairement
/// simple : un champ identifiant, un champ mot de passe, un seul bouton
/// d'action — conforme à la règle "maximum 3 actions principales par
/// écran" (PRD, chapitre 7) et à l'écran 4.1 du Cahier des charges.
///
/// Modernisation visuelle (12/09/2026, maquette v0.dev fournie par
/// l'utilisateur — voir mémoire `v0-design-modernization`) : en-tête
/// dégradé bleu + logo, carte de connexion arrondie par-dessus. Volontai-
/// rement PAS reproduit : le bloc "Comptes de démonstration" de la
/// maquette, qui affichait des identifiants/mots de passe en clair
/// directement sur l'écran de connexion — contraire à la règle "jamais de
/// mot de passe en clair" déjà actée (Module 5 v2, Rubrique 3) et
/// dangereux dès que ce compte de démo réel (`admin`/`genesis`, voir
/// `DatabaseSeeder`) tourne sur un appareil qui n'est plus entre des
/// mains de confiance.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _identifiantController = TextEditingController();
  final _motDePasseController = TextEditingController();
  bool _isSubmitting = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    // Module 5 v2, Rubrique 3 : affiche, une seule fois, le message laissé
    // par `AccountRevocationWatcher` si cette arrivée sur l'écran de
    // connexion vient d'une révocation à distance — jamais pour une
    // déconnexion volontaire, qui ne dépose aucun message.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final message =
          ref.read(sessionRevocationMessageProvider.notifier).consume();
      if (message != null && mounted) {
        AppSnackbar.showError(context, message);
      }
    });
  }

  @override
  void dispose() {
    _identifiantController.dispose();
    _motDePasseController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final identifiant = _identifiantController.text.trim();
    final motDePasse = _motDePasseController.text;

    if (identifiant.isEmpty || motDePasse.isEmpty) {
      AppSnackbar.showError(context, 'Veuillez renseigner ces deux champs.');
      return;
    }

    setState(() => _isSubmitting = true);

    final authService = ref.read(authServiceProvider);
    final result = await authService.login(
      identifiant: identifiant,
      motDePasse: motDePasse,
    );

    if (!mounted) return;

    await result.when(
      success: (session) async {
        await ref.read(sessionProvider.notifier).open(session);
        // La redirection vers l'accueil du rôle est gérée automatiquement
        // par `app_router.dart` (redirect), pas ici.
      },
      failure: (exception) async {
        AppSnackbar.showError(context, ErrorHandler.userMessageFor(exception));
      },
    );

    if (mounted) setState(() => _isSubmitting = false);
  }

  void _showForgotPasswordHelp() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mot de passe oublié'),
        content: const Text(
          'Aucune réinitialisation automatique n\'est disponible. '
          'Contactez votre administrateur : il peut réinitialiser '
          'votre mot de passe depuis la Gestion des comptes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _Header(),
                  Transform.translate(
                    // Chevauche légèrement l'en-tête, comme une feuille qui
                    // remonte par-dessus (maquette v0.dev).
                    offset: const Offset(0, -24),
                    child: _LoginCard(
                      identifiantController: _identifiantController,
                      motDePasseController: _motDePasseController,
                      obscurePassword: _obscurePassword,
                      isSubmitting: _isSubmitting,
                      onToggleObscure: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      onSubmit: _submit,
                      onForgotPassword: _showForgotPasswordHelp,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// En-tête plein `primary` avec un semis de points en surimpression —
/// PAS un dégradé (correction 12/09/2026, à la lecture du code source
/// réel du prototype v0.dev `genesis-picking-wa/login-screen.tsx` :
/// `bg-primary` uni + `radial-gradient` répété en grille 22px, opacité
/// 0.15 — l'impression de dégradé sur la capture d'écran initiale venait
/// de la compression JPEG/de l'éclairage, pas d'un vrai dégradé).
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.spacingLg,
        AppDimensions.spacingXl,
        AppDimensions.spacingLg,
        AppDimensions.spacingXl + 24,
      ),
      color: AppColors.primary,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _DotPatternPainter()),
          ),
          Column(
            children: [
              const AppLogoMark(size: 64, onDarkBackground: true),
              const SizedBox(height: AppDimensions.spacingMd),
              const Text(
                'GENESIS PICKING',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: AppDimensions.spacingXs),
              Text(
                'Préparation de commandes guidée pour votre équipe logistique',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Semis de points espacés de 22px, opacité 15% — reproduit le
/// `radial-gradient(circle at 1px 1px, currentColor 1px, transparent 0)`
/// du prototype source (un dégradé radial RÉPÉTÉ sert de motif de points
/// en CSS, jamais un vrai dégradé de couleur).
class _DotPatternPainter extends CustomPainter {
  static const double _espacement = 22;
  static const double _rayon = 1;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.15);
    for (double y = 0; y < size.height + _espacement; y += _espacement) {
      for (double x = 0; x < size.width + _espacement; x += _espacement) {
        canvas.drawCircle(Offset(x, y), _rayon, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.identifiantController,
    required this.motDePasseController,
    required this.obscurePassword,
    required this.isSubmitting,
    required this.onToggleObscure,
    required this.onSubmit,
    required this.onForgotPassword,
  });

  final TextEditingController identifiantController;
  final TextEditingController motDePasseController;
  final bool obscurePassword;
  final bool isSubmitting;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;
  final VoidCallback onForgotPassword;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingMd),
      padding: const EdgeInsets.all(AppDimensions.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.cornerRadiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Connexion',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppDimensions.spacingXs),
          const Text(
            'Accédez à votre espace de préparation.',
            style: AppTypography.secondaryLabel,
          ),
          const SizedBox(height: AppDimensions.spacingLg),
          const _FieldLabel('Identifiant'),
          const SizedBox(height: AppDimensions.spacingXs),
          _RoundedField(
            controller: identifiantController,
            hintText: 'ex. souleymane',
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          const _FieldLabel('Mot de passe'),
          const SizedBox(height: AppDimensions.spacingXs),
          _RoundedField(
            controller: motDePasseController,
            hintText: '••••••••',
            obscureText: obscurePassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onSubmit(),
            suffixIcon: IconButton(
              icon: Icon(
                obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: AppColors.textSecondary,
              ),
              onPressed: onToggleObscure,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingLg),
          PrimaryButton(
            label: 'Se connecter',
            isLoading: isSubmitting,
            onPressed: onSubmit,
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          TextButton(
            onPressed: onForgotPassword,
            child: const Text('Mot de passe oublié ?'),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    );
  }
}

/// Champ de saisie — fond `background` (pas `surfaceAlt`) avec une fine
/// bordure `divider`, comme le prototype source
/// (`border border-input bg-background`) : sur cet écran précis, la carte
/// de connexion est blanche et l'app en dessous a un fond légèrement
/// teinté — un champ sans bordure s'y fondrait complètement.
class _RoundedField extends StatelessWidget {
  const _RoundedField({
    required this.controller,
    required this.hintText,
    this.obscureText = false,
    this.textInputAction,
    this.onSubmitted,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor: AppColors.background,
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.cornerRadiusSm),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.cornerRadiusSm),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.cornerRadiusSm),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingMd,
          vertical: AppDimensions.spacingMd,
        ),
      ),
    );
  }
}
