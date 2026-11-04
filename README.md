# Notchlet

Une « Dynamic Island » pour Mac, en Swift, SwiftUI et AppKit. Ce projet personnel est inspiré d'Alcove, sans en reprendre le code ni les ressources.

## Installation

Il faut macOS 13 ou plus récent. L'app a été testée sur macOS 15 avec un Mac Apple Silicon à encoche.

1. Télécharge `Notchlet-x.y.z.zip` depuis la page [Releases](../../releases).
2. Ouvre le zip et place `Notchlet.app` dans le dossier Applications.
3. Ouvre l'app : macOS refuse d'abord, car elle n'est pas notarisée par Apple (cela demande un compte développeur payant).
4. Va dans Réglages Système > Confidentialité et sécurité, descends jusqu'à la section Sécurité, puis clique sur **Ouvrir quand même** et confirme.

L'app n'a pas d'icône dans le Dock : cherche son icône dans la barre des menus, en forme de pilule.

Ouvre l'app seulement si tu fais confiance à sa source : télécharge-la depuis cette page, et lis le code si tu veux vérifier ce qu'elle fait.

**Mise à jour :** remplace l'ancienne app dans Applications. macOS peut te redemander les permissions. Si le HUD ne répond plus alors que Notchlet paraît déjà autorisé, retire-le de la liste Accessibilité avec le bouton −, puis ajoute-le de nouveau.

## Ce que fait l'app

