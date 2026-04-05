import Foundation
import AppKit

// MARK: - ClipboardItemType

enum ClipboardItemType: String, Codable, CaseIterable, Identifiable {
    case text       = "text"
    case richText   = "richText"
    case image      = "image"
    case screenshot = "screenshot"
    case file       = "file"
    case link       = "link"
    case unknown    = "unknown"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .text:       return "Text"
        case .richText:   return "Rich Text"
        case .image:      return "Image"
        case .screenshot: return "Screenshot"
        case .file:       return "File"
        case .link:       return "Link"
        case .unknown:    return "Unknown"
        }
    }

    var systemImage: String {
        switch self {
        case .text:       return "doc.text"
        case .richText:   return "doc.richtext"
        case .image:      return "photo"
        case .screenshot: return "camera.viewfinder"
        case .file:       return "folder"
        case .link:       return "link"
        case .unknown:    return "questionmark.circle"
        }
    }
}

// MARK: - ClipboardItem

struct ClipboardItem: Identifiable, Equatable, Hashable {
    let id: UUID
    var type: ClipboardItemType
    var text: String?
    var imageData: Data?
    var filePaths: [String]?
    var sourceApp: String?
    var sourceAppName: String?
    var timestamp: Date
    var isPinned: Bool
    var isFavorite: Bool
    var tags: [String]
    var categoryId: String?
    var accessCount: Int
    var lastAccessed: Date?

    // MARK: Computed

    var displayTitle: String {
        switch type {
        case .text, .richText:
            return text?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: .newlines)
                .first?
                .trimmingCharacters(in: .whitespaces) ?? "Empty"
        case .image, .screenshot:
            let fmt = DateFormatter()
            fmt.dateStyle = .short
            fmt.timeStyle = .short
            return "\(type == .screenshot ? "Screenshot" : "Image") – \(fmt.string(from: timestamp))"
        case .file:
            if let first = filePaths?.first {
                return URL(fileURLWithPath: first).lastPathComponent
            }
            return "File"
        case .link:
            return text ?? "Link"
        case .unknown:
            return "Unknown"
        }
    }

    var previewText: String? {
        switch type {
        case .text, .richText, .link:
            return text
        case .file:
            return filePaths?.joined(separator: "\n")
        default:
            return nil
        }
    }

    var isURL: Bool {
        guard let text, type == .text || type == .link else { return false }
        let t = text.trimmingCharacters(in: .whitespaces)
        return (t.hasPrefix("http://") || t.hasPrefix("https://")) && !t.contains(" ")
    }

    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
