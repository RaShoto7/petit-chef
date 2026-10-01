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

    @Test func authoredSceneIsPlayableAndRetainsTransparency() async throws {
        let url = try #require(Bundle.main.url(forResource: "toast-plating", withExtension: "mov"))
        let asset = AVURLAsset(url: url)
        #expect(try await asset.load(.isPlayable))
        #expect(abs(try await asset.load(.duration).seconds - 6) < 0.05)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        let track = try #require(tracks.first)
        let formats = try await track.load(.formatDescriptions)
        let format = try #require(formats.first)
        let extensions = try #require(CMFormatDescriptionGetExtensions(format)) as NSDictionary
        #expect(extensions[kCMFormatDescriptionExtension_ContainsAlphaChannel] as? Bool == true)
        for name in ["toast-plating-start", "toast-plating-poster"] {
            let poster = try #require(Bundle.main.url(forResource: name, withExtension: "png"))
            #expect(UIImage(contentsOfFile: poster.path) != nil)
        }
    }
}
