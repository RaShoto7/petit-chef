import SwiftUI
import AVFoundation
import UIKit

/// One local movie per toast step. Timing describes media, never recipe cooking.
enum AuthoredToastScene: String, CaseIterable, Sendable {
    case preheat = "preheat-toast"
    case cutting = "slice-tomatoes"
    case building = "build-toast"
    case baking = "bake-toast"
    case seasoning = "dress-tomatoes"
    case plating = "serve-toast"

    var movieName: String {
        switch self {
        case .preheat: "toast-preheat"
        case .cutting: "toast-cutting"
        case .building: "toast-building"
        case .baking: "toast-baking"
        case .seasoning: "toast-seasoning"
        case .plating: "toast-plating"
        }
    }

    var duration: Double {
        switch self {
        case .cutting, .building, .seasoning: 8
        case .preheat, .baking, .plating: 6
        }
    }
}

/// A scene authored and rendered in Blender; native playback preserves its alpha.
/// It illustrates the gesture without advancing any step or changing a timer.
struct AuthoredCookingAnimation: View {
    let name: String
    var isPlaying: Bool
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                Image(uiImage: poster("\(name)-poster"))
                    .resizable().scaledToFit()
            } else {
                CookingMovieSurface(name: name, isPlaying: isPlaying && scenePhase == .active)
            }
        }
        .accessibilityHidden(true)
    }

    private func poster(_ name: String) -> UIImage {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png"),
              let image = UIImage(contentsOfFile: url.path) else { return UIImage() }
        return image
    }
}

private struct CookingMovieSurface: UIViewRepresentable {
    let name: String
    let isPlaying: Bool

    func makeUIView(context: Context) -> CookingMovieView { CookingMovieView(name: name) }
    func updateUIView(_ view: CookingMovieView, context: Context) { view.setPlaying(isPlaying) }
    static func dismantleUIView(_ view: CookingMovieView, coordinator: ()) { view.stop() }
}

private final class CookingMovieView: UIView {
    private let movieLayer = AVPlayerLayer()
    private let placeholder = UIImageView()
    private var player: AVPlayer?
    private var readiness: NSKeyValueObservation?

    init(name: String) {
        super.init(frame: .zero)
        isOpaque = false
        backgroundColor = .clear
        placeholder.contentMode = .scaleAspectFit
        if let poster = Bundle.main.url(forResource: "\(name)-start", withExtension: "png") {
            placeholder.image = UIImage(contentsOfFile: poster.path)
        }
        addSubview(placeholder)
        movieLayer.videoGravity = .resizeAspect
        movieLayer.backgroundColor = UIColor.clear.cgColor
        layer.addSublayer(movieLayer)
        guard let url = Bundle.main.url(forResource: name, withExtension: "mov") else { return }
        let player = AVPlayer(url: url)
        player.isMuted = true
        player.actionAtItemEnd = .pause // Hold the final pose, without a loop seam.
        player.automaticallyWaitsToMinimizeStalling = false
        self.player = player
        movieLayer.player = player
        readiness = movieLayer.observe(\.isReadyForDisplay, options: [.initial, .new]) { [weak self] layer, _ in
            guard layer.isReadyForDisplay else { return }
            DispatchQueue.main.async { self?.placeholder.isHidden = true }
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin(); CATransaction.setDisableActions(true)
        movieLayer.frame = bounds; placeholder.frame = bounds
        CATransaction.commit()
    }
    func setPlaying(_ value: Bool) { value ? player?.play() : player?.pause() }
    func stop() { player?.pause(); movieLayer.player = nil; readiness?.invalidate() }
}
