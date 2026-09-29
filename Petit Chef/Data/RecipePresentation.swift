import Foundation

extension Recipe {
    var allergens: [String] {
        switch id {
        case "burger-and-oven-fries": ["Gluten", "Lait", "Œuf*", "Moutarde*"]
        case "lemon-pasta": ["Gluten", "Lait", "Œuf*"]
        case "tomato-mozzarella-toast": ["Gluten", "Lait"]
        default: []
        }
    }

    var shortTitle: String {
        switch id {
        case "lemon-pasta": "Pâtes au citron"
        case "tomato-mozzarella-toast": "Tomate & mozzarella"
        default: title
        }
    }

    var category: String {
        switch id {
        case "burger-and-oven-fries": "Le classique maison"
        case "lemon-pasta": "Tout en fraîcheur"
        case "tomato-mozzarella-toast": "Simple & de saison"
        default: "Fait maison"
        }
    }
}

nonisolated enum CookingText {
    static func formatted(_ text: String, unit: String) -> String {
        guard unit == "fahrenheit",
              let expression = try? NSRegularExpression(pattern: #"(\d+)\s*°C"#)
        else { return text }
        var result = text
        let matches = expression.matches(in: text, range: NSRange(text.startIndex..., in: text))
        for match in matches.reversed() {
            guard let numberRange = Range(match.range(at: 1), in: text),
                  let matchRange = Range(match.range, in: result),
                  let celsius = Double(text[numberRange]) else { continue }
            result.replaceSubrange(matchRange, with: "\(Int((celsius * 9 / 5 + 32).rounded())) °F")
        }
        return result
    }
}


nonisolated struct RecipeSource {
    let title: String
    let url: URL
}

extension Recipe {
    var sources: [RecipeSource] {
        switch id {
        case "burger-and-oven-fries":
            [RecipeSource(title: "Frites au four · Papilles & Pupilles", url: URL(string: "https://www.papillesetpupilles.fr/2020/12/comment-faire-des-frites-au-four-maison.html/")!)]
        case "lemon-pasta":
            [RecipeSource(title: "Spaghetti al limone · Le Creuset", url: URL(string: "https://www.lecreuset.com/spaghetti-al-limone/LCR-2732.html")!),
             RecipeSource(title: "Citron et basilic · Jamie Oliver", url: URL(string: "https://www.jamieoliver.com/recipes/pasta/lemon-basil-spaghetti/")!)]
        default:
            [RecipeSource(title: "Bruschetta au four · Galbani", url: URL(string: "https://www.galbani.fr/recettes/bruschetta-et-tartines/bruschetta-a-litalienne")!)]
        }
    }

    var durationNote: String {
        switch id {
        case "burger-and-oven-fries": "Adaptation Petit Chef : environ 15 min de préparation, 30 min au four et assemblage. Les steaks se préparent pendant la seconde cuisson. Prévoir davantage de temps ou plusieurs plaques pour de grandes quantités."
        case "lemon-pasta": "Adaptation Petit Chef : environ 20 min, chauffe de l’eau comprise. La cuisson dépend des pâtes choisies."
        default: "Adaptation Petit Chef : environ 20 min, préchauffage compris. Vérifier la coloration après 8 min au four."
        }
    }
}
