# Instructions du projet DynamicNotch

## Le projet
DynamicNotch est une « Dynamic Island » pour Mac, développée par un étudiant en BUT pour apprendre et pour une diffusion publique.
Le modèle de référence est **Alcove 1.7.7** (tryalcove.com). Objectif à terme : reproduire toutes ses fonctionnalités, puis aller au-delà.
Le développement et les tests se font sur un MacBook avec Xcode.
Diffusion : code public sur GitHub, téléchargements via GitHub Releases, sans compte développeur Apple pour l'instant (donc sans notarisation ni WeatherKit).
Priorités : musique, HUD volume et luminosité, batterie et AirPods. API publiques d'abord ; les API privées arrivent en dernier, isolées et désactivables.

## Stack technique (à respecter)
- **Langage** : Swift 5.9+ (mode de langage Swift 5 tant que le projet n'est pas migré vers Swift 6).
- **UI** : SwiftUI pour toutes les vues. AppKit seulement pour la fenêtre (`NSPanel`), la barre des menus et ce que SwiftUI ne sait pas faire.
- **Cible** : macOS 13 minimum. Une fonctionnalité qui exige macOS 14 ou 15 passe derrière `if #available`.
- **Projet** : projet Xcode « macOS App » (`DynamicNotch.xcodeproj`), signature locale ad hoc. Les fichiers ajoutés dans `Sources/` et `Tests/` sont pris en compte automatiquement.
- **Dépendances** : aucune, sauf accord explicite. Frameworks Apple uniquement.

## Architecture
```
Sources/DynamicNotch/
  App/
    main.swift                  Point d'entrée, app "accessoire" (pas d'icône dans le Dock)
    AppDelegate.swift           Démarrage, icône de la barre des menus, changements d'écran
    Settings.swift              Clés @AppStorage
  Window/
    NotchWindowController.swift NSPanel transparent au-dessus de la barre des menus, survol
    NotchGeometry.swift         Taille de l'encoche réelle ou simulée
  Island/
    NotchViewModel.swift        État de l'île, tailles, rayons, file d'activités
    NotchShape.swift            Forme animable de l'île
    NotchView.swift             Interface SwiftUI
  Activities/
    Activity.swift              Protocole commun des activités
    MusicActivity.swift         Morceau en cours dans l'île fermée
  Managers/
    MediaManager.swift          Musique (notifications Spotify/Musique, commandes AppleScript)
    BatteryManager.swift        Batterie (IOKit)
Tests/DynamicNotchTests/        Tests unitaires
```
Dossiers à créer quand ils serviront : `SettingsUI/` (fenêtre de réglages) et `Private/` (API privées, chaque fonction désactivable).
Règles :
- **Un fichier par service** (`CalendarManager`, `HUDManager`, `BluetoothManager`…), chacun en `ObservableObject` avec des propriétés `@Published`.
- **Une activité = un type** conforme au protocole `Activity`. Une activité brève (HUD, alerte) passe par la file du ViewModel : elle remplace l'activité de fond quelques secondes, puis celle-ci revient. Le mode « Duo » viendra plus tard.
- **Une seule fenêtre**, placée sur l'écran choisi dans les réglages. L'île s'ouvre au survol, avec un délai réglable.
- Les vues ne parlent jamais directement à IOKit, AppleScript ou EventKit : elles passent toujours par un manager.
- Les réglages sont stockés avec `@AppStorage`, et leurs clés sont regroupées dans un seul fichier `Settings.swift`.
- Les classes liées à l'interface sont `@MainActor`. Pour les timers et les notifications, on préfère les observateurs à sélecteur (`#selector`) aux closures `@Sendable`.

## Feuille de route (inspirée d'Alcove)
0. **Étape 0** : fondations. Git et GitHub, projet Xcode, rangement des dossiers, protocole `Activity`, `Settings.swift`.
1. **Étape 1** : fenêtre de réglages, délai de survol, choix de l'écran, masquage en plein écran, lancement à l'ouverture de session (`SMAppService`).
2. **Étape 2** : musique. Pochette d'album, barre de progression, styles de couleur (pochette, coloré, dégradé, monochrome), gestes au trackpad (balayage vertical pour ouvrir ou fermer, horizontal pour changer de morceau).
3. **Étape 3** : batterie. Alertes de charge et de batterie faible (seuil réglable, son). Première activité brève.
4. **Étape 4** : HUD volume et luminosité (`CGEventTap` et permission Accessibilité). Styles de barre, vitesse d'animation, appareil de sortie audio.
5. **Étape 5** : AirPods et appareils Bluetooth (batterie, animation).
6. **Étape 6** : première version publique. GitHub Releases, licence, guide d'installation.
7. **Étape 7** : calendrier avec EventKit (événements à venir, rappel, bouton « Rejoindre » pour Meet, Teams, Zoom et Webex). Carillon horaire. Notifications de l'île avec durées réglables.
8. **Étape 8** : météo (API gratuite comme Open-Meteo), onde sonore en direct (capture audio), étagère de fichiers, modes de concentration.
9. **Étape 9** : API privées, fragiles : lecture système, onglets de navigateur, écran verrouillé.

À chaque étape, on livre une version qui compile et qui marche avant de passer à la suivante.

## Façon de travailler avec moi
- **Réponds en français.** Le code (noms de types, variables, fonctions) est en anglais. Les commentaires et les textes affichés dans l'interface sont en français.
- **Explique au fil du code**, sans paraphraser chaque ligne. Je suis en BUT après deux ans de prépa : j'ai de bonnes bases en logique et en maths, mais je découvre Swift et macOS. Explique les concepts propres à Apple (ex. `NSPanel`, `@Published`, `@MainActor`, TCC/permissions) la première fois qu'ils apparaissent.
- **Donne des fichiers complets**, pas des fragments du genre « remplace la ligne 42 ». Pour une petite modification, montre la fonction entière concernée.
- **Dis clairement si le code n'a pas été compilé** (par exemple quand il a été écrit hors macOS) et ce qui risque d'échouer.
- Quand une erreur Xcode est collée, corrige-la d'abord, puis explique la cause en une ou deux phrases.
- **Signale les permissions** qu'une fonctionnalité demande (Accessibilité, Automatisation, Calendrier, Bluetooth, Localisation, Capture audio), et comment les accorder dans Réglages Système.
- Si une fonctionnalité d'Alcove repose sur des API privées ou non documentées, dis-le avant de la coder et propose une alternative stable quand il y en a une.
- Ne copie ni le code, ni les ressources (sons, vidéos AirPods, icônes) d'Alcove : on s'en inspire, on ne le copie pas.

## Qualité
- Le projet doit compiler sans erreur à chaque livraison. Les avertissements sont tolérés s'ils sont expliqués.
- Performance : pas de polling plus rapide que nécessaire (~10 Hz au maximum pour la souris), et pas de travail lourd sur le thread principal.
- Tester sur un Mac avec encoche et en mode encoche simulée.
- Le README.md est mis à jour à chaque nouvelle fonctionnalité : ce qu'elle fait, et les permissions qu'elle demande.
