import CryptoKit
import Foundation
import os

private let logger = Logger(subsystem: "de.larsmacario.sam", category: "License")

enum LicenseStatus: String, Codable, Sendable {
    case trialing
    case active
    case revoked
}

struct LicensePayload: Codable, Sendable {
    let v: Int
    let id: String
    let email: String
    let product: String
    let status: LicenseStatus
    let trial_ends_at: String?
    let issued_at: String
}

enum LicenseError: LocalizedError {
    case invalidKey
    case activationFailed(String)
    case network(String)
    case revoked
    case expired

    var errorDescription: String? {
        switch self {
        case .invalidKey:
            return "Ungültiger Lizenzschlüssel."
        case .activationFailed(let message):
            return message
        case .network(let message):
            return message
        case .revoked:
            return "Deine Lizenz wurde widerrufen. Bitte erneut kaufen oder Support kontaktieren."
        case .expired:
            return "Dein Test ist abgelaufen. Bitte auf sam-website kostenpflichtig abschließen."
        }
    }
}

@MainActor
final class LicenseService: ObservableObject {
    static let shared = LicenseService()

    @Published private(set) var isLicensed = false
    @Published private(set) var status: LicenseStatus?
    @Published private(set) var trialEndsAt: Date?
    @Published private(set) var statusMessage = "Lizenz erforderlich"
    @Published private(set) var isRefreshing = false

    private let defaults = UserDefaults.standard
    private let lastOnlineCheckKey = "license.lastOnlineCheck"

    private init() {}

    var storedLicenseKey: String? {
        LicenseKeychain.read()
    }

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        guard let key = LicenseKeychain.read() else {
            applyUnlicensed(message: "Bitte Lizenzschlüssel eingeben.")
            return
        }

        guard let payload = verifyLicenseKey(key) else {
            applyUnlicensed(message: "Ungültiger Lizenzschlüssel.")
            return
        }

        if payload.status == .revoked {
            applyUnlicensed(message: LicenseError.revoked.errorDescription ?? "Lizenz widerrufen.")
            return
        }

        if payload.status == .trialing, let end = parseDate(payload.trial_ends_at), end <= Date() {
            applyUnlicensed(message: LicenseError.expired.errorDescription ?? "Test abgelaufen.")
            return
        }

        if await shouldAttemptOnlineCheck() {
            do {
                try await syncOnline(licenseKey: key, activate: false)
            } catch {
                logger.warning("Online-Lizenzcheck fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
                if payload.status != .active && !offlineGraceAllowsUse() {
                    applyUnlicensed(message: "Offline zu lange – Internetverbindung für Lizenzprüfung nötig.")
                    return
                }
            }
        }

        applyLicensed(from: payload)
    }

    func activate(licenseKey: String) async throws {
        let trimmed = licenseKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let payload = verifyLicenseKey(trimmed) else {
            throw LicenseError.invalidKey
        }

        do {
            try await syncOnline(licenseKey: trimmed, activate: true)
        } catch {
            guard payload.status == .active else { throw error }
            logger.warning("Online-Aktivierung fehlgeschlagen, offline für Lifetime-Lizenz: \(error.localizedDescription, privacy: .public)")
            markOnlineCheckSucceeded()
        }

        try LicenseKeychain.save(trimmed)
        await refresh()
    }

    func clearLicense() {
        LicenseKeychain.delete()
        defaults.removeObject(forKey: lastOnlineCheckKey)
        applyUnlicensed(message: "Keine Lizenz hinterlegt.")
    }

    // MARK: - Private

    private func applyLicensed(from payload: LicensePayload) {
        status = payload.status
        trialEndsAt = parseDate(payload.trial_ends_at)
        isLicensed = true

        switch payload.status {
        case .active:
            statusMessage = "Lizenz aktiv – lebenslang"
        case .trialing:
            if let end = trialEndsAt {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .none
                formatter.locale = Locale(identifier: "de_DE")
                statusMessage = "Test aktiv bis \(formatter.string(from: end))"
            } else {
                statusMessage = "Test aktiv"
            }
        case .revoked:
            statusMessage = "Lizenz widerrufen"
        }
    }

    private func applyUnlicensed(message: String) {
        isLicensed = false
        status = nil
        trialEndsAt = nil
        statusMessage = message
    }

    private func shouldAttemptOnlineCheck() -> Bool {
        guard let last = defaults.object(forKey: lastOnlineCheckKey) as? Date else {
            return true
        }
        return Date().timeIntervalSince(last) > 6 * 3600
    }

    private func offlineGraceAllowsUse() -> Bool {
        guard let last = defaults.object(forKey: lastOnlineCheckKey) as? Date else {
            return false
        }
        return Date().timeIntervalSince(last) <= LicenseConfig.offlineGrace
    }

    private func markOnlineCheckSucceeded() {
        defaults.set(Date(), forKey: lastOnlineCheckKey)
    }

    private func syncOnline(licenseKey: String, activate: Bool) async throws {
        let endpoint = activate ? "activate" : "status"
        let url = LicenseConfig.apiBaseURL
            .appendingPathComponent("api/license/\(endpoint)")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20

        let body: [String: String] = [
            "licenseKey": licenseKey,
            "deviceId": DeviceIdentity.deviceId(),
            "deviceName": DeviceIdentity.deviceName,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw LicenseError.network("Keine Server-Antwort.")
        }

        struct ApiResponse: Decodable {
            let status: LicenseStatus?
            let usable: Bool?
            let trialEndsAt: String?
            let licenseKey: String?
            let error: String?
        }

        let decoded = try JSONDecoder().decode(ApiResponse.self, from: data)

        if http.statusCode == 403 {
            throw LicenseError.revoked
        }
        if http.statusCode >= 400 {
            throw LicenseError.activationFailed(decoded.error ?? "Lizenzprüfung fehlgeschlagen.")
        }

        if decoded.usable == false || decoded.status == .revoked {
            throw LicenseError.revoked
        }

        if let updatedKey = decoded.licenseKey, updatedKey != licenseKey {
            try LicenseKeychain.save(updatedKey)
        }

        markOnlineCheckSucceeded()
    }

    private func verifyLicenseKey(_ key: String) -> LicensePayload? {
        let parts = key.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 3, parts[0] == LicenseConfig.keyPrefix else { return nil }

        let payloadB64 = parts[1]
        let signatureB64 = parts[2]

        guard let message = payloadB64.data(using: .utf8),
              let signature = base64URLDecode(signatureB64),
              let payloadData = base64URLDecode(payloadB64),
              let publicKeyData = Data(base64Encoded: LicenseConfig.publicKeyBase64),
              publicKeyData.count == 32 else {
            return nil
        }

        do {
            let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData)
            guard publicKey.isValidSignature(signature, for: message) else { return nil }
            let payload = try JSONDecoder().decode(LicensePayload.self, from: payloadData)
            guard payload.v == 1 else { return nil }
            return payload
        } catch {
            return nil
        }
    }

    private func parseDate(_ iso: String?) -> Date? {
        guard let iso else { return nil }
        return ISO8601DateFormatter().date(from: iso)
    }

    private func base64URLDecode(_ value: String) -> Data? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = (4 - base64.count % 4) % 4
        if padding > 0 {
            base64 += String(repeating: "=", count: padding)
        }
        return Data(base64Encoded: base64)
    }
}
