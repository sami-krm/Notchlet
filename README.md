# DynamicNotch

Une « Dynamic Island » pour Mac, en Swift, SwiftUI et AppKit. Ce projet personnel est inspiré d'Alcove, sans en reprendre le code ni les ressources.

## Ce que fait l'app

- Une île noire posée sur l'encoche, ou une pilule simulée en haut de l'écran sur les Mac sans encoche.
- **Survol** : l'île s'ouvre avec une animation « spring ». Elle se referme quand la souris s'éloigne.
- **Live activity** : quand Spotify ou Musique joue, l'île s'élargit et affiche l'icône de l'app à gauche et un égaliseur animé à droite.
- **Vue ouverte** : date, batterie, morceau en cours avec précédent / lecture-pause / suivant, et l'heure.
- Une icône dans la barre des menus permet de quitter l'app.

## Permissions

| Permission | Pourquoi | Où la gérer |
|---|---|---|
| Automatisation | Contrôler Spotify ou Musique (lecture-pause, morceau suivant ou précédent) | Réglages Système > Confidentialité et sécurité > Automatisation |

macOS la demande au premier clic sur un bouton de lecture. L'autorisation concerne désormais l'app DynamicNotch, et non plus Xcode ou Terminal.

## Lancer le projet

Il faut macOS 13 ou plus récent pour lancer l'app, et Xcode 16 ou plus récent pour la compiler.

1. Ouvre `DynamicNotch.xcodeproj` dans Xcode.
2. Choisis le schéma `DynamicNotch` > `My Mac`, puis ⌘R.

Pour lancer les tests : ⌘U dans Xcode, ou dans le Terminal :

```bash
xcodebuild test -project DynamicNotch.xcodeproj -scheme DynamicNotch -destination 'platform=macOS'
```

## Organisation du code

| Dossier | Rôle |
|---|---|
| `Sources/DynamicNotch/App` | Démarrage, barre des menus, clés de réglages |
| `Sources/DynamicNotch/Window` | Fenêtre transparente, survol, taille de l'encoche |
| `Sources/DynamicNotch/Island` | État, forme et interface de l'île |
| `Sources/DynamicNotch/Activities` | Protocole `Activity` et activités affichées dans l'île |
| `Sources/DynamicNotch/Managers` | Accès au système : musique, batterie |
| `Tests/DynamicNotchTests` | Tests unitaires |

Une activité brève (HUD, alerte) remplace l'activité de fond quelques secondes, puis celle-ci revient.
