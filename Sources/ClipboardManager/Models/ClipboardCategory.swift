import Foundation
import SwiftUI

struct ClipboardCategory: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var icon: String   // SF Symbol name
    var colorHex: String
    var isSystem: Bool
    var sortOrder: Int

    // MARK: Well-known system categories (stable IDs)

    static let allID       = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let favoritesID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    static let pinnedID    = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!

    static let all = ClipboardCategory(
        id: allID, name: "All Items", icon: "tray.full.fill",
        colorHex: "#007AFF", isSystem: true, sortOrder: 0)

    static let favorites = ClipboardCategory(
        id: favoritesID, name: "Favorites", icon: "star.fill",
        colorHex: "#FFD600", isSystem: true, sortOrder: 1)

    static let pinned = ClipboardCategory(
        id: pinnedID, name: "Pinned", icon: "pin.fill",
        colorHex: "#FF375F", isSystem: true, sortOrder: 2)

    static let defaults: [ClipboardCategory] = [
        .all, .favorites, .pinned,
        ClipboardCategory(id: UUID(), name: "Work",        icon: "briefcase.fill",  colorHex: "#5856D6", isSystem: false, sortOrder: 3),
        ClipboardCategory(id: UUID(), name: "Personal",   icon: "person.fill",     colorHex: "#34C759", isSystem: false, sortOrder: 4),
        ClipboardCategory(id: UUID(), name: "Real Estate",icon: "house.fill",      colorHex: "#FF9500", isSystem: false, sortOrder: 5),
    ]

    var color: Color {
        Color(hex: colorHex) ?? .accentColor
    }
}

// MARK: - Hex color helper

extension Color {
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s = String(s.dropFirst()) }
        guard s.count == 6, let val = UInt64(s, radix: 16) else { return nil }
        let r = Double((val >> 16) & 0xFF) / 255
        let g = Double((val >> 8)  & 0xFF) / 255
        let b = Double(val          & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
