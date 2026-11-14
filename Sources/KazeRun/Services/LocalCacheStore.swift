import Foundation

final class LocalCacheStore {
    let baseDir: URL
    private let fm = FileManager.default
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted]
        return e
    }()
    private let decoder = JSONDecoder()

    init() {
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.baseDir = appSupport.appendingPathComponent("KazeRun/cache", isDirectory: true)
        try? fm.createDirectory(at: baseDir, withIntermediateDirectories: true)
        try? fm.createDirectory(at: baseDir.appendingPathComponent("bundles", isDirectory: true), withIntermediateDirectories: true)
    }

    private var dashboardURL: URL { baseDir.appendingPathComponent("dashboard.json") }
    private var activitiesURL: URL { baseDir.appendingPathComponent("activities.json") }
    private func bundleURL(id: Int) -> URL {
        baseDir.appendingPathComponent("bundles/\(id).json")
    }

    func saveDashboard(_ snapshot: DashboardSnapshot) {
        if let data = try? encoder.encode(snapshot) {
            try? data.write(to: dashboardURL, options: .atomic)
        }
    }

    func loadDashboard() -> DashboardSnapshot? {
        guard let data = try? Data(contentsOf: dashboardURL) else { return nil }
        return try? decoder.decode(DashboardSnapshot.self, from: data)
    }

    func saveActivities(_ activities: [ActivityItem]) {
        if let data = try? encoder.encode(activities) {
            try? data.write(to: activitiesURL, options: .atomic)
        }
    }

    func loadActivities() -> [ActivityItem] {
        guard let data = try? Data(contentsOf: activitiesURL),
              let items = try? decoder.decode([ActivityItem].self, from: data) else {
            return []
        }
        return items
    }

    func saveBundle(_ bundle: ActivityDetailBundle) {
        if let data = try? encoder.encode(bundle) {
            try? data.write(to: bundleURL(id: bundle.activityId), options: .atomic)
        }
    }

    func loadBundle(activityId: Int) -> ActivityDetailBundle? {
        guard let data = try? Data(contentsOf: bundleURL(id: activityId)) else { return nil }
        return try? decoder.decode(ActivityDetailBundle.self, from: data)
    }

    func clearAll() {
        try? fm.removeItem(at: baseDir)
        try? fm.createDirectory(at: baseDir, withIntermediateDirectories: true)
        try? fm.createDirectory(at: baseDir.appendingPathComponent("bundles", isDirectory: true), withIntermediateDirectories: true)
    }

    func cacheSizeDescription() -> String {
        guard let enumerator = fm.enumerator(at: baseDir, includingPropertiesForKeys: [.fileSizeKey]) else {
            return "0 KB"
        }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(size)
            }
        }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: total)
    }
}
