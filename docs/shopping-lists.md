# Listes de courses

La barre de navigation propose **Recettes** et **Listes**. Depuis une fiche recette, **Ajouter à une liste** ouvre la sélection des ingrédients. Les portions et modifications personnelles sont déjà appliquées ; décocher les produits présents à la maison, puis choisir une nouvelle liste ou une liste existante.

Une liste permet de cocher et décocher les achats, d’ajouter un article libre avec une quantité, de supprimer un article par balayage, de renommer la liste et de la partager via la feuille de partage iOS. Le menu propose la suppression de la liste avec confirmation.

Les listes sont conservées localement dans `UserDefaults`, avec un schéma Codable versionné (`petitchef.shopping.lists.v1`). Chaque export est un instantané : modifier ensuite une recette ne modifie pas les courses déjà prévues. Les apports de plusieurs recettes restent séparés et leur provenance reste visible ; aucune somme implicite entre unités ou préparations différentes. Ajouter une recette une seconde fois ajoute un nouveau lot d’achats, même si le précédent a déjà été coché.

Le partage est du texte avec les quantités, les recettes d’origine et l’état des cases. Pas de synchronisation iCloud ni de collaboration en temps réel dans cette version.

## Vérification

- Tests de domaine : portions ajustées, sélection, instantané indépendant de la recette, sauvegarde, cases cochées, renommage, suppression, export texte, lots séparés.
- Test UI : onglets, état vide, export avec exclusion, case cochée, fermeture et relance, restauration, ouverture du partage.
- L’anneau de progression et le déplacement des achats cochés s’animent doucement ; ces animations et le style tactile des cartes respectent Réduire les animations. Le cochage respecte le réglage des retours tactiles.

## Direction visuelle

Fond blanc cassé, cartes blanches à bord fin et léger décalage de papier, typographie système sans arrondi, grands chiffres légers et anneau de progression. Dans le détail, les quantités ont leur propre surface et la recette d’origine n’est affichée qu’une fois lorsqu’elle est commune à tous les articles. Le bouton d’ajout reste accessible en bas de l’écran.
