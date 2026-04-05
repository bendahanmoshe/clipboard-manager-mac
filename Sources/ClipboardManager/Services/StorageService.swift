import Foundation
import SQLite3

// MARK: - SQLite helpers

private let SQLITE_STATIC    = unsafeBitCast(0,  to: sqlite3_destructor_type.self)
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

// MARK: - StorageService

final class StorageService: @unchecked Sendable {
    static let shared = StorageService()

    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "com.clipboardmanager.db", qos: .utility)

    private init() { openDatabase() }

    // MARK: - Setup

    private var dbURL: URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ClipboardManager", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("clipboard.db")
    }

    private func openDatabase() {
        guard sqlite3_open(dbURL.path, &db) == SQLITE_OK else { return }
        exec("PRAGMA journal_mode=WAL;")
        exec("PRAGMA synchronous=NORMAL;")
        exec("PRAGMA cache_size=10000;")
        exec("PRAGMA temp_store=MEMORY;")
        createSchema()
    }

    private func exec(_ sql: String) {
        sqlite3_exec(db, sql, nil, nil, nil)
    }

    private func createSchema() {
        exec("""
            CREATE TABLE IF NOT EXISTS clipboard_items (
                id              TEXT PRIMARY KEY,
                type            TEXT NOT NULL,
                text            TEXT,
                image_data      BLOB,
                file_paths      TEXT,
                source_app      TEXT,
                source_app_name TEXT,
                timestamp       REAL NOT NULL,
                is_pinned       INTEGER DEFAULT 0,
                is_favorite     INTEGER DEFAULT 0,
                tags            TEXT DEFAULT '[]',
                category_id     TEXT,
                access_count    INTEGER DEFAULT 0,
                last_accessed   REAL
            );
        """)
        exec("CREATE INDEX IF NOT EXISTS idx_ts   ON clipboard_items(timestamp DESC);")
        exec("CREATE INDEX IF NOT EXISTS idx_type ON clipboard_items(type);")
        exec("CREATE INDEX IF NOT EXISTS idx_pin  ON clipboard_items(is_pinned);")
        exec("CREATE INDEX IF NOT EXISTS idx_fav  ON clipboard_items(is_favorite);")

        exec("""
            CREATE VIRTUAL TABLE IF NOT EXISTS clipboard_fts USING fts5(
                item_id   UNINDEXED,
                body,
                tokenize  = 'porter ascii'
            );
        """)
    }

    // MARK: - Insert

    func insert(_ item: ClipboardItem) {
        queue.async { [weak self] in self?.insertSync(item) }
    }

    private func insertSync(_ item: ClipboardItem) {
        let sql = """
            INSERT OR IGNORE INTO clipboard_items
            (id, type, text, image_data, file_paths, source_app, source_app_name,
             timestamp, is_pinned, is_favorite, tags, category_id, access_count, last_accessed)
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?);
        """
        guard let stmt = prepare(sql) else { return }
        defer { sqlite3_finalize(stmt) }

        let tagsJSON = (try? JSONEncoder().encode(item.tags)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        let fpJSON   = item.filePaths.flatMap { try? JSONEncoder().encode($0) }.flatMap { String(data: $0, encoding: .utf8) }

        bind(stmt, 1,  item.id.uuidString)
        bind(stmt, 2,  item.type.rawValue)
        bindOptional(stmt, 3,  item.text)
        if let data = item.imageData {
            sqlite3_bind_blob(stmt, 4, (data as NSData).bytes, Int32(data.count), SQLITE_TRANSIENT)
        } else { sqlite3_bind_null(stmt, 4) }
        bindOptional(stmt, 5,  fpJSON)
        bindOptional(stmt, 6,  item.sourceApp)
        bindOptional(stmt, 7,  item.sourceAppName)
        sqlite3_bind_double(stmt, 8, item.timestamp.timeIntervalSince1970)
        sqlite3_bind_int(stmt, 9,  item.isPinned   ? 1 : 0)
        sqlite3_bind_int(stmt, 10, item.isFavorite ? 1 : 0)
        bind(stmt, 11, tagsJSON)
        bindOptional(stmt, 12, item.categoryId)
        sqlite3_bind_int(stmt, 13, Int32(item.accessCount))
        if let la = item.lastAccessed { sqlite3_bind_double(stmt, 14, la.timeIntervalSince1970) }
        else { sqlite3_bind_null(stmt, 14) }

        sqlite3_step(stmt)

        // FTS index
        let body = [item.text, item.sourceAppName, item.filePaths?.joined(separator: " ")]
            .compactMap { $0 }.joined(separator: " ")
        let fts = prepare("INSERT INTO clipboard_fts(item_id, body) VALUES (?,?);")
        if let fts {
            defer { sqlite3_finalize(fts) }
            bind(fts, 1, item.id.uuidString)
            bind(fts, 2, body)
            sqlite3_step(fts)
        }
    }

    // MARK: - Fetch

    func fetchAll(limit: Int = 200, offset: Int = 0,
                  type: ClipboardItemType? = nil,
                  categoryId: String? = nil) -> [ClipboardItem] {
        var result: [ClipboardItem] = []
        queue.sync {
            var clauses: [String] = []
            if type != nil       { clauses.append("type = ?") }
            if categoryId != nil { clauses.append("category_id = ?") }

            var sql = "SELECT * FROM clipboard_items"
            if !clauses.isEmpty { sql += " WHERE " + clauses.joined(separator: " AND ") }
            sql += " ORDER BY is_pinned DESC, timestamp DESC LIMIT ? OFFSET ?"

            guard let stmt = prepare(sql) else { return }
            defer { sqlite3_finalize(stmt) }

            var idx: Int32 = 1
            if let t = type       { bind(stmt, idx, t.rawValue); idx += 1 }
            if let c = categoryId { bind(stmt, idx, c);          idx += 1 }
            sqlite3_bind_int(stmt, idx, Int32(limit));  idx += 1
            sqlite3_bind_int(stmt, idx, Int32(offset))

            while sqlite3_step(stmt) == SQLITE_ROW {
                if let item = rowToItem(stmt) { result.append(item) }
            }
        }
        return result
    }

    func search(query: String, type: ClipboardItemType? = nil,
                categoryId: String? = nil, limit: Int = 200) -> [ClipboardItem] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return fetchAll(limit: limit, type: type, categoryId: categoryId)
        }
        var result: [ClipboardItem] = []
        queue.sync {
            let ftsQ = query.components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }
                .map { "\($0)*" }
                .joined(separator: " ")

            var sql = """
                SELECT ci.* FROM clipboard_items ci
                INNER JOIN clipboard_fts fts ON ci.id = fts.item_id
                WHERE clipboard_fts MATCH ?
            """
            if let type       { sql += " AND ci.type = '\(type.rawValue)'" }
            if let categoryId { sql += " AND ci.category_id = '\(categoryId)'" }
            sql += " ORDER BY ci.is_pinned DESC, rank, ci.timestamp DESC LIMIT ?"

            guard let stmt = prepare(sql) else { return }
            defer { sqlite3_finalize(stmt) }
            bind(stmt, 1, ftsQ)
            sqlite3_bind_int(stmt, 2, Int32(limit))
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let item = rowToItem(stmt) { result.append(item) }
            }
        }
        return result
    }

    // MARK: - Category

    func updateCategory(id: UUID, categoryId: String?) {
        queue.async { [weak self] in
            let value = categoryId.map { "'\($0)'" } ?? "NULL"
            self?.exec("UPDATE clipboard_items SET category_id=\(value) WHERE id='\(id.uuidString)';")
        }
    }

    func fetchFavorites(limit: Int = 200) -> [ClipboardItem] {
        var result: [ClipboardItem] = []
        queue.sync {
            guard let stmt = prepare(
                "SELECT * FROM clipboard_items WHERE is_favorite=1 ORDER BY timestamp DESC LIMIT ?;")
            else { return }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_int(stmt, 1, Int32(limit))
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let item = rowToItem(stmt) { result.append(item) }
            }
        }
        return result
    }

    func fetchPinned() -> [ClipboardItem] {
        var result: [ClipboardItem] = []
        queue.sync {
            guard let stmt = prepare(
                "SELECT * FROM clipboard_items WHERE is_pinned=1 ORDER BY timestamp DESC;")
            else { return }
            defer { sqlite3_finalize(stmt) }
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let item = rowToItem(stmt) { result.append(item) }
            }
        }
        return result
    }

    // MARK: - Update / Delete

    func delete(id: UUID) {
        queue.async { [weak self] in
            self?.exec("DELETE FROM clipboard_items WHERE id='\(id.uuidString)';")
            self?.exec("DELETE FROM clipboard_fts WHERE item_id='\(id.uuidString)';")
        }
    }

    func update(id: UUID, isPinned: Bool? = nil, isFavorite: Bool? = nil,
                tags: [String]? = nil, categoryId: String? = nil) {
        queue.async { [weak self] in
            var parts: [String] = []
            if let v = isPinned   { parts.append("is_pinned=\(v ? 1 : 0)") }
            if let v = isFavorite { parts.append("is_favorite=\(v ? 1 : 0)") }
            if let t = tags, let j = try? JSONEncoder().encode(t),
               let s = String(data: j, encoding: .utf8) {
                parts.append("tags='\(s)'")
            }
            if let c = categoryId { parts.append("category_id='\(c)'") }
            guard !parts.isEmpty else { return }
            self?.exec("UPDATE clipboard_items SET \(parts.joined(separator: ",")) WHERE id='\(id.uuidString)';")
        }
    }

    func incrementAccess(id: UUID) {
        queue.async { [weak self] in
            let ts = Date().timeIntervalSince1970
            self?.exec("UPDATE clipboard_items SET access_count=access_count+1, last_accessed=\(ts) WHERE id='\(id.uuidString)';")
        }
    }

    func cleanup(maxItems: Int, maxAgeDays: Int? = nil) {
        queue.async { [weak self] in
            if let days = maxAgeDays {
                let cutoff = Date().addingTimeInterval(-Double(days * 86400)).timeIntervalSince1970
                self?.exec("DELETE FROM clipboard_items WHERE timestamp<\(cutoff) AND is_pinned=0 AND is_favorite=0;")
            }
            if maxItems > 0 {
                self?.exec("""
                    DELETE FROM clipboard_items WHERE id IN (
                        SELECT id FROM clipboard_items WHERE is_pinned=0 AND is_favorite=0
                        ORDER BY timestamp DESC LIMIT -1 OFFSET \(maxItems)
                    );
                """)
            }
        }
    }

    func totalCount() -> Int {
        var n = 0
        queue.sync {
            guard let stmt = prepare("SELECT COUNT(*) FROM clipboard_items;") else { return }
            defer { sqlite3_finalize(stmt) }
            if sqlite3_step(stmt) == SQLITE_ROW { n = Int(sqlite3_column_int(stmt, 0)) }
        }
        return n
    }

    // MARK: - Helpers

    private func prepare(_ sql: String) -> OpaquePointer? {
        var stmt: OpaquePointer?
        return sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK ? stmt : nil
    }

    private func bind(_ stmt: OpaquePointer?, _ col: Int32, _ val: String) {
        sqlite3_bind_text(stmt, col, val, -1, SQLITE_TRANSIENT)
    }

    private func bindOptional(_ stmt: OpaquePointer?, _ col: Int32, _ val: String?) {
        if let val { bind(stmt, col, val) } else { sqlite3_bind_null(stmt, col) }
    }

    private func rowToItem(_ stmt: OpaquePointer) -> ClipboardItem? {
        guard
            let idStr  = sqlite3_column_text(stmt, 0).map({ String(cString: $0) }),
            let id     = UUID(uuidString: idStr),
            let typStr = sqlite3_column_text(stmt, 1).map({ String(cString: $0) }),
            let type   = ClipboardItemType(rawValue: typStr)
        else { return nil }

        let text            = sqlite3_column_text(stmt, 2).map { String(cString: $0) }
        let blobLen         = sqlite3_column_bytes(stmt, 3)
        let imageData: Data? = blobLen > 0
            ? Data(bytes: sqlite3_column_blob(stmt, 3)!, count: Int(blobLen))
            : nil

        var filePaths: [String]? = nil
        if let fp = sqlite3_column_text(stmt, 4).map({ String(cString: $0) }),
           let d  = fp.data(using: .utf8) {
            filePaths = try? JSONDecoder().decode([String].self, from: d)
        }

        let sourceApp     = sqlite3_column_text(stmt, 5).map { String(cString: $0) }
        let sourceAppName = sqlite3_column_text(stmt, 6).map { String(cString: $0) }
        let timestamp     = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 7))
        let isPinned      = sqlite3_column_int(stmt, 8) != 0
        let isFavorite    = sqlite3_column_int(stmt, 9) != 0

        var tags: [String] = []
        if let ts = sqlite3_column_text(stmt, 10).map({ String(cString: $0) }),
           let d  = ts.data(using: .utf8) {
            tags = (try? JSONDecoder().decode([String].self, from: d)) ?? []
        }

        let categoryId   = sqlite3_column_text(stmt, 11).map { String(cString: $0) }
        let accessCount  = Int(sqlite3_column_int(stmt, 12))
        let lats         = sqlite3_column_double(stmt, 13)
        let lastAccessed = lats > 0 ? Date(timeIntervalSince1970: lats) : nil

        return ClipboardItem(
            id: id, type: type, text: text, imageData: imageData, filePaths: filePaths,
            sourceApp: sourceApp, sourceAppName: sourceAppName, timestamp: timestamp,
            isPinned: isPinned, isFavorite: isFavorite, tags: tags, categoryId: categoryId,
            accessCount: accessCount, lastAccessed: lastAccessed
        )
    }
}
