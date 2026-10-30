#if !os(tvOS)
import Foundation
import Testing
import SmartTubeIOSCore
@testable import SmartTubeIOS

@Suite("ShortsEmbedJS")
struct ShortsEmbedJSTests {

    @Test("embedURL targets youtube.com/embed/<videoId>")
    func embedURLHasCorrectPathAndHost() {
        let url = ShortsEmbedJS.embedURL(videoId: "abc123XYZ_-")
        #expect(url.host == "www.youtube.com")
        #expect(url.path == "/embed/abc123XYZ_-")
    }

    @Test("embedURL supplies autoplay parameters and hides YouTube chrome for native controls")
    func embedURLHasExpectedQueryItems() {
        let url = ShortsEmbedJS.embedURL(videoId: "abc123XYZ_-", startTime: 5)
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
        let dict = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value) })
        #expect(dict["autoplay"] == "1")
        #expect(dict["mute"] == "1")
        #expect(dict["controls"] == "0")
        #expect(dict["playsinline"] == "1")
        #expect(dict["rel"] == "0")
        #expect(dict["iv_load_policy"] == "3")
        #expect(dict["start"] == "5")
        #expect(dict["origin"] == "https://www.example.com")
    }

    @Test("The spike and production embed builders use identical playback parameters")
    func embedBuildersStayInSync() {
        #expect(
            ShortsEmbedJS.embedURL(videoId: "abc123XYZ_-", startTime: 12.9)
                == ShortsEmbedURL.embedURL(videoId: "abc123XYZ_-", startTime: 12.9))
        #expect(ShortsEmbedJS.playerControlsHiderJS.contains("body *{visibility:hidden!important}"))
        #expect(ShortsEmbedJS.playerControlsHiderJS.contains("video{visibility:visible!important;"))
    }

    @Test("embedURL truncates a fractional startTime to whole seconds")
    func embedURLTruncatesStartTime() {
        let url = ShortsEmbedJS.embedURL(videoId: "abc123XYZ_-", startTime: 12.9)
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
        #expect(items.first { $0.name == "start" }?.value == "12")
    }

    @Test("embedURL defaults startTime to 0")
    func embedURLDefaultsStartTimeToZero() {
        let url = ShortsEmbedJS.embedURL(videoId: "abc123XYZ_-")
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
        #expect(items.first { $0.name == "start" }?.value == "0")
    }

    @Test("htmlWrapper embeds the iframe with id=\"yt\" and the given URL")
    func htmlWrapperContainsIframeWithEmbedURL() {
        let url = ShortsEmbedJS.embedURL(videoId: "abc123XYZ_-")
        let html = ShortsEmbedJS.htmlWrapper(embedURL: url)
        #expect(html.contains("id=\"yt\""))
        #expect(html.contains(url.absoluteString))
    }
}
#endif
