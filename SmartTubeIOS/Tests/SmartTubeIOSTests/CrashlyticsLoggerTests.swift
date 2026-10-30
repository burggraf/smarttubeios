import FirebaseCore
import Foundation
import Testing

@testable import SmartTubeIOS

@Suite("Logging without Firebase configuration")
struct CrashlyticsLoggerTests {
    @Test("All diagnostic paths are safe without a Firebase app")
    func diagnosticsWithoutFirebase() {
        #expect(FirebaseApp.app() == nil)
        let logger = CrashlyticsLogger(category: "PersonalBuildTest")
        logger.notice("Notice")
        logger.error("Error")
        logger.debug("Debug")
        logger.recordNonFatal(NSError(domain: "Test", code: 1), userInfo: ["context": "test"])
        CrashlyticsLogger.setVideoContext(id: "test", title: "Test")
        CrashlyticsLogger.setIntendedVideo(id: "test", title: "Test")
        CrashlyticsLogger.sendDiagnosticReport()
        CrashlyticsLogger.recordSlowVideoLoad(videoId: "test", elapsedMs: 5000, streamType: "test", hasError: false)
        CrashlyticsLogger.sendAutoPlaybackDiagnostic()
        CrashlyticsLogger.sendWrongVideoReport(intendedId: "a", intendedTitle: "A", activeId: "b", activeTitle: "B")
        #expect(CrashlyticsLogger.sessionReportID.count == 8)
        #expect(FirebaseApp.app() == nil, "Logging must not initialize Firebase or enable reporting")
    }
}
