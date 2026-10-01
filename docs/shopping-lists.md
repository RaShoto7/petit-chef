# Listes de courses

La barre de navigation propose **Recettes** et **Listes**. Depuis une fiche recette, **Ajouter à une liste** ouvre la sélection des ingrédients. Les portions et modifications personnelles sont déjà appliquées ; décocher les produits présents à la maison, puis choisir une nouvelle liste ou une liste existante.

Une liste permet de cocher et décocher les achats, d’ajouter un article libre avec une quantité, de supprimer un article par balayage, de renommer la liste et de la partager via la feuille de partage iOS. Le menu propose la suppression de la liste avec confirmation.

Les listes sont conservées localement dans `UserDefaults`, avec un schéma Codable versionné (`petitchef.shopping.lists.v1`). Chaque export est un instantané : modifier ensuite une recette ne modifie pas les courses déjà prévues. Les apports de plusieurs recettes restent séparés et leur provenance est conservée dans les données et le partage ; aucune somme implicite entre unités ou préparations différentes. Ajouter une recette une seconde fois ajoute un nouveau lot d’achats, même si le précédent a déjà été coché.

Le partage est du texte avec les quantités, les recettes d’origine et l’état des cases. Pas de synchronisation iCloud ni de collaboration en temps réel dans cette version.

## Interface et mouvement

L’accueil affiche uniquement le titre « Listes », les noms des listes et l’accès à la création. Aucun compteur, aperçu d’ingrédients, anneau, illustration ni carte décorative.

Le détail présente le titre et les ingrédients sur un fond blanc : cases circulaires, quantités alignées à droite, séparateurs fins. Les achats cochés rejoignent « Dans le panier ». L’ajout d’article reste accessible en bas ; partage et options utilisent les contrôles natifs. La provenance d’un article n’est affichée que si plusieurs recettes alimentent la liste.

La navigation utilise la transition native standard. L’apparition est un fondu de 250 ms avec un déplacement de 4 points. Au cochage, les données sont sauvegardées immédiatement ; la coche se dessine, puis la ligne rejoint sa section après 220 ms, avec une transition de 250 ms. Réduire les animations supprime ces effets et le délai de déplacement. Les retours tactiles suivent le réglage de l’app.

## Vérification

- Tests de domaine : portions, sélection, instantané, persistance, cochage, renommage, suppression et partage.
- Deux parcours UI : export/exclusion/cochage/reprise/partage ; création/article libre/cochage/sortie/réouverture/décochage.
- Captures contrôlées pour l’accueil, le détail, l’état vide et une liste terminée.
