# Mouvement — v0.4

## Choix de rendu

Swift est le langage. L’interface reste native SwiftUI avec Liquid Glass. Les gestes sont dessinés dans Canvas, puis composés par des shaders Metal compilés avec l’application. Pas de réseau ni de modèle 3D à télécharger.

- Ouverture des recettes : transition zoom native depuis la vignette et révélation diagonale de l’illustration sur 0,7 seconde, jouée une seule fois.
- Portions : ressort commun pour le nombre de personnes et toutes les quantités ; transition numérique et retour haptique de sélection.
- Contrôles : disques de 30 points avec une zone tactile de 44 points ; pression amortie. Bouton principal en verre, plus compact.
- Découpe : préparation, descente de lame, contact, séparation de la pièce et remontée ; six coupes puis pause.
- Four : manipulation du thermostat pour le préchauffage ; plaque glissée dans le four et fermeture de la porte pour l’enfournement.
- Poêle : spatule et retournement du steak ; dessin séparé pour les pains à toaster.
- Assemblage : arrivée successive des couches du burger, puis maintien du résultat.
- Pâtes : vapeur, mélange et rubans soulevés ; tomates : bol distinct pour l’assaisonnement.
- Shader `sketchPaper` : grain fixe très discret dans les aplats, sans scintillement.
- Shader `kitchenHeat` : ondulation inférieure à un point, limitée à la zone d’air chaud du dessin ; aucun texte n’est déformé.
- Le bouton « Revoir le geste » recommence la démonstration sans toucher à l’étape ni aux minuteurs.

La cadence demandée est de 60 images/s, 30 en mode économie d’énergie ; elle reste soumise à la disponibilité du rendu et n’est pas une mesure de performance. Les boucles s’arrêtent en arrière-plan. « Réduire les animations » affiche un dessin fixe et supprime les déplacements. Les boutons gardent une réponse visuelle.

## API Apple

- [Shaders SwiftUI](https://developer.apple.com/documentation/SwiftUI/Shader)
- [Dessin et graphisme](https://developer.apple.com/documentation/swiftui/drawing-and-graphics)

La compilation des fichiers `.metal` nécessite le composant **Metal Toolchain** de Xcode. Il a été installé sur ce Mac avec `xcodebuild -downloadComponent MetalToolchain`.
