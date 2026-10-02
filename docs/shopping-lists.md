# Listes de courses

La barre de navigation propose **Recettes** et **Listes**. Depuis une fiche recette, **Ajouter à une liste** ouvre la sélection des ingrédients. Les modifications personnelles sont déjà appliquées. Choisir de 1 à 12 personnes dans la feuille d’export recalcule les quantités pour les courses sans modifier la recette enregistrée ; décocher les produits présents à la maison, puis choisir une nouvelle liste ou une liste existante. Depuis une liste, le menu « Ajouter une recette » préselectionne cette destination.

Une liste permet de cocher et décocher les achats, d’ajouter un article libre avec une quantité, de modifier un article par appui long, de supprimer un article par balayage, de renommer la liste et de la partager via la feuille de partage iOS. Le menu propose la suppression de la liste avec confirmation.

Les listes sont conservées localement dans `UserDefaults`, avec un schéma Codable versionné (`petitchef.shopping.lists.v1`). Chaque export est un instantané : modifier ensuite une recette ne modifie pas les courses déjà prévues. Les ingrédients identiques non cochés sont regroupés quand leurs unités correspondent et que leurs quantités sont toutes numériques ou toutes non chiffrées. Quelques équivalences explicites sont reconnues, notamment Tomate/Tomates ; des noms de préparations différents restent séparés. Aucune conversion automatique entre g et kg, aucune interprétation des quantités libres. Chaque apport conserve son export de recette, ses portions et sa quantité d’origine. Les articles déjà achetés ne sont jamais réutilisés pour un nouvel export. Les anciennes listes restent lisibles ; leurs quantités en texte ne sont pas fusionnées.

Le classement par rayon utilise des règles locales sur les noms : fruits et légumes, boulangerie, viande et poisson, produits frais, épicerie, surgelés et autres. Un appui long sur un article ouvre « Changer de rayon » ; la correction est sauvegardée. Le menu « Ordre des rayons » ouvre une feuille de réorganisation par glisser-déposer. L’ordre est sauvegardé pour toutes les listes et pour leur partage (`petitchef.shopping.aisle-order.v1`). Aucun modèle IA ni appel réseau.

Toucher une capsule de recette filtre les articles associés à cet export ; la capsule sélectionnée devient sombre et un second tap revient à la liste complète. Les articles partagés gardent leurs quantités totales et leur cochage concerne toute la liste, même sous filtre. Le filtre n’est pas sauvegardé entre les ouvertures de l’app. Un appui long sur une capsule ouvre « Voir les quantités » : les références restent un instantané de l’export.

Modifier un nom, une quantité ou un rayon concerne uniquement les courses. Les noms et quantités d’origine restent conservés dans les références. Une quantité modifiée est traitée comme du texte libre ; l’article n’est plus fusionné automatiquement lors d’un nouvel export. Une correction du rayon seul conserve le regroupement.

Après un cochage, une suppression, une modification ou un changement de rayon, une capsule d’annulation remplace le bouton d’ajout pendant 4,5 secondes. L’annulation reste disponible dans le menu après la disparition de la capsule. Elle restaure le dernier article concerné, avec sa position, sa quantité, ses références et son état, sans remplacer la liste entière. Un seul niveau d’annulation par liste, conservé pendant la session de l’app ; un nouvel ajout invalide l’ancien geste pour éviter de perdre ses apports.

« Enregistrer comme modèle », dans le menu de la liste, conserve un instantané indépendant de tous les articles. Le bouton marque-page de l’accueil ouvre les modèles. Un tap crée une nouvelle liste avec de nouveaux identifiants et toutes les cases décochées, en conservant les quantités, rayons et références. Supprimer la liste d’origine ne supprime pas son modèle ; supprimer un modèle ne supprime pas les listes créées avec lui. Le menu « Dupliquer » produit également une copie décochée. Les modèles utilisent la clé locale `petitchef.shopping.templates.v1`.

Le partage est du texte avec les quantités, les recettes d’origine et l’état des cases. Pas de synchronisation iCloud ni de collaboration en temps réel dans cette version.

## Interface et mouvement

L’accueil affiche le titre « Listes » et une bulle blanche arrondie par liste, sur un fond gris très clair. Les bulles ont une hauteur minimale de 92 points, un rayon de 30 points et un espacement de 16 points. Le nom en taille titre 3 et une ombre très douce leur donnent une présence discrète ; chaque bulle contient uniquement le nom et un chevron. Aucun compteur ni aperçu d’ingrédients. Le bouton de création reste dans la barre supérieure.

Le détail regroupe les ingrédients par rayon dans des panneaux blancs arrondis : cases circulaires, quantités alignées à droite et séparateurs fins. Les achats cochés rejoignent un panneau « Dans le panier ». L’ajout d’article reste accessible dans une capsule de verre en bas ; partage et options utilisent les contrôles natifs. Les capsules de recettes sous le titre servent de filtres ; leurs menus contextuels donnent accès aux quantités prévues. Dans une liste alimentée par plusieurs recettes, la provenance figure aussi sous chaque ingrédient. Les anciennes références en texte restent affichées.

Les bulles se compriment légèrement au toucher (échelle 0,98, ressort de 300 ms). La navigation utilise la transition native standard. L’apparition est un fondu de 250 ms avec un déplacement de 4 points. Au cochage, les données sont sauvegardées immédiatement ; la coche se dessine, puis la ligne rejoint sa section après 220 ms, avec une transition de 250 ms. Réduire les animations supprime les mouvements de pression et d’apparition et le délai de déplacement. Les retours tactiles suivent le réglage de l’app.

## Vérification

- Quatorze tests de domaine : annulation des achats et suppressions, modifications et références historiques, filtres sur les ingrédients partagés, ordre des rayons, portions personnalisées, sélection, instantané, migration des anciennes listes, regroupement et références, unités incompatibles, rayons corrigés, modèles indépendants, persistance et opérations existantes.
- Trois parcours UI existants validés : recettes multiples/portions/rayons/références/modèles/reprise ; export/exclusion/cochage/reprise/partage ; création/article libre/cochage/sortie/réouverture/décochage.
- Quatrième parcours validé sur un simulateur isolé avant publication : modification d’un article, annulation après expiration de la capsule, annulation du cochage et d’une suppression, filtre de recette, réorganisation par glisser-déposer et persistance de l’ordre après relancement.
- Captures contrôlées pour l’accueil, le détail, l’état vide et une liste terminée.
