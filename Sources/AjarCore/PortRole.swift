import Foundation

/// What a listening port is for, judged from how it answers: a monitoring endpoint, an app
/// server, a page, an API, or a socket that does not speak HTTP. Without it, a process with
/// several ports shows only bind addresses, which say nothing about how the ports differ.
public struct PortRole: Sendable, Equatable {
    public enum Kind: String, Sendable {
        case springActuator = "spring-actuator"
        case appHTTP = "app-http"
        case page
        case httpAPI = "http-api"
        case http
        case tcp
    }

    public let kind: Kind
    public let label: String
    public let reason: String

    static let springActuator = PortRole(kind: .springActuator, label: "Spring Actuator",
        reason: L("/actuator lists Spring Boot Actuator endpoints such as health and info: the monitoring port.",
                  "/actuator 返回了 Spring Boot Actuator 的接口列表（health、info 等），这是监控端口。"))

    static let tcp = PortRole(kind: .tcp, label: L("TCP (not HTTP)", "TCP（非 HTTP）"),
        reason: L("Accepts connections but does not answer HTTP: a private protocol for its own clients.",
                  "接受连接但不响应 HTTP，是供自身客户端使用的私有协议。"))

    static let untrustedHTTPS = PortRole(kind: .http, label: "HTTPS",
        reason: L("Answers TLS with a certificate this Mac does not trust; not read further.",
                  "以本机不信任的证书响应 TLS，未进一步读取。"))

    /// Judges the response to `GET /`. Error pages mean an application server whose routes
    /// live under a path of their own, so the page title is only trusted below status 400.
    static func classify(status: Int, contentType: String?, server: String?, body: Data) -> PortRole {
        let type = contentType?.lowercased() ?? ""
        let server = server?.trimmingCharacters(in: .whitespaces).nilIfEmpty
        if type.contains("html") {
            let title = title(in: body)
            if status >= 400 {
                let engine = server ?? (title?.hasPrefix("HTTP Status ") == true ? "Tomcat" : nil)
                return PortRole(kind: .appHTTP, label: L("App HTTP", "应用 HTTP") + (engine.map { " · \($0)" } ?? ""),
                    reason: L("/ answers \(status) with \(engine ?? "an") error page: an application server whose routes live under a path.",
                              "/ 返回 \(status)\(engine.map { "（\($0) 错误页）" } ?? "错误页")：应用服务器，接口挂在某个路径下。"))
            }
            if let title {
                return PortRole(kind: .page, label: title,
                    reason: L("/ serves an HTML page titled “\(title)”.", "/ 返回标题为“\(title)”的网页。"))
            }
        }
        if type.contains("json") {
            return PortRole(kind: .httpAPI, label: "HTTP API",
                reason: L("/ answers \(status) with JSON.", "/ 返回 \(status) 和 JSON。"))
        }
        let detail = [server, type.split(separator: ";").first.map(String.init)].compactMap { $0 }.joined(separator: ", ")
        return PortRole(kind: .http, label: "HTTP",
            reason: L("/ answers \(status)\(detail.isEmpty ? "" : " (\(detail))").", "/ 返回 \(status)\(detail.isEmpty ? "" : "（\(detail)）")。"))
    }

    /// The Actuator index, not any 200: single-page apps answer every path with their page.
    static func isActuatorIndex(_ body: Data) -> Bool {
        guard let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let links = json["_links"] as? [String: Any] else { return false }
        return links["health"] != nil
    }

    static func title(in body: Data) -> String? {
        let html = String(decoding: body, as: UTF8.self)
        guard let open = html.range(of: "<title", options: .caseInsensitive),
              let start = html[open.upperBound...].firstIndex(of: ">"),
              let close = html.range(of: "</title>", options: .caseInsensitive, range: start..<html.endIndex)
        else { return nil }
        var title = html[html.index(after: start)..<close.lowerBound]
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
        for (entity, character) in [("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&#39;", "'"), ("&amp;", "&")] {
            title = title.replacingOccurrences(of: entity, with: character)
        }
        guard !title.isEmpty else { return nil }
        return title.count > 48 ? String(title.prefix(47)) + "…" : title
    }
}

/// Two bounded GETs per port (`/` and `/actuator`) on this Mac's own addresses: no cookies,
/// no redirects, at most 32 KB read, and self-signed certificates only on loopback.
public enum PortRoleProbe {
    private static let limit = 32 * 1024
    private static let delegate = LoopbackOnlyDelegate()
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.urlCredentialStorage = nil
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = 0.75
        configuration.timeoutIntervalForResource = 1.0
        configuration.httpMaximumConnectionsPerHost = 4
        return URLSession(configuration: configuration)
    }()

    /// Probes four ports at a time; ports that refuse connections get no role.
    public static func detect(_ activities: [Activity]) async -> [String: PortRole] {
        var roles: [String: PortRole] = [:]
        for start in stride(from: 0, to: activities.count, by: 4) {
            guard !Task.isCancelled else { break }
            await withTaskGroup(of: (String, PortRole?).self) { group in
                for activity in activities[start..<min(start + 4, activities.count)] {
                    group.addTask { (activity.id, await detect(activity.listener)) }
                }
                for await (id, role) in group {
                    if let role { roles[id] = role }
                }
            }
        }
        return roles
    }

    public static func detect(_ listener: Listener) async -> PortRole? {
        var connected = false
        for url in probeURLs(for: listener) {
            guard !Task.isCancelled else { return nil }
            do {
                let (response, body) = try await fetch(url, accept: "text/html,application/json;q=0.9,*/*;q=0.8")
                if let (index, indexBody) = try? await fetch(url.appendingPathComponent("actuator"), accept: "application/json"),
                   index.statusCode == 200, PortRole.isActuatorIndex(indexBody) {
                    return .springActuator
                }
                return PortRole.classify(status: response.statusCode,
                    contentType: response.value(forHTTPHeaderField: "Content-Type"),
                    server: response.value(forHTTPHeaderField: "Server"), body: body)
            } catch let error as URLError {
                // A certificate this Mac does not trust is HTTPS, not permission to retry HTTP.
                if [.serverCertificateUntrusted, .serverCertificateHasBadDate,
                    .serverCertificateHasUnknownRoot, .serverCertificateNotYetValid].contains(error.code) {
                    return .untrustedHTTPS
                }
                // These follow an accepted connection, so something listens but did not speak HTTP.
                if [.networkConnectionLost, .badServerResponse, .cannotParseResponse, .zeroByteResource,
                    .timedOut, .secureConnectionFailed].contains(error.code) {
                    connected = true
                }
            } catch { }
        }
        return connected ? .tcp : nil
    }

    /// Wildcard binds are reached over 127.0.0.1 rather than `localhost`, which only loopback
    /// literals may answer with a self-signed certificate.
    static func probeURLs(for listener: Listener) -> [URL] {
        BrowserAddress.probeURLs(for: listener).compactMap { url in
            guard url.host == "localhost", var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
            components.host = "127.0.0.1"
            return components.url
        }
    }

    private static func fetch(_ url: URL, accept: String) async throws -> (HTTPURLResponse, Data) {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 0.75)
        request.setValue(accept, forHTTPHeaderField: "Accept")
        let (bytes, response) = try await session.bytes(for: request, delegate: delegate)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        var body = Data()
        for try await byte in bytes {
            body.append(byte)
            if body.count >= limit { break }
        }
        return (http, body)
    }
}

private final class LoopbackOnlyDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let space = challenge.protectionSpace
        if space.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           FaviconPolicy.allowsSelfSignedCertificate(host: space.host), let trust = space.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
