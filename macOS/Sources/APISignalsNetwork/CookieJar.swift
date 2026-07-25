import Foundation
import APISignalsCore

public actor CookieJar: Sendable {
    private let storage: HTTPCookieStorage
    public static let shared = CookieJar()

    public init(storage: HTTPCookieStorage = .shared) {
        self.storage = storage
    }

    public func cookies(for url: URL) -> [Cookie] {
        storage.cookies(for: url)?.map { Cookie(from: $0) } ?? []
    }

    public func set(_ cookies: [HTTPCookie]) {
        for cookie in cookies {
            storage.setCookie(cookie)
        }
    }

    public func setCookies(from response: HTTPURLResponse, url: URL) {
        let headers = response.allHeaderFields as? [String: String] ?? [:]
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: headers, for: url)
        set(cookies)
    }

    public func allCookies() -> [Cookie] {
        (storage.cookies ?? []).map { Cookie(from: $0) }
    }

    public func deleteCookie(_ cookie: Cookie) {
        guard let domain = cookie.domain else { return }
        let matching = storage.cookies?.first {
            $0.name == cookie.name && $0.domain == domain
        }
        if let c = matching { storage.deleteCookie(c) }
    }

    public func clearAll() {
        storage.cookies?.forEach { storage.deleteCookie($0) }
    }
}

extension Cookie {
    init(from httpCookie: HTTPCookie) {
        self.init(
            name: httpCookie.name,
            value: httpCookie.value,
            domain: httpCookie.domain,
            path: httpCookie.path,
            expires: httpCookie.expiresDate,
            isSecure: httpCookie.isSecure,
            isHttpOnly: httpCookie.isHTTPOnly
        )
    }
}
