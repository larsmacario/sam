import Foundation

enum LicenseConfig {
    /// Basis-URL der SAM-Website (Lizenz-API). Optional überschreibbar via Info.plist `SAMLicenseAPIBaseURL`.
    static var apiBaseURL: URL {
        if let value = Bundle.main.object(forInfoDictionaryKey: "SAMLicenseAPIBaseURL") as? String,
           let url = URL(string: value) {
            return url
        }
        return URL(string: "https://sam-website.vercel.app")!
    }

    static var purchaseURL: URL {
        var components = URLComponents(url: apiBaseURL, resolvingAgainstBaseURL: false)!
        components.fragment = "pricing"
        return components.url ?? apiBaseURL
    }

    /// Muss mit `NEXT_PUBLIC_LICENSE_PUBLIC_KEY` auf der Website übereinstimmen.
    static let publicKeyBase64 = "G8RuiEQt9w86Q8leLhBEDjv0i3ZZsIj28EXlOKWsaQk="

    static let offlineGrace: TimeInterval = 72 * 3600
    static let keyPrefix = "SAM1"
}
