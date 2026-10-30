import Foundation
import Testing

@testable import SmartTubeIOSCore

// MARK: - FEShortsClientRegressionTests
//
// FEshorts was retired upstream: the initial feed and srch: continuations now use
// anonymous WEB search. TV device-code OAuth tokens must never be sent with WEB
// requests; legacy unprefixed continuation tokens still try authenticated TV browse.

// MARK: - URLProtocol helper

/// Intercepts the first outgoing POST request and captures its JSON body.
/// Returns HTTP 400 so the caller's network path fails fast.
private final class BodyCapturingURLProtocol: URLProtocol, @unchecked Sendable {

    nonisolated(unsafe) static var capturedBody: Data?
    nonisolated(unsafe) static var capturedRequest: URLRequest?

    override class func canInit(with request: URLRequest) -> Bool {
        request.httpMethod == "POST"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        // URLSession converts httpBody to httpBodyStream before handing the request
        // to URLProtocol; httpBody is always nil here.
        // Keep the first request so legacy continuation fallbacks cannot overwrite it.
        if BodyCapturingURLProtocol.capturedBody == nil {
            BodyCapturingURLProtocol.capturedRequest = request
            if let stream = request.httpBodyStream {
                stream.open()
                var body = Data()
                let bufferSize = 4096
                let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
                defer {
                    buffer.deallocate()
                    stream.close()
                }
                // Use read-until-zero rather than hasBytesAvailable; the latter
                // can return false prematurely for in-memory streams.
                while true {
                    let count = stream.read(buffer, maxLength: bufferSize)
                    if count <= 0 { break }
                    body.append(buffer, count: count)
                }
                BodyCapturingURLProtocol.capturedBody = body
            } else if let bodyData = request.httpBody {
                // Fallback: some configurations pass the body directly in httpBody.
                BodyCapturingURLProtocol.capturedBody = bodyData
            }
        }

        // Reply with a minimal HTTP 400 response so the API call fails fast.
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 400,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data())
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

// MARK: - Tests

@Suite("Shorts search and legacy TV authentication — Regression #96", .serialized)
struct FEShortsClientRegressionTests {

    // MARK: - Helpers

    /// Returns an `InnerTubeAPI` wired to `BodyCapturingURLProtocol` via an ephemeral
    /// `URLSession`. This avoids polluting the global URLProtocol registry.
    private func makeTestAPI(authToken: String) -> InnerTubeAPI {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [BodyCapturingURLProtocol.self]
        let session = URLSession(configuration: config)
        return InnerTubeAPI(authToken: authToken, session: session)
    }

    // MARK: - fetchShorts

    @Test("fetchShorts uses filtered WEB search without leaking the TV OAuth token")
    func fetchShortsUsesAnonymousSearch() async throws {
        BodyCapturingURLProtocol.capturedBody = nil
        BodyCapturingURLProtocol.capturedRequest = nil
        let api = makeTestAPI(authToken: "fake-tv-oauth-token")

        // The call will throw (HTTP 400 from BodyCapturingURLProtocol), which is expected.
        _ = try? await api.fetchShorts()

        let bodyData = try #require(
            BodyCapturingURLProtocol.capturedBody,
            "URLProtocol should have captured the POST body"
        )
        let json = try #require(
            try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
            "Request body must be valid JSON"
        )

        let context = json["context"] as? [String: Any]
        let clientDict = context?["client"] as? [String: Any]

        let request = try #require(BodyCapturingURLProtocol.capturedRequest)
        #expect(request.url?.path == "/youtubei/v1/search")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(clientDict?["clientName"] as? String == "WEB")
        #expect(json["query"] as? String == "#shorts")
        #expect(json["params"] as? String == SearchFilter(duration: .short).encodedParams())
        #expect(json["browseId"] == nil, "The retired FEshorts endpoint must not be retried")
    }

    @Test("Search continuations strip their routing prefix and remain anonymous")
    func searchContinuationUsesAnonymousSearch() async throws {
        BodyCapturingURLProtocol.capturedBody = nil
        BodyCapturingURLProtocol.capturedRequest = nil
        let api = makeTestAPI(authToken: "fake-tv-oauth-token")

        _ = try? await api.fetchShortsMore(continuationToken: "srch:search-next-page")

        let body = try #require(BodyCapturingURLProtocol.capturedBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        let request = try #require(BodyCapturingURLProtocol.capturedRequest)
        let context = json["context"] as? [String: Any]
        let client = context?["client"] as? [String: Any]
        #expect(request.url?.path == "/youtubei/v1/search")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(client?["clientName"] as? String == "WEB")
        #expect(json["continuation"] as? String == "search-next-page")
    }

    // MARK: - fetchShortsMore

    /// Verifies that fetchShortsMore sends `clientName: "TVHTML5"`.
    ///
    /// Continuation tokens are client-scoped: a token from a TVHTML5 FEshorts
    /// response must be submitted with TVHTML5 context to work correctly.
    @Test("Legacy fetchShortsMore tokens still use TVHTML5 clientName")
    func fetchShortsMoreSendsTVClient() async throws {
        BodyCapturingURLProtocol.capturedBody = nil
        BodyCapturingURLProtocol.capturedRequest = nil
        let api = makeTestAPI(authToken: "fake-tv-oauth-token")

        _ = try? await api.fetchShortsMore(continuationToken: "test-continuation-token-12345")

        let bodyData = try #require(
            BodyCapturingURLProtocol.capturedBody,
            "URLProtocol should have captured the POST body"
        )
        let json = try #require(
            try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
            "Request body must be valid JSON"
        )

        let context = json["context"] as? [String: Any]
        let clientDict = context?["client"] as? [String: Any]

        #expect(
            clientDict?["clientName"] as? String == "TVHTML5",
            """
            fetchShortsMore must use TVHTML5 client.
            Found clientName=\(String(describing: clientDict?["clientName"]))
            """
        )
        #expect(
            json["continuation"] as? String == "test-continuation-token-12345",
            "fetchShortsMore must forward the continuation token in the body"
        )
        let request = try #require(BodyCapturingURLProtocol.capturedRequest)
        #expect(request.url?.path == "/youtubei/v1/browse")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer fake-tv-oauth-token")
    }
}
