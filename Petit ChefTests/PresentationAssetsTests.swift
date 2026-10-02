import Testing
import UIKit
import AVFoundation
import CoreMedia
@testable import Petit_Chef

struct PresentationAssetsTests {
    @MainActor @Test func displayFontLoadsFromTheAppBundle() throws {
        let font = try #require(UIFont(name: "FrauncesPetitChef-Italic", size: 42))
        #expect(font.familyName == "Fraunces Petit Chef")
        #expect(font.fontDescriptor.symbolicTraits.contains(.traitItalic))
    }

    @Test func allToastStepsHaveAnAuthoredScene() {
        #expect(Set(RecipeCatalog.tomatoToast.steps.map(\.id)) == Set(AuthoredToastScene.allCases.map(\.rawValue)))
    }

    @Test(arguments: AuthoredToastScene.allCases)
    func authoredSceneIsPlayableAndRetainsTransparency(scene: AuthoredToastScene) async throws {
        let url = try #require(Bundle.main.url(forResource: scene.movieName, withExtension: "mov"))
        let asset = AVURLAsset(url: url)
        #expect(try await asset.load(.isPlayable))
        #expect(abs(try await asset.load(.duration).seconds - scene.duration) < 0.05)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        let track = try #require(tracks.first)
        let formats = try await track.load(.formatDescriptions)
        let format = try #require(formats.first)
        let extensions = try #require(CMFormatDescriptionGetExtensions(format)) as NSDictionary
        #expect(extensions[kCMFormatDescriptionExtension_ContainsAlphaChannel] as? Bool == true)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        for seconds in [0, scene.duration - 1.0 / 24] {
            let (image, _) = try await generator.image(at: CMTime(seconds: seconds, preferredTimescale: 24))
            #expect(image.width == 840 && image.height == 640)
        }
        for name in ["\(scene.movieName)-start", "\(scene.movieName)-poster"] {
            let poster = try #require(Bundle.main.url(forResource: name, withExtension: "png"))
            #expect(UIImage(contentsOfFile: poster.path) != nil)
        }
    }
}
