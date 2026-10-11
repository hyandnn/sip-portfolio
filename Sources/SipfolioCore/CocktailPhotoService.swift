import Foundation

public struct CocktailPhotoCandidate: Codable, Sendable, Equatable, Identifiable {
    public enum Origin: String, Codable, Sendable { case commons, openverseCommons, openverseFlickr }
    public let title: String
    public let imageURL: URL
    public let thumbnailURL: URL
    public let pageURL: URL
    public let credit: String
    public let license: String
    public let licenseURL: URL
    public let origin: Origin
    public let sourceTitle: String?
    public let categories: [String]?
    public let tags: [String]?
    public let width: Int?
    public let height: Int?
    public var id: String { (imageURL.host ?? "") + imageURL.path }
    public var provider: String {
        switch origin {
        case .commons: "Wikimedia Commons"
        case .openverseCommons: "Openverse · Wikimedia Commons"
        case .openverseFlickr: "Openverse · Flickr"
        }
    }
    public init(title: String, imageURL: URL, thumbnailURL: URL? = nil, pageURL: URL, credit: String, license: String, licenseURL: URL, origin: Origin, sourceTitle: String? = nil, categories: [String]? = nil, tags: [String]? = nil, width: Int? = nil, height: Int? = nil) {
        self.title = title; self.imageURL = imageURL; self.thumbnailURL = thumbnailURL ?? imageURL
        self.pageURL = pageURL; self.credit = credit; self.license = license; self.licenseURL = licenseURL; self.origin = origin
        self.sourceTitle = sourceTitle; self.categories = categories; self.tags = tags; self.width = width; self.height = height
    }
}

public struct CocktailPhotoSearchResult: Sendable {
    public let candidates: [CocktailPhotoCandidate]
    public let notices: [String]
    public init(candidates: [CocktailPhotoCandidate], notices: [String] = []) {
        self.candidates = candidates; self.notices = notices
    }
}

public enum CocktailPhotoError: LocalizedError, Equatable {
    case invalidData, unavailable, sourceChanged, http(Int)
    public var errorDescription: String? {
        switch self {
        case .invalidData: "图片来源返回的数据无法读取，请重试。"
        case .unavailable: "图片地址不可用，可以选择另一张或导入自己的照片。"
        case .sourceChanged: "原始来源的图片或许可无法确认，请选择另一张照片。"
        case .http(429): "图源暂时限制了请求次数，稍后可重试；仍可导入自己的照片。"
        case .http: "这个图源暂时无法连接，稍后可重试。"
        }
    }
}

/// Redirects must stay within the same public provider, including preview image requests.
private final class PhotoRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        guard let original = task.originalRequest?.url, let next = request.url,
              CocktailPhotoService.allowedRedirect(from: original, to: next) else { completionHandler(nil); return }
        completionHandler(request)
    }
}

private struct PhotoHTTPTransport: AIHTTPTransport {
    private let session = URLSession(configuration: .ephemeral, delegate: PhotoRedirectDelegate(), delegateQueue: nil)
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw CocktailPhotoError.invalidData }
        return (data, response)
    }
}

