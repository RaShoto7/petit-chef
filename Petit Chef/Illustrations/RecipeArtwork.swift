import SwiftUI

struct RecipeArtwork: View {
    let recipeID: String
    @State private var reveal = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var asset: String {
        switch recipeID {
        case "lemon-pasta": "PastaSketch"
        case "tomato-mozzarella-toast": "ToastSketch"
        default: "BurgerSketch"
        }
    }
    var body: some View {
        let staticImage = reduceMotion
        Image(asset)
            .resizable()
            .scaledToFit()
            .keyframeAnimator(initialValue: 1.0, trigger: reveal) { content, progress in
                content.visualEffect { view, proxy in
                    view.colorEffect(ShaderLibrary.brushReveal(.float2(proxy.size), .float(staticImage ? 1 : progress)))
                }
            } keyframes: { _ in
                MoveKeyframe(0.0)
                LinearKeyframe(1.0, duration: 0.7)
            }
            .onAppear { reveal = true }
            .accessibilityHidden(true)
    }
}
