import Foundation

/// Liefert den API-Key für API-Aufrufe. Jeder Client setzt seinen providerspezifischen Header selbst.
protocol AuthProviding: Sendable {
    func apiKey() async throws -> String
    var isConfigured: Bool { get async }
}

enum AuthError: LocalizedError {
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Kein API-Key konfiguriert. Bitte in den Einstellungen hinterlegen."
        }
    }
}

/// API-Key des jeweiligen Providers aus den lokalen Einstellungen.
final class APIKeyAuthProvider: AuthProviding, @unchecked Sendable {
    private let provider: LLMProvider

    init(provider: LLMProvider) {
        self.provider = provider
    }

    var isConfigured: Bool {
        get async {
            await MainActor.run {
                SettingsStore.shared.readAPIKey(for: provider) != nil
            }
        }
    }

    func apiKey() async throws -> String {
        let key = await MainActor.run {
            SettingsStore.shared.readAPIKey(for: provider)
        }
        guard let key, !key.isEmpty else {
            throw AuthError.notConfigured
        }
        return key
    }
}

// MARK: - OAuth-Platzhalter (später)

/// Zukünftiger OAuth-Provider für Claude-Subscription.
/// Noch nicht implementiert – ToS-rechtlich zu prüfen vor Aktivierung.
final class OAuthAuthProvider: AuthProviding, @unchecked Sendable {
    var isConfigured: Bool { get async { false } }

    func apiKey() async throws -> String {
        throw AuthError.notConfigured
    }
}
