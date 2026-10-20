import EventKit
import Foundation

/// Finds a video-conference URL on calendar events (Meet, Zoom, Teams, etc.).
enum ConferenceLinkResolver {
    private static let urlInTextPattern =
        #"https?:\/\/[^\s<>"\]\)]+"#

    static func joinURL(from event: EKEvent) -> URL? {
        let candidates = [
            event.url,
            urlFromPlainText(event.location),
            urlFromPlainText(event.notes),
        ].compactMap { $0 }

        for url in candidates {
            if isLikelyConferenceURL(url) {
                return url
            }
        }

        if let notes = event.notes, let parsed = firstURL(in: notes) {
            return parsed
        }
        if let location = event.location, let parsed = firstURL(in: location) {
            return parsed
        }

        return candidates.first { isLikelyConferenceURL($0) }
    }

    static func isLikelyConferenceURL(_ url: URL) -> Bool {
        let absolute = url.absoluteString.lowercased()
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return false
        }

        let host = url.host?.lowercased() ?? ""

        if host.contains("meet.google.com") { return true }
        if host.contains("zoom.us") || host.hasSuffix(".zoom.us") { return true }
        if host.contains("teams.microsoft.com") || host.contains("teams.live.com") { return true }
        if host.contains("webex.com") { return true }
        if host.contains("gotomeeting.com") { return true }
        if host.contains("whereby.com") { return true }
        if host.contains("bluejeans.com") { return true }

        if host.contains("google.com"), absolute.contains("calendar/event") {
            return false
        }

        return host.contains("meet") || absolute.contains("/j/")
    }

    private static func urlFromPlainText(_ text: String?) -> URL? {
        guard let text, !text.isEmpty else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let direct = URL(string: trimmed), direct.scheme != nil {
            return direct
        }
        return firstURL(in: trimmed)
    }

    private static func firstURL(in text: String) -> URL? {
        guard let regex = try? NSRegularExpression(pattern: urlInTextPattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let swiftRange = Range(match.range, in: text) else {
            return nil
        }
        var raw = String(text[swiftRange])
        while let last = raw.last, ",.;)".contains(last) {
            raw.removeLast()
        }
        return URL(string: raw)
    }
}
