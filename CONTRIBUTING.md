# Travailler sur Petit Chef

## Première installation

Un Mac compatible avec Xcode 27, Xcode 27 (testé avec 27.0 / 27A266a), un simulateur iPhone iOS 27 et le composant Metal Toolchain sont nécessaires. Installer les composants dans Xcode > Settings > Components. Aucun service distant, clé API ou compte Apple payant n’est nécessaire pour le parcours simulateur.

```sh
git clone https://github.com/RaShoto7/petit-chef.git
cd petit-chef
./scripts/simulator.sh run
```

Le script compile, installe et ouvre l’app sur un simulateur iPhone disponible. En cas de composant manquant, il affiche la marche à suivre. On peut aussi ouvrir `Petit Chef.xcodeproj`, choisir le scheme partagé **Petit Chef** et un iPhone Simulator, puis ⌘R.

Si la mauvaise version de Xcode est sélectionnée, choisir Xcode 27 dans **Settings > Locations > Command Line Tools**. Pour Metal : `xcodebuild -downloadComponent MetalToolchain`.

## Une branche par changement

Après invitation comme collaborateur :

```sh
git switch main
git pull --ff-only
git switch -c codex/amelioration-recettes
# Modifier et vérifier dans Xcode ou Codex.
./scripts/simulator.sh test
git add <les-fichiers-modifies>
git commit -m "Améliore la présentation des recettes"
git push -u origin codex/amelioration-recettes
```

Sur GitHub, ouvrir une pull request vers `main`. Décrire le changement et joindre une capture pour l’interface. Relire les modifications et les tests avant de fusionner. Mettre ensuite sa copie locale à jour avec `git pull --ff-only` depuis `main`. Si `main` comporte des changements locaux, les enregistrer sur sa branche avant de changer de branche.

Le dépôt étant public, la lecture et le clonage sont possibles avant l’invitation. Pour publier des modifications sans accès collaborateur, passer par un fork puis une pull request.

## Tests

`./scripts/simulator.sh test` compile l’app, son extension et lance les tests unitaires et UI. Le test d’autorisation AlarmKit réelle est exclu de cette commande et de la CI : il dépend des permissions système et doit être lancé séparément depuis Xcode sur un environnement compatible. L’interface des alarmes sur iPhone verrouillé et Sign in with Apple restent à valider sur appareil signé.

Le workflow GitHub Actions **iOS** applique cette même commande aux pull requests et à `main`, sur l’image officielle `xcode-27`. Ses résultats `.xcresult` sont conservés pendant sept jours.

Options facultatives : `SIMULATOR_ID` pour choisir un simulateur, `PETITCHEF_DERIVED_DATA` pour le dossier de compilation et `PETITCHEF_TEST_RESULTS` pour un nouveau chemin `.xcresult`.

## Règles du projet

- SwiftUI pour l’interface, RealityKit pour les gestes 3D des tartines, Canvas et Metal pour les autres illustrations ; respecter Réduire les animations.
- Durées, dépendances et parallélisation restent dans le moteur déterministe. Ne pas les confier à un modèle de langage.
- Ajouter une recette dans le catalogue structuré et documenter ses références ; pas de scraping automatique.
- Ne pas publier de certificats, secrets ou préférences personnelles Xcode. Ne pas modifier l’équipe de signature partagée pour un test simulateur : le script utilise une signature locale indépendante.
- Ne pas modifier silencieusement les recettes ou ingrédients d’une session déjà commencée.
- Petites modifications relisibles, et captures lorsque l’interface change.

## Tester sur son iPhone

Le projet contient les identifiants d’app de Rafaël. Pour utiliser sa propre équipe, adapter localement l’équipe et les identifiants de **l’app et de CookingWidgets**, avec des profils prenant en charge les capacités utilisées. Ne pas envoyer ces changements personnels dans une pull request. Le script simulateur ne requiert pas cette configuration.
