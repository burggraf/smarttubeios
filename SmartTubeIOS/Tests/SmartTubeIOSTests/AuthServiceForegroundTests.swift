import Foundation
import Testing

@testable import SmartTubeIOS

/// Intercepts only the device-flow endpoints and credential discovery. No user
/// credentials, Google authorization, or live network are used by these tests.
private final class DeviceFlowURLProtocol: URLProtocol, @unchecked Sendable {
    override static func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "oauth2.googleapis.com"
            || request.url?.absoluteString == "https://www.youtube.com/tv"
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let body: Data
        let status: Int
        switch request.url?.path {
        case "/device/code":
            status = 200
            body = Data(
                """
                {"device_code":"test-device-code","user_code":"TEST-CODE",\
                "verification_url":"https://www.google.com/device",\
                "expires_in":900,"interval":3600}
                """.utf8)
        case "/token":
            status = 428
            body = Data(#"{"error":"authorization_pending"}"#.utf8)
        default:
            // Empty discovery HTML makes the existing credential fetcher use
            // its fallback. That fallback is sent only to this local mock.
            status = 200
            body = Data()
        }
        guard let url = request.url,
            let response = HTTPURLResponse(
                url: url, statusCode: status,
                httpVersion: nil, headerFields: ["Content-Type": "application/json"])
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@Suite("Device sign-in foreground handoff", .serialized)
@MainActor
struct AuthServiceForegroundTests {
    @Test("Returning from Safari preserves the existing token poll")
    func foregroundDoesNotCancelActivePoll() async throws {
        URLProtocol.registerClass(DeviceFlowURLProtocol.self)
        defer { URLProtocol.unregisterClass(DeviceFlowURLProtocol.self) }
        let auth = AuthService()
        auth.clearSession()
        defer { auth.cancelSignIn() }
        await auth.beginSignIn()
        _ = try #require(auth.pendingActivation)
        let original = try #require(auth.pollTask)

        auth.handleForeground()

        #expect(
            !original.isCancelled,
            "An approved code can be consumed by the in-flight request; cancelling it can lose its token response")
        #expect(auth.pollTask == original, "Foregrounding must not create a competing token exchange")
        #expect(auth.error == nil)
    }

    @Test("Foregrounding can recover a cancelled poll without creating a new device code")
    func foregroundRestartsCancelledPoll() async throws {
        URLProtocol.registerClass(DeviceFlowURLProtocol.self)
        defer { URLProtocol.unregisterClass(DeviceFlowURLProtocol.self) }
        let auth = AuthService()
        auth.clearSession()
        defer { auth.cancelSignIn() }
        await auth.beginSignIn()
        let activation = try #require(auth.pendingActivation)
        let original = try #require(auth.pollTask)
        original.cancel()

        auth.handleForeground()

        let restarted = try #require(auth.pollTask)
        #expect(restarted != original)
        #expect(!restarted.isCancelled)
        #expect(auth.pendingActivation?.userCode == activation.userCode)
    }
}
