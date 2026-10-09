import Foundation
import Security

/// Somewhere small secrets can be kept. The app uses the Keychain; checks use memory.
protocol SecretStore: Sendable {
    func read(account: String) -> Data?
    func write(_ data: Data, account: String)
    func delete(account: String)
}

/// The iOS Keychain. Items are available after the first unlock since the last restart (so a refresh
/// that runs while the phone is locked still works) and never leave this device: they are excluded
/// from backups and don't move to a new phone.
struct KeychainSecretStore: SecretStore {
    var service = "com.jstnhbbs.app.session"

    private func query(_ account: String) -> [CFString: Any] {
        [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: account]
    }

    func read(account: String) -> Data? {
        var request = query(account)
        request[kSecReturnData] = true
        request[kSecMatchLimit] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(request as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    func write(_ data: Data, account: String) {
        let update: [CFString: Any] = [kSecValueData: data]
        if SecItemUpdate(query(account) as CFDictionary, update as CFDictionary) == errSecSuccess { return }
        var add = query(account)
        add[kSecValueData] = data
        add[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(add as CFDictionary, nil)
        if status != errSecSuccess {
            // The status says why (never what was being stored).
            NSLog("Porchlight: could not save the session to the Keychain (status %d)", status)
        }
    }

    func delete(account: String) {
        SecItemDelete(query(account) as CFDictionary)
    }
}

final class InMemorySecretStore: SecretStore, @unchecked Sendable {
    private let lock = NSLock()
    private var items: [String: Data] = [:]

    func read(account: String) -> Data? { lock.withLock { items[account] } }
    func write(_ data: Data, account: String) { lock.withLock { items[account] = data } }
    func delete(account: String) { lock.withLock { _ = items.removeValue(forKey: account) } }
}

/// The signed-in session for one server: the cookies the sign-in service handed out, kept in the
/// Keychain rather than in the cookie storage that ordinary web requests use.
///
/// The cookie storage keeps cookies in a plain file inside the app's folder, which is included in
/// device backups and readable by anything that can read them. The session cookie is the whole
/// credential (it signs the person in without a password), so it lives in the Keychain, and the app
/// sends it itself instead of letting the system do it. Requests go only to the server it belongs to.
final class SessionCredentials: @unchecked Sendable {
    private let origin: String
    private let host: String?
    private let store: SecretStore
    private let lock = NSLock()
    private var cookies: [String: String]
    private var generation = 0

    var sessionGeneration: Int { lock.withLock { generation } }

    init(baseURL: URL, store: SecretStore = KeychainSecretStore()) {
        self.origin = APIClient.origin(of: baseURL) ?? baseURL.absoluteString
        self.host = baseURL.host
        self.store = store
        if let data = store.read(account: origin),
           let saved = try? JSONDecoder().decode([String: String].self, from: data) {
            cookies = saved
        } else {
            cookies = [:]
        }
    }

    /// One per server, so every client in the app shares the same session.
    private static let lock = NSLock()
    nonisolated(unsafe) private static var shared: [String: SessionCredentials] = [:]

    static func shared(for baseURL: URL) -> SessionCredentials {
        let key = APIClient.origin(of: baseURL) ?? baseURL.absoluteString
        return lock.withLock {
            if let existing = shared[key] { return existing }
            let created = SessionCredentials(baseURL: baseURL)
            created.migrateOnFirstLaunch(baseURL: baseURL)
            shared[key] = created
            return created
        }
    }

    // MARK: Using it

    /// The `Cookie` header to send to `url`, or nil when signed out or when `url` is another server.
    func cookieHeader(for url: URL) -> String? {
        snapshot(for: url).header
    }

    func snapshot(for url: URL) -> (generation: Int, header: String?) {
        return lock.withLock {
            let header = url.host != host || cookies.isEmpty ? nil : cookies.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
            return (generation, header)
        }
    }

    var hasSession: Bool { lock.withLock { !cookies.isEmpty } }

    /// Takes in whatever cookies a response set or removed.
    func absorb(_ response: HTTPURLResponse, from url: URL, generation expectedGeneration: Int? = nil) {
        guard url.host == host else { return }
        let fields = response.allHeaderFields.reduce(into: [String: String]()) { result, pair in
            if let key = pair.key as? String, let value = pair.value as? String { result[key] = value }
        }
        let received = HTTPCookie.cookies(withResponseHeaderFields: fields, for: url)
        guard !received.isEmpty else { return }
        lock.withLock {
            guard expectedGeneration == nil || expectedGeneration == generation else { return }
            for cookie in received {
                let gone = cookie.value.isEmpty || (cookie.expiresDate.map { $0 <= Date() } ?? false)
                if gone { cookies.removeValue(forKey: cookie.name) } else { cookies[cookie.name] = cookie.value }
            }
            persist()
        }
    }

    /// Forgets the session on this device.
    func clear() {
        lock.withLock {
            generation += 1
            cookies = [:]
            store.delete(account: origin)
        }
    }

    private func persist() {
        if cookies.isEmpty {
            store.delete(account: origin)
        } else if let data = try? JSONEncoder().encode(cookies) {
            store.write(data, account: origin)
        }
    }

    // MARK: Moving over from the cookie storage

    private static let initializedKey = "homehub.sessionStoreInitialized"

    /// The first time a version that uses the Keychain runs:
    /// - someone who was already signed in has their session in the old cookie storage; it moves to the
    ///   Keychain and the old copy is deleted, so they stay signed in;
    /// - otherwise this is a fresh install. The Keychain survives deleting an app, so anything still in
    ///   it is a session from a previous install, which is cleared rather than quietly signed back in.
    func migrateOnFirstLaunch(baseURL: URL, defaults: UserDefaults = .standard, storage: HTTPCookieStorage = .shared) {
        guard !defaults.bool(forKey: Self.initializedKey) else { return }
        defaults.set(true, forKey: Self.initializedKey)

        let old = (storage.cookies(for: baseURL) ?? []).filter { !$0.value.isEmpty }
        if old.isEmpty {
            clear()
            return
        }
        lock.withLock {
            for cookie in old { cookies[cookie.name] = cookie.value }
            persist()
        }
        for cookie in old { storage.deleteCookie(cookie) }
    }
}
