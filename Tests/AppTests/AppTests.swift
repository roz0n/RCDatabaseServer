@testable import App
import XCTVapor

final class AppTests: XCTestCase {
    func testRCDatabaseServerWorld() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        try app.test(.GET, "RCDatabaseServer", afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "RCDatabaseServer, world!")
        })
    }
}
