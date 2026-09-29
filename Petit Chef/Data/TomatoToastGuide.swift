import Foundation

/// Editorial gestures only: selecting or replaying one never advances the cooking engine.
nonisolated enum TomatoToastGesture: String, Sendable {
    case preheat, bread, dice, mozzarella, garlic, rub, oil, layer, bake, check, season, mix, top, finish
}

nonisolated struct TomatoToastAction: Identifiable, Sendable {
    let gesture: TomatoToastGesture
    let label: String
    let title: String
    let detail: String
    let landmark: String
    var id: String { gesture.rawValue }
}

nonisolated struct TomatoToastGuide: Sendable {
    let actions: [TomatoToastAction]
    let checkpoint: String

    var instruction: String {
        actions.map { $0.title + ". " + $0.detail }.joined(separator: "\n\n") + "\n\nRepère : " + checkpoint
    }

    static func forStep(_ id: String) -> TomatoToastGuide? {
        switch id {
        case "preheat-toast":
            return Self(actions: [
                .init(gesture: .preheat, label: "Le four", title: "Régler le four à 180 °C",
                      detail: "Choisir la chaleur tournante et placer la grille à mi-hauteur. Laisser le four chauffer pendant la préparation ; attendre son signal de préchauffage avant d’enfourner.", landmark: "180 °C · chaleur tournante"),
                .init(gesture: .bread, label: "Le pain", title: "Préparer des tranches régulières",
                      detail: "Couper le pain sur environ 1,5 cm d’épaisseur. Poser les tranches à plat sur une plaque recouverte de papier cuisson, avec un peu d’espace entre elles.", landmark: "Pain · 1,5 cm d’épaisseur")
            ], checkpoint: "Le pain forme une seule couche sur la plaque. Les tomates seront ajoutées après la cuisson.")
        case "slice-tomatoes":
            return Self(actions: [
                .init(gesture: .dice, label: "Tomates", title: "Couper les tomates en dés de 1 cm",
                      detail: "Laver et sécher les tomates. Retirer le pédoncule, couper en deux et poser la face plate sur la planche. Faire des tranches, puis des bandes et enfin des dés, les doigts repliés derrière la lame. Laisser le jus libre sur la planche et réserver les dés dans un bol.", landmark: "Dés de tomate · environ 1 cm"),
                .init(gesture: .mozzarella, label: "Mozza", title: "Égoutter, éponger puis trancher",
                      detail: "Vider le liquide de la mozzarella. La tamponner avec du papier absorbant, puis la couper en tranches d’environ 5 mm. Éponger aussi les tranches si elles rendent encore de l’eau, sans les écraser.", landmark: "Mozzarella · tranches de 5 mm"),
                .init(gesture: .garlic, label: "Ail", title: "Préparer une face d’ail fraîche",
                      detail: "Éplucher la gousse et la couper en deux dans la longueur. Garder les deux moitiés : leur face coupée servira à parfumer le pain.", landmark: "Une gousse · coupée en deux")
            ], checkpoint: "Les dés sont réguliers et la mozzarella ne baigne plus dans son jus : c’est ce qui évite un pain détrempé.")
        case "build-toast":
            return Self(actions: [
                .init(gesture: .rub, label: "Frotter", title: "Parfumer le pain avec l’ail",
                      detail: "Passer doucement la face coupée de l’ail sur chaque tranche de pain, deux ou trois fois. Insister un peu plus pour un goût d’ail plus présent.", landmark: "Ail · face coupée contre le pain"),
                .init(gesture: .oil, label: "Huiler", title: "Répartir la moitié de l’huile",
                      detail: "Verser la moitié de l’huile prévue dans les ingrédients en un fin filet sur l’ensemble des tartines. L’étaler avec le dos d’une cuillère. Garder l’autre moitié pour les tomates.", landmark: "La moitié de l’huile · sur le pain"),
                .init(gesture: .layer, label: "Garnir", title: "Poser la mozzarella en une couche",
                      detail: "Répartir toutes les tranches de mozzarella sur le pain, sans les empiler. Laisser un petit bord de pain visible pour qu’il puisse dorer. Garder les tomates et le basilic à côté.", landmark: "Mozzarella seule · avant le four")
            ], checkpoint: "Chaque tartine porte une fine couche de mozzarella. Pas encore de tomates ni de basilic.")
        case "bake-toast":
            return Self(actions: [
                .init(gesture: .bake, label: "Enfourner", title: "Enfourner puis lancer les 8 minutes",
                      detail: "Quand le four a atteint 180 °C, glisser la plaque à mi-hauteur avec des maniques. Fermer la porte, puis toucher « Lancer · 8 min ». Pendant la cuisson, passer à l’assaisonnement des tomates.", landmark: "Mi-hauteur · 180 °C · 8 min"),
                .init(gesture: .check, label: "Vérifier", title: "Observer le fromage et les bords",
                      detail: "À la sonnerie, vérifier que la mozzarella est fondue et que les bords du pain sont légèrement dorés. Si nécessaire, ajouter 1 minute au minuteur et vérifier à nouveau. La durée est un repère : ne pas attendre que le fromage se dessèche.", landmark: "Fromage fondu · bords dorés")
            ], checkpoint: "Le minuteur démarre uniquement avec le bouton de cuisson. Revoir une animation ne le lance pas.")
        case "dress-tomatoes":
            return Self(actions: [
                .init(gesture: .season, label: "Assaisonner", title: "Ajouter l’huile et le basilic",
                      detail: "Laver et sécher le basilic. Déchirer la moitié des feuilles à la main au-dessus des tomates. Ajouter le reste d’huile, une petite pincée de sel et du poivre. Réserver les autres feuilles pour le service.", landmark: "Reste d’huile · moitié du basilic"),
                .init(gesture: .mix, label: "Mélanger", title: "Mélanger doucement puis goûter",
                      detail: "Soulever les dés avec une cuillère, du fond vers le dessus, sans les écraser. Goûter et ajuster le sel et le poivre petit à petit. Si du jus s’accumule, le laisser au fond du bol au moment de garnir.", landmark: "Des dés enrobés · sans les écraser")
            ], checkpoint: "Les tomates restent en morceaux et le basilic reste frais. Cette préparation se fait pendant les 8 minutes au four.")
        case "serve-toast":
            return Self(actions: [
                .init(gesture: .top, label: "Tomates", title: "Garnir les tartines à la sortie du four",
                      detail: "Sortir la plaque avec des maniques et la poser sur un support résistant à la chaleur. Prélever les tomates à la cuillère, laisser le jus s’égoutter au-dessus du bol et les répartir sur la mozzarella chaude.", landmark: "Tomates fraîches · après le four"),
                .init(gesture: .finish, label: "Basilic", title: "Ajouter le basilic et servir aussitôt",
                      detail: "Déchirer les feuilles de basilic restantes et les poser sur les tartines. Transférer dans les assiettes avec une spatule. Servir tout de suite pour garder le contraste entre pain croustillant, fromage fondant et tomates fraîches.", landmark: "Croustillant · fondant · frais")
            ], checkpoint: "Garnir juste avant de manger : les tomates restent fraîches et le pain garde son croustillant.")
        default: return nil
        }
    }
}
