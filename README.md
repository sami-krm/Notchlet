# DynamicNotch

Une « Dynamic Island » pour Mac, en Swift, SwiftUI et AppKit. Ce projet personnel est inspiré d'Alcove, sans en reprendre le code ni les ressources.

## Ce que fait l'app

- Une île noire posée sur l'encoche, ou une pilule simulée en haut de l'écran sur les Mac sans encoche.
- **Survol** : après un délai réglable, l'île s'ouvre avec une animation « spring ». Elle se referme quand la souris s'éloigne.
- **Live activity** : quand Spotify ou Musique joue, l'île s'élargit et affiche la pochette à gauche et un égaliseur animé à droite.
- **Vue ouverte** : date, batterie, pochette, morceau en cours avec précédent / lecture-pause / suivant, barre de progression (clique ou fais-la glisser pour avancer ou reculer), et l'heure.
- **Styles de couleur** : pochette (fond flou), coloré (couleur de la pochette sur l'égaliseur et la progression), dégradé (fond coloré), monochrome (noir et blanc).
- **Gestes au trackpad**, à deux doigts sur l'île : vers le bas pour ouvrir, vers le haut pour fermer, vers la gauche pour le morceau suivant, vers la droite pour le précédent.
- **Alertes de batterie** : quelques secondes dans l'île au branchement du chargeur et quand la batterie passe sous le seuil, avec un son (ceux de macOS). L'alerte s'affiche à la place de la musique, qui revient ensuite. Île ouverte, elle prend la place de la date.
- **HUD volume et luminosité** (à activer dans l'onglet HUD) : remplace les HUD de macOS par une jauge dans l'île, avec le nom de la sortie audio. Avec Maj, Option, Contrôle ou Commande, les touches restent gérées par macOS.
- **Appareils Bluetooth** (à activer dans l'onglet Bluetooth) : à la connexion, l'île affiche l'icône de l'appareil avec un petit rebond, son nom et sa batterie. Pour des écouteurs, c'est le niveau le plus faible des deux.
- Une icône dans la barre des menus donne accès aux réglages et permet de quitter l'app.

## Réglages

Ouvre-les depuis l'icône de la barre des menus, avec **Réglages…**.

- **Lancer à l'ouverture de session** : macOS peut demander ton accord dans Réglages Système > Général > Ouverture. Active cette option depuis la copie de l'app que tu gardes, de préférence dans le dossier Applications.
- **Délai de survol** : de 0 à 1 seconde (0,2 seconde par défaut).
- **Écran** : automatique (l'écran à encoche, sinon l'écran principal) ou un écran précis.
- **Masquer l'île en plein écran** : activé par défaut. L'île disparaît des apps en plein écran au sens de macOS, c'est-à-dire qui occupent leur propre espace.
- **Style de couleur** : dans l'onglet Lecture en cours.
- **Alertes de batterie** : dans l'onglet Batterie, avec un seuil de 5 à 50 % (20 % par défaut) et un son désactivable.
- **HUD** : dans l'onglet HUD, avec la luminosité désactivable, le style de barre (blanc, couleur d'accent, lumineux), la vitesse d'animation et l'affichage de la sortie audio.

## Permissions

| Permission | Pourquoi | Où la gérer |
|---|---|---|
| Automatisation | Lire la pochette et la position, et contrôler Spotify ou Musique | Réglages Système > Confidentialité et sécurité > Automatisation |
| Accessibilité | Intercepter les touches de volume et de luminosité pour le HUD | Réglages Système > Confidentialité et sécurité > Accessibilité |
| Bluetooth | Détecter la connexion des appareils | Réglages Système > Confidentialité et sécurité > Bluetooth |

macOS la demande dès le premier morceau détecté. Sans elle, l'île affiche l'icône de l'app au lieu de la pochette, sans barre de progression, et les boutons restent sans effet.

L'Accessibilité n'est demandée que lorsque tu actives le HUD, et le Bluetooth lorsque tu actives son onglet. La batterie des appareils vient de l'outil système `system_profiler`, sans API privée, mais son format n'est pas documenté. Les gestes et les alertes de batterie ne demandent aucune permission.

**API privée :** le HUD de luminosité utilise DisplayServices, une API non documentée d'Apple (voir `Sources/DynamicNotch/Private`). Si une mise à jour de macOS la retire, ces touches reviennent à macOS. Pour Spotify, la pochette est téléchargée depuis l'adresse HTTPS fournie par l'app.

## Lancer le projet

Il faut macOS 13 ou plus récent pour lancer l'app, et Xcode 16 ou plus récent pour la compiler.

1. Ouvre `DynamicNotch.xcodeproj` dans Xcode.
2. Choisis le schéma `DynamicNotch` > `My Mac`, puis ⌘R.

Pour lancer les tests : ⌘U dans Xcode, ou dans le Terminal :

```bash
xcodebuild test -project DynamicNotch.xcodeproj -scheme DynamicNotch -destination 'platform=macOS'
```

Le projet compile sans compte Apple, avec une signature ad hoc, mais macOS peut alors redemander l'Accessibilité après chaque compilation. Pour l'éviter, signe avec ton certificat en suivant les indications de `Config/Signing.xcconfig`.

## Organisation du code

| Dossier | Rôle |
|---|---|
| `Sources/DynamicNotch/App` | Démarrage, barre des menus, clés de réglages |
| `Sources/DynamicNotch/Window` | Fenêtre transparente, survol, taille de l'encoche |
| `Sources/DynamicNotch/Island` | État, forme et interface de l'île |
| `Sources/DynamicNotch/Activities` | Protocole `Activity` et activités affichées dans l'île |
| `Sources/DynamicNotch/Managers` | Accès au système : musique, batterie, HUD, sortie audio, Bluetooth, lancement à l'ouverture de session |
| `Sources/DynamicNotch/Private` | Code qui dépend d'API privées d'Apple |
| `Sources/DynamicNotch/SettingsUI` | Fenêtre et onglets de réglages |
| `Tests/DynamicNotchTests` | Tests unitaires |

Une activité brève (HUD, alerte) remplace l'activité de fond quelques secondes, puis celle-ci revient.
