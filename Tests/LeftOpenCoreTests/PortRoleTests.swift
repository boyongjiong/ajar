import Network
import XCTest
@testable import LeftOpenCore

final class PortRoleTests: XCTestCase {
    func testClassifiesRootResponses() {
        let tomcat = Data("<!doctype html><html><head><title>HTTP Status 404 – Not Found</title></head></html>".utf8)
        let app = PortRole.classify(status: 404, contentType: "text/html;charset=utf-8", server: nil, body: tomcat)
        XCTAssertEqual(app.kind, .appHTTP)
        XCTAssertTrue(app.label.hasSuffix(" · Tomcat"))

        let page = PortRole.classify(status: 200, contentType: "text/html", server: nil,
            body: Data("<html><head>\n<TITLE>\n  MRP &amp; Review\n</TITLE></head></html>".utf8))
        XCTAssertEqual(page.kind, .page)
        XCTAssertEqual(page.label, "MRP & Review")

        let api = PortRole.classify(status: 401, contentType: "application/json;charset=UTF-8", server: nil,
            body: Data(#"{"code":"UNAUTHORIZED"}"#.utf8))
        XCTAssertEqual(api.kind, .httpAPI)

        let untitled = PortRole.classify(status: 200, contentType: "text/plain", server: "nginx", body: Data("ok".utf8))
        XCTAssertEqual(untitled.kind, .http)
        XCTAssertTrue(untitled.reason.contains("nginx"))

        let long = String(repeating: "a", count: 80)
        XCTAssertEqual(PortRole.title(in: Data("<title>\(long)</title>".utf8))?.count, 48)
        XCTAssertNil(PortRole.title(in: Data("<title>  </title>".utf8)))
    }

    func testActuatorNeedsItsIndexNotJustA200() {
        XCTAssertTrue(PortRole.isActuatorIndex(Data(#"{"_links":{"self":{"href":"x"},"health":{"href":"y"}}}"#.utf8)))
        // A single-page app answers /actuator with its own page.
        XCTAssertFalse(PortRole.isActuatorIndex(Data("<html><title>App</title></html>".utf8)))
        XCTAssertFalse(PortRole.isActuatorIndex(Data(#"{"_links":{"self":{"href":"x"}}}"#.utf8)))
    }

    func testWildcardBindsAreProbedOverLoopbackLiterals() {
        let listener = Listener(pid: 42, command: "node", uid: 501, user: nil, port: 8088, addresses: ["*"])
        XCTAssertEqual(PortRoleProbe.probeURLs(for: listener).map(\.absoluteString),
                       ["https://127.0.0.1:8088", "http://127.0.0.1:8088"])
    }

    func testProbesRealLoopbackListeners() async throws {
        let actuator = try await serve { request in
            request.hasPrefix("GET /actuator ")
                ? Self.response("200 OK", "application/json", #"{"_links":{"health":{"href":"/actuator/health"}}}"#)
                : Self.response("404 Not Found", "application/json", #"{"status":404}"#)
        }
        defer { actuator.server.cancel() }
        let silent = try await serve { _ in nil }
        defer { silent.server.cancel() }

        let roles = await PortRoleProbe.detect([listener(actuator.port), listener(silent.port)])
        XCTAssertEqual(roles["\(actuator.port):42"]?.kind, .springActuator)
        XCTAssertEqual(roles["\(silent.port):42"]?.kind, .tcp)
    }

    private func listener(_ port: Int) -> Activity {
        let listener = Listener(pid: 42, command: "service", uid: 501, user: nil, port: port, addresses: ["127.0.0.1"])
        let process = ProcessFact(pid: 42, ppid: 1, command: "service", executablePath: nil, uid: 501, user: nil, cwd: nil)
        return Activity(listener: listener, process: process, parentChain: [], projectMarker: nil,
            applicationBundle: nil, scope: .local,
            inference: OwnerInference(label: "service", category: .unknown, confidence: "none", reason: ""))
    }

    private static func response(_ status: String, _ type: String, _ body: String) -> Data {
        Data("HTTP/1.1 \(status)\r\nContent-Type: \(type)\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)".utf8)
    }

    /// A loopback TCP server; `reply` returning nil accepts the connection and never answers.
    private func serve(_ reply: @escaping @Sendable (String) -> Data?) async throws -> (server: NWListener, port: Int) {
        let server = try NWListener(using: .tcp, on: .any)
        let queue = DispatchQueue(label: "leftopen.port-role-test")
        let ready = expectation(description: "Loopback server ready")
        server.stateUpdateHandler = { state in
            if case .ready = state { ready.fulfill() }
        }
        server.newConnectionHandler = { connection in
            connection.start(queue: queue)
            connection.receive(minimumIncompleteLength: 5, maximumLength: 8192) { data, _, _, _ in
                // TLS hellos and silence get no answer, like a daemon with its own protocol.
                guard let data, let answer = reply(String(decoding: data, as: UTF8.self)) else { return }
                connection.send(content: answer, completion: .contentProcessed { _ in connection.cancel() })
            }
        }
        server.start(queue: queue)
        await fulfillment(of: [ready], timeout: 2)
        return (server, try XCTUnwrap(server.port.map { Int($0.rawValue) }))
    }
}
