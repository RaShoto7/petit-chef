# Petit Chef

Application iOS de cuisine guidée, en SwiftUI, pour Xcode 27 / iOS 27.

[![iOS](https://github.com/RaShoto7/petit-chef/actions/workflows/ios.yml/badge.svg)](https://github.com/RaShoto7/petit-chef/actions/workflows/ios.yml)

## Récupérer le projet

```sh
git clone https://github.com/RaShoto7/petit-chef.git
cd petit-chef
./scripts/simulator.sh run
```

Prérequis : **Xcode 27**, **iOS 27 Simulator** et **Metal Toolchain**. Le script choisit un iPhone disponible et ne nécessite aucun compte Apple pour le simulateur. [Installation et travail à plusieurs](CONTRIBUTING.md).

<img src="docs/screenshots/v0.4/home.png" alt="Accueil mes recettes" width="260">

## Listes de courses

Deux onglets **Recettes** et **Listes**. Depuis une recette, exporter les ingrédients ajustés vers une nouvelle liste ou une liste existante, en excluant ce qui est déjà à la maison. Les achats sont cochables, sauvegardés localement et partageables ; des articles libres peuvent être ajoutés. [Fonctionnement et choix de données](docs/shopping-lists.md).

## Version 0.4

- **mes recettes.** : grille de deux cartes par ligne, fond blanc, illustrations originales en croquis et touches de pinceau diagonales. Le profil est le seul accès aux réglages.
- **Fiche** : bouton compact « C’est parti », quantités pour 1 à 12 personnes, ingrédients modifiables un par un (nom, quantité, unité, ajout, suppression), annuler/rétablir, matériel et allergènes avec pictogrammes dessinés. Les références restent dans la documentation.
- **Étapes** : texte neutre, gestes animés correspondant à l’action, navigation précédente/suivante et sommaire. Consulter une étape n’effectue aucune action et ne relance aucun minuteur.
- **Liberté de préparation** : une étape peut être effectuée en avance après confirmation de ses prérequis manquants. Le moteur mémorise cette décision. Une cuisson peut être raccourcie, prolongée, réglée directement en heures/minutes/secondes en touchant le chrono, ou terminée explicitement avant l’échéance.
- **Minuteurs système** : AlarmKit, extension WidgetKit de compte à rebours pour la Dynamic Island et l’écran verrouillé. Une seule source de vérité pour les échéances ; pas de compteur décrémenté en mémoire.
- **Compte** : Sign in with Apple facultatif, identité locale dans le trousseau ; réglages °C/°F et retours tactiles.

## Lancer

Installer si nécessaire le composant Metal Toolchain depuis Xcode > Settings > Components (ou `xcodebuild -downloadComponent MetalToolchain`).

Ouvrir `Petit Chef.xcodeproj`, scheme **Petit Chef**, puis **⌘R** sur un iPhone Simulator ou un iPhone signé.

```sh
xcodebuild -project 'Petit Chef.xcodeproj' -scheme 'Petit Chef' \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -derivedDataPath /tmp/PetitChefDerivedData CODE_SIGN_IDENTITY=- build
```

Sur appareil, choisir une équipe Apple Developer et un profil autorisant Sign in with Apple. L’extension `CookingWidgets` doit être signée par la même équipe. L’autorisation AlarmKit est demandée au premier minuteur ou dans les réglages. L’app ne peut pas créer une entrée dans l’application Horloge : elle utilise l’API système officielle destinée aux minuteurs tiers.

Si la signature signale « resource fork / Finder information », placer DerivedData hors du dossier Documents synchronisé, comme dans la commande ci-dessus. Le dossier de compilation par défaut de Xcode convient également.

## Architecture

- `Domain/Recipe.swift` : recettes et étapes `Codable` ; `RecipeLibrary.swift` : personnalisations persistées et mise à l’échelle numérique.
- `Data/` : trois recettes adaptées et documentées, sans scraping automatique ni reproduction des photos ou textes sources.
- `Cooking/CookingEngine.swift` : transitions déterministes, dépendances et choix explicites d’ordre. Aucune décision de planning confiée à une IA.
- `Cooking/CookingStore.swift` : session et copie des ingrédients choisis au démarrage, persistance et synchronisation sérialisée des rappels.
- `Cooking/CookingAlarms.swift` : autorisation et programmation AlarmKit, inventaire local des alarmes appartenant aux sessions de l’app. Une alarme arrêtée dans l’interface système n’est pas recréée sans modification explicite de sa durée et ne marque pas automatiquement un aliment comme cuit.
- `Shared/` : métadonnées AlarmKit et App Intent communs à l’app et à l’extension.
- `CookingWidgets/` : présentation du compte à rebours en activité en direct, Dynamic Island compacte, étendue et minimale.
- `Illustrations/` : illustrations du catalogue et gestes Canvas chorégraphiés (60 images/s demandées, 30 en économie d’énergie), bouton de relecture et Réduire les animations respecté. `Shaders/` : révélation au pinceau, grain fixe et chaleur en Metal.
- `Features/` : accueil, fiche, éditeur d’ingrédients, cuisine et paramètres.
- `Shopping/` : listes persistantes, sélection des ingrédients, suivi des achats et partage texte.

Les préférences d’ingrédients ne modifient pas une session déjà commencée. Elles ne réécrivent pas non plus les instructions culinaires. Les durées et températures ne sont pas multipliées avec les portions. Les allergènes restent une information de référence à vérifier après toute substitution.

## Vérification

24 tests unitaires et 4 parcours UI (personnalisation/navigation/reprise, ajout/suppression, contrôle des illustrations rendues et listes de courses) passent sur iPhone 18 Pro Simulator, iOS 27. Les tests UI ordinaires utilisent un stockage séparé et des notifications locales désactivées. Le test `testSystemTimerAuthorizationAndBackground` exerce séparément AlarmKit réel, avec son autorisation système, puis annule le minuteur. Ce contrôle a été ignoré explicitement sur ce simulateur : AlarmKit refuse l’autorisation, y compris après compilation signée localement. L’affichage réel de la Dynamic Island n’est donc pas encore validé.

```sh
xcodebuild -project 'Petit Chef.xcodeproj' -scheme 'Petit Chef' \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -derivedDataPath /tmp/PetitChefDerivedData -parallel-testing-enabled NO \
  CODE_SIGN_IDENTITY=- test
```

Captures : [accueil](docs/screenshots/v0.4/home.png), [fiche](docs/screenshots/v0.4/recipe.png), [édition](docs/screenshots/v0.4/ingredients.png), [découpe](docs/screenshots/v0.4/cutting.png), [minuteur](docs/screenshots/v0.4/timer-editor.png), [allergènes](docs/screenshots/v0.4/allergens.png).

## Références et limites

- [Choix de mouvement et rendu natif](docs/design/motion-v04.md).

- [Références culinaires et choix de durée](docs/recipe-references.md). Ces adaptations restent à tester en cuisine.
- [Illustrations générées, chemins et prompts](docs/design/illustrations-v04.md). Les images sont livrées dans le catalogue d’assets, disponibles hors ligne.
- [Apple : AlarmKit et son activité en direct](https://developer.apple.com/videos/play/wwdc2025/230/).
- [Apple : programmer une alarme](https://developer.apple.com/documentation/alarmkit/scheduling-an-alarm-with-alarmkit).
- [Apple : Liquid Glass](https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views).

La connexion Apple et le comportement complet des alarmes sur appareil verrouillé restent à valider sur un iPhone signé. Voix, IA locale MLX et animations 3D ne sont pas intégrées. Le tag `v1.0` sera créé lorsque la Phase 1 sera validée ; la version actuelle reste une version de développement.