public actor CocktailPhotoService {
    private let transport: any AIHTTPTransport
    private var cache: [String: (Date, CocktailPhotoSearchResult)] = [:]
    private var openverseRetryAfter = Date.distantPast
    public init(transport: (any AIHTTPTransport)? = nil) { self.transport = transport ?? PhotoHTTPTransport() }

    /// Independent of public recipe lookup: only a drink name or user-entered search term is sent.
    public func search(name: String, refresh: Bool = false) async throws -> CocktailPhotoSearchResult {
        try Task.checkCancellation()
        let term = CocktailNames.imageSearchTerm(name)
        guard !term.isEmpty else { return .init(candidates: []) }
        if refresh { cache[term] = nil }
        if let (date, result) = cache[term], Date.now.timeIntervalSince(date) < 600 { return result }
        var candidates: [CocktailPhotoCandidate] = [], notices: [String] = []
        do {
            var parameters = ["generator": "search", "gsrsearch": "\"\(term)\" cocktail filetype:bitmap", "gsrnamespace": "6", "gsrlimit": "18"]
            // A known topic avoids interpreting Highball as any cocktail served in a tall glass.
            if CocktailNames.key(name) == "highball" {
                parameters = ["generator": "categorymembers", "gcmtitle": "Category:Whisky soda", "gcmtype": "file", "gcmlimit": "20"]
            }
            let data = try await request(commonsURL(parameters), refresh: refresh)
            candidates = CocktailPhotoMatcher.ranked(try Self.decodeCommons(data), name: name)
        } catch { try Task.checkCancellation(); notices.append("Wikimedia Commons：\(error.localizedDescription)") }
        // Keep Commons results first. Openverse widens coverage when that source is insufficient.
        if candidates.count < 6 {
            if Date.now < openverseRetryAfter { notices.append("Openverse 请求次数已达限制，稍后可重试。") }
            else {
                do {
                    var components = URLComponents(string: "https://api.openverse.org/v1/images/")!
                    components.queryItems = ["q": "\(term) cocktail", "page_size": "8", "license": "by,by-sa,cc0,pdm", "source": "flickr,wikimedia", "extension": "jpg,jpeg,png", "mature": "false"].sorted { $0.key < $1.key }.map { .init(name: $0.key, value: $0.value) }
                    let data = try await request(components.url!, refresh: refresh)
                    candidates += try Self.decodeOpenverse(data)
                } catch {
                    try Task.checkCancellation()
                    if error as? CocktailPhotoError == .http(429) { openverseRetryAfter = Date.now.addingTimeInterval(900) }
                    notices.append("Openverse：\(error.localizedDescription)")
                }
            }
        }
        var seen = Set<String>()
        try Task.checkCancellation()
        candidates = Array(CocktailPhotoMatcher.ranked(candidates, name: name).filter { seen.insert($0.id).inserted }.prefix(6))
        let result = CocktailPhotoSearchResult(candidates: candidates, notices: notices)
        // Failed providers are retryable; successful searches are reused during this app session.
        if notices.isEmpty {
            if cache.count >= 64 { cache.removeAll() }
            cache[term] = (.now, result)
        }
        return result
    }

    public func preview(_ candidate: CocktailPhotoCandidate, refresh: Bool = false) async throws -> Data {
        guard Self.isImageURL(candidate.thumbnailURL) else { throw CocktailPhotoError.unavailable }
        return try await request(candidate.thumbnailURL, limit: 15 * 1024 * 1024, refresh: refresh)
    }

    /// Recheck the original source before saving an indexed photo and use its current attribution.
    public func download(_ candidate: CocktailPhotoCandidate, searchTerm: String, matchingName: String? = nil) async throws -> (Data, CocktailPhotoMetadata) {
        let verified: CocktailPhotoCandidate
        switch candidate.origin {
        case .commons, .openverseCommons:
            guard Self.isCommonsPage(candidate.pageURL) else { throw CocktailPhotoError.sourceChanged }
            var parameters: [String: String] = [:]
            if candidate.pageURL.path.hasPrefix("/wiki/File:") {
                parameters["titles"] = String(candidate.pageURL.path.dropFirst("/wiki/".count))
            } else if let id = URLComponents(url: candidate.pageURL, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "curid" })?.value, Int(id) != nil {
                parameters["pageids"] = id
            } else { throw CocktailPhotoError.sourceChanged }
            let fresh = try Self.decodeCommons(await request(commonsURL(parameters), refresh: true))
            guard let match = fresh.first(where: { $0.id == candidate.id }) else { throw CocktailPhotoError.sourceChanged }
            if let matchingName, CocktailPhotoMatcher.score(match, name: matchingName) == nil { throw CocktailPhotoError.sourceChanged }
            verified = .init(title: match.title, imageURL: match.imageURL, thumbnailURL: match.thumbnailURL, pageURL: match.pageURL, credit: match.credit, license: match.license, licenseURL: match.licenseURL, origin: candidate.origin)
        case .openverseFlickr:
            if let matchingName, CocktailPhotoMatcher.score(candidate, name: matchingName) == nil { throw CocktailPhotoError.sourceChanged }
            guard Self.isFlickrPage(candidate.pageURL), Self.isFlickrImage(candidate.imageURL),
                  let photoID = candidate.pageURL.path.split(separator: "/").last,
                  candidate.imageURL.lastPathComponent.hasPrefix("\(photoID)_") else { throw CocktailPhotoError.sourceChanged }
            let page = try await request(candidate.pageURL, limit: 2 * 1024 * 1024, refresh: true)
            let license = try Self.flickrLicense(page, matching: candidate.pageURL)
            verified = .init(title: candidate.title, imageURL: candidate.imageURL, pageURL: candidate.pageURL, credit: license.2, license: license.0, licenseURL: license.1, origin: candidate.origin)
        }
        guard Self.isImageURL(verified.imageURL) else { throw CocktailPhotoError.unavailable }
        let image = try await request(verified.imageURL, limit: 15 * 1024 * 1024)
        return (image, CocktailPhotoMetadata(provider: verified.provider, pageURL: verified.pageURL.absoluteString, photoURL: verified.imageURL.absoluteString, photoSourceURL: verified.pageURL.absoluteString, credit: verified.credit, creativeCommonsConfirmed: true, usesOriginalPhoto: true, license: verified.license, licenseURL: verified.licenseURL.absoluteString, searchTerm: searchTerm))
    }

    private func commonsURL(_ parameters: [String: String]) -> URL {
        var components = URLComponents(string: "https://commons.wikimedia.org/w/api.php")!
        var values = parameters
        values.merge(["action": "query", "format": "json", "formatversion": "2", "prop": "imageinfo|categories", "cllimit": "max", "iiprop": "url|mime|size|extmetadata", "iiurlwidth": "640", "iiextmetadatafilter": "Artist|LicenseShortName|LicenseUrl|ImageDescription", "iiextmetadatalanguage": "en"]) { _, new in new }
        components.queryItems = values.sorted { $0.key < $1.key }.map { .init(name: $0.key, value: $0.value) }
        return components.url!
    }

    private func request(_ url: URL, limit: Int = 2 * 1024 * 1024, refresh: Bool = false) async throws -> Data {
        var request = URLRequest(url: url); request.timeoutInterval = 18
        if refresh { request.cachePolicy = .reloadIgnoringLocalCacheData }
        request.setValue("Sipfolio (https://github.com/hyandnn/sip-portfolio)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await transport.data(for: request)
        try Task.checkCancellation()
        guard (200..<300).contains(response.statusCode) else { throw CocktailPhotoError.http(response.statusCode) }
        guard let final = response.url, Self.allowedRedirect(from: url, to: final), data.count <= limit else { throw CocktailPhotoError.unavailable }
        return data
    }

    public static func decodeCommons(_ data: Data) throws -> [CocktailPhotoCandidate] {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any], object["error"] == nil else { throw CocktailPhotoError.invalidData }
        guard let query = object["query"] as? [String: Any] else { return [] }
        guard let pages = query["pages"] as? [[String: Any]] else { throw CocktailPhotoError.invalidData }
        return pages.sorted { ($0["index"] as? Int ?? 0) < ($1["index"] as? Int ?? 0) }.compactMap { page in
            guard let info = (page["imageinfo"] as? [[String: Any]])?.first,
                  ["image/jpeg", "image/png", "image/webp"].contains(info["mime"] as? String ?? ""),
                  (info["width"] as? Int ?? 0) >= 300, (info["height"] as? Int ?? 0) >= 200,
                  (info["size"] as? Int ?? Int.max) <= 15 * 1024 * 1024,
                  let image = URL(string: info["url"] as? String ?? ""), isCommonsImage(image),
                  let pageURL = URL(string: info["descriptionurl"] as? String ?? ""), isCommonsPage(pageURL),
                  let meta = info["extmetadata"] as? [String: [String: Any]],
                  let licenseURL = URL(string: meta["LicenseUrl"]?["value"] as? String ?? ""), let license = acceptedLicense(licenseURL) else { return nil }
            let artist = plainText(meta["Artist"]?["value"] as? String ?? "")
            guard !artist.isEmpty else { return nil }
            let thumb = URL(string: info["thumburl"] as? String ?? "").flatMap { isCommonsImage($0) ? $0 : nil }
            let description = plainText(meta["ImageDescription"]?["value"] as? String ?? "")
            let title = description.isEmpty ? String((page["title"] as? String ?? "").dropFirst(5)) : description
            return .init(title: String(title.prefix(180)), imageURL: image, thumbnailURL: thumb, pageURL: pageURL, credit: artist, license: license, licenseURL: licenseURL, origin: .commons, sourceTitle: page["title"] as? String, categories: (page["categories"] as? [[String: Any]])?.compactMap { $0["title"] as? String }, width: info["width"] as? Int, height: info["height"] as? Int)
        }
    }

    public static func decodeOpenverse(_ data: Data) throws -> [CocktailPhotoCandidate] {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any], let results = object["results"] as? [[String: Any]] else { throw CocktailPhotoError.invalidData }
        return results.compactMap { item in
            guard item["mature"] as? Bool != true,
                  (item["width"] as? Int ?? 0) >= 300, (item["height"] as? Int ?? 0) >= 200,
                  let image = URL(string: item["url"] as? String ?? ""),
                  let page = URL(string: item["foreign_landing_url"] as? String ?? ""),
                  let licenseURL = URL(string: item["license_url"] as? String ?? ""), let license = acceptedLicense(licenseURL) else { return nil }
            let origin: CocktailPhotoCandidate.Origin
            if isCommonsImage(image), isCommonsPage(page) { origin = .openverseCommons }
            else if isFlickrImage(image), isFlickrPage(page) { origin = .openverseFlickr }
            else { return nil }
            let credit = plainText(item["creator"] as? String ?? "")
            guard !credit.isEmpty else { return nil }
            // Fetch the supported provider's image directly rather than an arbitrary proxy/redirect.
            return .init(title: String(plainText(item["title"] as? String ?? "成品照片").prefix(180)), imageURL: image, pageURL: page, credit: credit, license: license, licenseURL: licenseURL, origin: origin, tags: (item["tags"] as? [[String: Any]])?.compactMap { $0["name"] as? String }, width: item["width"] as? Int, height: item["height"] as? Int)
        }
    }

    static func flickrLicense(_ data: Data, matching page: URL) throws -> (String, URL, String) {
        guard let html = String(data: data, encoding: .utf8) else { throw CocktailPhotoError.sourceChanged }
        let pattern = #"<script[^>]*type=["']application/ld\+json["'][^>]*>([\s\S]*?)</script>"#
        let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        for match in regex.matches(in: html, range: NSRange(html.startIndex..., in: html)) {
            guard let range = Range(match.range(at: 1), in: html),
                  let root = try? JSONSerialization.jsonObject(with: Data(html[range].utf8)) as? [String: Any] else { continue }
            let objects = root["@graph"] as? [[String: Any]] ?? [root]
            for object in objects {
                guard object["@type"] as? String == "ImageObject",
                      let licenseURL = URL(string: object["license"] as? String ?? ""), let license = acceptedLicense(licenseURL),
                      let source = URL(string: object["acquireLicensePage"] as? String ?? ""), isFlickrPage(source),
                      source.path.split(separator: "/").last == page.path.split(separator: "/").last,
                      let content = URL(string: object["contentUrl"] as? String ?? ""), isFlickrImage(content),
                      let photoID = page.path.split(separator: "/").last, content.lastPathComponent.hasPrefix("\(photoID)_"),
                      let author = object["author"] as? [String: Any], let name = author["name"] as? String, !name.isEmpty else { continue }
                return (license, licenseURL, plainText(name))
            }
        }
        throw CocktailPhotoError.sourceChanged
    }

    static func acceptedLicense(_ url: URL) -> String? {
        guard ["http", "https"].contains(url.scheme), ["creativecommons.org", "www.creativecommons.org"].contains(url.host) else { return nil }
        let parts = url.path.split(separator: "/").map(String.init)
        if parts.count >= 3, parts[0] == "licenses", ["by", "by-sa"].contains(parts[1]), ["1.0", "2.0", "2.5", "3.0", "4.0"].contains(parts[2]) {
            return "CC \(parts[1].uppercased()) \(parts[2])"
        }
        if parts.count >= 3, parts[0] == "publicdomain", parts[2] == "1.0" {
            if parts[1] == "zero" { return "CC0 1.0" }
            if parts[1] == "mark" { return "Public Domain" }
        }
        return nil
    }

    private static func plainText(_ value: String) -> String {
        value.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&").replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'").replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    static func isCommonsImage(_ url: URL) -> Bool { url.scheme == "https" && ["upload.wikimedia.org", "thumb.wikimedia.org"].contains(url.host) && url.path.hasPrefix("/wikipedia/commons/") && url.user == nil && url.port == nil }
    static func isFlickrImage(_ url: URL) -> Bool { url.scheme == "https" && url.host == "live.staticflickr.com" && url.user == nil && url.port == nil }
    static func isImageURL(_ url: URL) -> Bool { isCommonsImage(url) || isFlickrImage(url) }
    static func isCommonsPage(_ url: URL) -> Bool { url.scheme == "https" && url.host == "commons.wikimedia.org" && (url.path.hasPrefix("/wiki/File:") || url.path == "/w/index.php") && url.user == nil && url.port == nil }
    static func isFlickrPage(_ url: URL) -> Bool { url.scheme == "https" && ["www.flickr.com", "flickr.com"].contains(url.host) && url.path.hasPrefix("/photos/") && url.user == nil && url.port == nil }
    static func allowedRedirect(from original: URL, to next: URL) -> Bool {
        guard next.scheme == "https", next.user == nil, next.port == nil else { return false }
        if isCommonsImage(original) { return isCommonsImage(next) }
        if isFlickrImage(original) { return isFlickrImage(next) }
        if isFlickrPage(original) { return isFlickrPage(next) }
        return original.host == next.host && ["commons.wikimedia.org", "api.openverse.org"].contains(next.host)
    }
}
