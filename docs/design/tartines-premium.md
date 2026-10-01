# Tartines : direction visuelle et mouvement

Les tartines servent de recette pilote. Le titre « mes recettes. » utilise Fraunces Italic, embarquée sous licence SIL OFL, avec des formes arrondies et un espacement resserré. Les titres de recette et d’étape conservent leur serif italique. Les cartes d’ingrédients, de matériel et d’instructions utilisent Liquid Glass `clear`, avec un fond opaque quand Réduire la transparence est activé. Un contour continu de 0,75 point complète les reflets du verre : la bulle reste fermée sur un fond blanc.

Les sections Étapes et Matériel conservent leur contenu et leur surface pendant le dépliage. L’animation change leur hauteur visible et leur opacité, sans une seconde animation de pression sur toute la surface.

## Navigation

La grande flèche centrale valide et avance. La flèche précédente reste à gauche et disparaît à la première étape. Un appui prolongé sur la flèche centrale permet de consulter la suite sans valider ; le sommaire reste accessible par le menu supérieur.

Une transition prend environ 1,15 seconde : départ vers le haut (0,42 s), changement du contenu invisible et respiration (0,08 s), arrivée depuis le bas (0,65 s). La navigation arrière inverse le déplacement. Les boutons sont bloqués jusqu’à la fin réelle de l’animation, et le dessin commence après l’arrivée. Le défilement ne lance aucune animation concurrente.

L’entrée en cuisine utilise la transition native `crossFade` d’iOS 27, suivie d’une arrivée verticale de la première carte.

Le minuteur reste ancré en bas, au-dessus de la navigation, dans une carte Liquid Glass transparente avec des chiffres de 27 points. La croix du minuteur l’arrête immédiatement. Toucher le chrono permet toujours de régler sa durée. Le bouton final **Terminer**, agrandi et sans icône, revient à la grille ; les commandes de navigation disparaissent à la fin.

## Croquis animés

`ToastSketchAnimation` dessine les scènes de préparation avec SwiftUI Canvas : four, découpe, garniture, cuisson, mélange et dressage. Contours légèrement doublés, hachures fixes, couleurs en lavis, mie et nervures donnent un rendu de carnet culinaire. Le shader Metal ajoute un grain stable. Aucun modèle ni asset distant n’est nécessaire.

Les mouvements sont décomposés : levée du couteau, coupe et dégagement ; frottement de l’ail, filet d’huile, pose du fromage ; insertion du plateau puis fermeture du four ; rotation des ingrédients dans le saladier ; dépôt des tomates et du basilic. La découpe conserve les graines et la peau dans chaque morceau : les fragments se séparent après le contact de la lame. Le couteau bascule autour de sa pointe, la porte du four est projetée autour de sa charnière et les ombres restent sur la surface pendant la descente des ingrédients. Le mélange ralentit progressivement et déplace davantage les morceaux proches de la cuillère.

Chaque séquence conserve sa pose finale avant un fondu de boucle. Les gestes illustrent l’action sans piloter le moteur de cuisson ni les minuteurs.

Les mises à jour visent 60 images/s, ou 30 en économie d’énergie, et sont suspendues pendant les transitions et lorsque l’app est inactive. Réduire les animations affiche une pose fixe et supprime les déplacements de l’interface. La qualité de fluidité, la consommation et la chauffe sur iPhone physique restent à mesurer.

## Vérification

Les cinq premières étapes restent des croquis 2D avec perspective et relief. Le dressage utilise désormais un pilote préparé en 3D dans Blender, puis lu localement en vidéo transparente. [Recherche, compromis et sources](animation-pilot/README.md). Le choix conserve la direction dessinée demandée et le contrôle des contours. Sources Apple consultées : [Canvas](https://developer.apple.com/documentation/swiftui/canvas), [Liquid Glass](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views), [transition CrossFade](https://developer.apple.com/documentation/swiftui/crossfadenavigationtransition).

Le parcours UI des tartines ouvre et ferme chaque section trois fois, traverse les six étapes, revient en arrière, arrête le minuteur en un tap et vérifie le retour à l’accueil. Le parcours burger vérifie aussi la consultation d’une étape sans validation, le réglage manuel du chrono et la reprise après relancement.

<img src="../screenshots/tartines-premium/home.png" alt="Accueil" width="240"> <img src="../screenshots/tartines-premium/recipe.png" alt="Tartines" width="240"> <img src="../screenshots/tartines-premium/preparation.png" alt="Croquis de découpe" width="240">

Les alarmes système réelles et la Dynamic Island nécessitent toujours une vérification sur un iPhone signé ; les tests UI ordinaires isolent leurs données et ne programment pas d’alarmes système.