- Une île noire posée sur l'encoche, ou une pilule simulée en haut de l'écran sur les Mac sans encoche.
- **Survol** : après un délai réglable, l'île s'ouvre avec une animation « spring », avec un retour haptique sur les Mac équipés. Elle se referme quand la souris s'éloigne.
- **Live activity** : quand Spotify ou Musique joue, l'île s'élargit et affiche la pochette à gauche et un égaliseur animé à droite. Cet égaliseur est une animation : il ne suit pas réellement le son.
- **Île ouverte avec musique** : pochette, titre, artiste, barre de progression (clique ou fais-la glisser pour avancer ou reculer), temps restant, précédent / lecture-pause / suivant, un bouton au choix (aléatoire, répétition ou copie du lien) et un bouton de sortie audio qui affiche la ligne de volume.
- **Île ouverte sans musique** : l'heure, la date et la batterie.
- **Aperçu rapide** : l'île s'ouvre quelques secondes quand le morceau change.
- **Styles de couleur** : pochette (fond flou), coloré (couleur de la pochette sur l'égaliseur et la progression), dégradé (fond coloré), monochrome (noir et blanc).
- **Gestes au trackpad**, à deux doigts sur l'île : vers le bas pour ouvrir, vers le haut pour fermer, vers la gauche pour le morceau suivant, vers la droite pour le précédent.
- **Alertes de batterie** : quelques secondes dans l'île au branchement du chargeur et quand la batterie passe sous le seuil, avec un son (ceux de macOS). L'alerte s'affiche à la place de la musique, qui revient ensuite. Île ouverte, elle s'affiche sous l'encoche.
- **HUD volume et luminosité** (à activer dans leurs rubriques) : remplace les HUD de macOS par une jauge dans l'île, avec le nom de la sortie audio. Avec Maj, Option, Contrôle ou Commande, les touches restent gérées par macOS.
- **Appareils Bluetooth** (à activer dans la rubrique Appareils) : à la connexion, l'île affiche l'icône de l'appareil avec un petit rebond, son nom et sa batterie. Pour des écouteurs, c'est le niveau le plus faible des deux.
- **Calendrier** (à activer dans la rubrique Calendrier) : les trois prochains événements dans l'île ouverte, un rappel avant chaque événement, et un bouton « Rejoindre » pour Google Meet, Microsoft Teams, Zoom et Webex. Avec de la musique, un bouton à droite de l'encoche passe du lecteur aux événements.
- **Carillon** (à activer dans la rubrique Calendrier) : un son de macOS à chaque heure pile.
- **Météo** (à activer dans la rubrique Météo) : température et conditions locales dans l'île ouverte, quand aucune musique ne joue.
- **Onde sonore** (à activer dans Lecture en cours, macOS 14.2 ou plus récent) : les barres suivent le niveau réel du son pendant la lecture.
- **Modes de concentration** (à activer dans sa rubrique, avec l'Accès complet au disque) : l'île signale le début et la fin d'un mode. Fonction fragile : une concentration programmée peut ne pas être détectée.
- **Appel en cours** (activé par défaut) : quand une app utilise le micro depuis quelques secondes, l'île affiche la durée et un bouton pour couper le micro. L'app ne sait pas s'il s'agit vraiment d'un appel : un mémo vocal ou la dictée l'allument aussi. Le son n'est jamais écouté.
- **Appels entrants** (à activer dans la rubrique Appels, avec l'Accessibilité) : l'île s'ouvre sur le nom de l'appelant, avec les boutons Accepter et Refuser. Fonction fragile : elle lit les bannières de notification, dont le format n'est pas documenté. Rien n'est enregistré.
- **Étagère de fichiers** : glisse un fichier vers l'encoche pour le déposer, double-clique pour l'ouvrir, ou fais-le glisser ailleurs. Elle garde de simples raccourcis jusqu'à la fermeture de l'app : les fichiers ne sont ni copiés, ni déplacés, ni supprimés.
- Une icône dans la barre des menus donne accès aux réglages et permet de quitter l'app.

## Réglages

Ouvre-les depuis l'icône de la barre des menus, avec **Réglages…**.

- **Général** : lancement à l'ouverture de session (macOS peut demander ton accord dans Réglages Système > Général > Ouverture ; active-le depuis la copie de l'app que tu gardes, de préférence dans Applications), activité au repos, ouverture au survol et son délai, retour haptique, masquage en plein écran (pour les apps qui occupent leur propre espace), choix de l'écran, gestes au trackpad, ajustement de la taille de l'encoche.
- **Batterie** : alertes de charge et de batterie faible, seuil de 5 à 50 % (20 % par défaut), son, durée d'affichage, masquage du pourcentage.
- **Appareils** : alerte de connexion Bluetooth et sa durée.
- **Luminosité** et **Volume** : remplacement du HUD de macOS, durée, style de barre (blanc, couleur d'accent, lumineux), pourcentage, vitesse d'animation, et sortie audio pour le volume.
- **Lecture en cours** : style de couleur, bouton à gauche des commandes, aperçu rapide et sa durée.
- **Calendrier** : affichage des événements, rappel avec son délai de 1 à 30 minutes (10 par défaut), sa durée et son son, carillon horaire, choix des calendriers.
- **Concentration**, **Appels**, **Météo** et **Étagère** : activation de chaque fonction.
- **À propos** : version et liens vers le projet.

## Permissions

| Permission | Pourquoi | Où la gérer |
|---|---|---|
| Automatisation | Lire la pochette et la position, et contrôler Spotify ou Musique | Réglages Système > Confidentialité et sécurité > Automatisation |
| Accessibilité | Intercepter les touches de volume et de luminosité pour le HUD, lire les bannières d'appel entrant | Réglages Système > Confidentialité et sécurité > Accessibilité |
| Bluetooth | Détecter la connexion des appareils | Réglages Système > Confidentialité et sécurité > Bluetooth |
| Calendriers | Lire les prochains événements (aucune modification, rien n'est enregistré ni envoyé) | Réglages Système > Confidentialité et sécurité > Calendriers |
| Localisation | Connaître la météo locale | Réglages Système > Confidentialité et sécurité > Service de localisation |
| Capture audio | Mesurer le niveau du son pour l'onde sonore (rien n'est enregistré ni envoyé) | Réglages Système > Confidentialité et sécurité |
| Accès complet au disque | Lire le mode de concentration actif. Cette permission couvre tous tes fichiers, mais Notchlet ne lit que deux fichiers de réglages de macOS | Réglages Système > Confidentialité et sécurité > Accès complet au disque |

L'Automatisation est demandée dès le premier morceau détecté. Sans elle, l'île affiche l'icône de l'app au lieu de la pochette, sans barre de progression, et les boutons restent sans effet.

L'Accessibilité n'est demandée que lorsque tu actives un HUD ou les appels entrants, le Bluetooth lorsque tu actives la rubrique Appareils, et les Calendriers lorsque tu actives leur rubrique. « Rejoindre » n'ouvre que des liens HTTPS vers les quatre services cités. La Localisation et la capture audio ne sont demandées que lorsque tu actives la météo ou l'onde sonore.

**Service tiers :** une fois la météo activée, ta position, arrondie à environ 1 km, est envoyée à [Open-Meteo](https://open-meteo.com) toutes les 30 minutes et à chaque réveil du Mac. La batterie des appareils vient de l'outil système `system_profiler`, sans API privée, mais son format n'est pas documenté. Les gestes et les alertes de batterie ne demandent aucune permission.

**API privée :** le HUD de luminosité utilise DisplayServices, une API non documentée d'Apple (voir `Sources/Notchlet/Private`). Si une mise à jour de macOS la retire, ces touches reviennent à macOS. Pour Spotify, la pochette est téléchargée depuis l'adresse HTTPS fournie par l'app.

## Lancer le projet

Il faut macOS 13 ou plus récent pour lancer l'app, et Xcode 16 ou plus récent pour la compiler.

1. Ouvre `Notchlet.xcodeproj` dans Xcode.
2. Choisis le schéma `Notchlet` > `My Mac`, puis ⌘R.

Pour lancer les tests : ⌘U dans Xcode, ou dans le Terminal :

```bash
xcodebuild test -project Notchlet.xcodeproj -scheme Notchlet -destination 'platform=macOS'
```

Le projet compile sans compte Apple, avec une signature ad hoc, mais macOS peut alors redemander l'Accessibilité après chaque compilation. Pour l'éviter, signe avec ton certificat en suivant les indications de `Config/Signing.xcconfig`.

## Organisation du code

| Dossier | Rôle |
|---|---|
| `Sources/Notchlet/App` | Démarrage, barre des menus, clés de réglages |
| `Sources/Notchlet/Window` | Fenêtre transparente, survol, taille de l'encoche |
| `Sources/Notchlet/Island` | État, forme et interface de l'île |
| `Sources/Notchlet/Activities` | Protocole `Activity` et activités affichées dans l'île |
| `Sources/Notchlet/Managers` | Accès au système : musique, batterie, HUD, sortie audio, Bluetooth, lancement à l'ouverture de session |
| `Sources/Notchlet/Private` | Code qui dépend d'API privées d'Apple |
| `Sources/Notchlet/SettingsUI` | Fenêtre et onglets de réglages |
| `Tests/NotchletTests` | Tests unitaires |

Une activité brève (HUD, alerte) remplace l'activité de fond quelques secondes, puis celle-ci revient.

## Construire le paquet

```bash
./scripts/build-release.sh
```

Le script crée `build/Notchlet-x.y.z.zip` et vérifie l'identifiant, les architectures et la signature ad hoc.

## Licence

Notchlet est distribué sous [licence MIT](LICENSE).
