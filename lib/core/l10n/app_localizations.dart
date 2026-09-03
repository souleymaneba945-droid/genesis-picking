import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Système d'internationalisation de l'application.
///
/// Conçu pour être prêt à accueillir d'autres langues (voir Module 1,
/// exigence "internationalisation prête") même si, en V1, seul le
/// français (`assets/l10n/app_fr.arb`) est fourni. Ajouter une langue se
/// résume à : créer `app_xx.arb`, l'ajouter à [AppLocalizations.supportedLocales]
/// et à la liste `assets` de `pubspec.yaml`.
///
/// Implémentation volontairement autonome (sans génération de code via
/// `flutter gen-l10n`) pour ce module de fondation : les fichiers `.arb`
/// sont chargés et interprétés directement au démarrage. Elle pourra être
/// remplacée par la génération officielle `intl`/`gen-l10n` sans changer
/// la façon dont les écrans appellent `AppLocalizations.of(context)`.
class AppLocalizations {
  AppLocalizations(this._strings);

  final Map<String, String> _strings;

  static const List<Locale> supportedLocales = [Locale('fr')];

  static AppLocalizations of(BuildContext context) {
    final localizations = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    if (localizations == null) {
      throw StateError(
        'AppLocalizations.of() appelé sans AppLocalizationsDelegate '
        'enregistré dans MaterialApp.',
      );
    }
    return localizations;
  }

  String get appName => _get('appName');
  String get genericLoading => _get('genericLoading');
  String get noTourneeAvailable => _get('noTourneeAvailable');
  String get errorInvalidCredentials => _get('errorInvalidCredentials');
  String get errorAccountDisabled => _get('errorAccountDisabled');
  String get errorGeneric => _get('errorGeneric');
  String get offlineNotice => _get('offlineNotice');

  String _get(String key) {
    return _strings[key] ?? '‼ clé de traduction manquante : $key';
  }
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales.any(
      (supported) => supported.languageCode == locale.languageCode,
    );
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final raw = await rootBundle.loadString(
      'assets/l10n/app_${locale.languageCode}.arb',
    );
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final strings = <String, String>{
      for (final entry in decoded.entries)
        if (!entry.key.startsWith('@')) entry.key: entry.value as String,
    };
    return AppLocalizations(strings);
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}
