# Police et nouvelle piste d’animation — 1 octobre 2026

## Choix de police

**Fraunces Italic**, par Undercase Type. Elle apporte des formes plus souples et expressives que la police système, tout en restant lisible. L’app embarque une instance fixe (`wght=550`, `opsz=72`, `SOFT=45`, `WONK=1`), nommée `Fraunces Petit Chef` pour identifier cette déclinaison. Taille de base 42 points, adaptée à Dynamic Type. Le titre conserve ses minuscules et son point. `fontDesign(nil)` neutralise le dessin arrondi hérité du reste de l’écran, qui remplacerait sinon la police personnalisée.

La licence SIL OFL et son attribution sont incluses dans le bundle. Source : [site des auteurs](https://fraunces.undercase.xyz/), [distribution Google Fonts](https://github.com/google/fonts/tree/main/ofl/fraunces). Le fichier source peut être instancié avec `fontTools.varLib.instancer` ; aucun accès réseau n’est nécessaire dans l’application.

## Recherche de solutions

| Solution | Ce qu’elle apporte | Conséquence pour Petit Chef |
| --- | --- | --- |
| [Rive Apple runtime](https://github.com/rive-app/rive-ios) | Dessins vectoriels, animation interactive et machines à états, intégration SwiftUI | Bon candidat pour des gestes 2D dessinés et riggés. Il faut créer les dessins et les animations dans l’éditeur ; importer le runtime seul ne transforme pas nos scènes. |
| [Lottie iOS](https://github.com/airbnb/lottie-ios) | Lecture d’animations dessinées et exportées, moteur Core Animation | Adapté aux petites animations d’interface. Les scènes détaillées exigent toujours des assets préparés. |
| [RealityKit](https://developer.apple.com/documentation/realitykit) | Rendu et animation de modèles 3D en temps réel | Intéressant si l’utilisateur doit manipuler les objets. Modèles, textures et rendu dessiné restent à produire ; nos anciennes primitives étaient insuffisantes. |
| [Blender et Grease Pencil](https://docs.blender.org/manual/en/latest/grease_pencil/) | Modélisation, animation, contours dessinés et rendu préparé | La piste retenue pour les séquences de recette : elle permet de vérifier chaque pose et chaque contact avant livraison. |
| [AVFoundation / HEVC avec alpha](https://developer.apple.com/videos/play/wwdc2019/506/) | Lecture native d’une vidéo sur un fond transparent | Transporte le rendu Blender dans SwiftUI. Lecture locale, sans contrôles vidéo ni calcul de planning. |

La recherche de plugins Codex a renvoyé notamment Runway et Higgsfield, des services de création de médias. Aucun n’a été installé. Pour ce pilote, Blender est déjà installé et accessible directement. La recherche du catalogue n’est pas exhaustive ; un plugin de génération de vidéo ne dispense pas de vérifier la fidélité des gestes culinaires.

**Décision : Blender pour l’animation et le rendu, AVFoundation pour la lecture iOS.** Le compromis est explicite : ce sont de vrais objets 3D lors de la création, puis une séquence vidéo à caméra fixe dans l’app. On ne peut pas tourner autour du plat en touchant l’écran. La qualité dépend du travail sur les objets et les poses ; ce pilote valide le chemin technique, pas la direction artistique définitive des six scènes.

## Pilote concret : dressage des tartines

La scène `toast-pilot.blend` comprend une assiette tournée, deux pains avec croûte et mie, des tranches de mozzarella, des dés de tomate et des feuilles de basilic courbées avec nervures. Les modèles sont créés dans le script, sans téléchargement de modèles externes. Le rendu Eevee utilise des matériaux à teintes étagées et des courbes de contour et de hachure ; ce premier pilote n’utilise pas encore de traits Grease Pencil peints à la main.

Les ingrédients arrivent successivement et se posent sur leurs surfaces. Les poignées Bézier sont bornées pour éviter qu’un objet traverse le pain. La vidéo contient 144 images à 24 images/s, soit 6 secondes, avec transparence HEVC. Elle pèse environ 610 Ko. L’étape **Servir les tartines** utilise ce pilote ; les cinq autres étapes conservent les croquis actuels pour permettre la comparaison.

La lecture attend la fin de l’arrivée de la carte, s’interrompt quand l’app est inactive et garde la dernière image à la fin. Réduire les animations affiche directement la pose finale. Le minuteur et le moteur de recette ne lisent jamais la position de la vidéo.

## Reproduire

Blender 5.2 est nécessaire pour recréer les images. Xcode et Swift servent à l’encodage HEVC avec alpha.

```sh
blender -b --python scripts/animation/toast_pilot.py -- /tmp/PetitChef-blender-pilot
swift scripts/animation/encode_alpha.swift /tmp/PetitChef-blender-pilot \
  'Petit Chef/Resources/Animations/toast-plating.mov' 24
```

Les PNG intermédiaires restent hors du dépôt. L’app embarque la vidéo, une image initiale et une pose finale ; aucun Blender ni service distant n’est requis sur le Mac du collaborateur pour compiler ou tester.

## Vérification

Les tests des ressources vérifient que la police se charge, que le film est lisible, dure 6 secondes et contient un canal alpha. Le parcours UI des tartines vérifie la navigation complète et capture le dressage intégré. La fluidité, le décodage et la consommation sur iPhone physique restent à mesurer. Les poses culinaires restent des illustrations à confronter aux gestes réels.
