import Foundation
import Observation
import AppKit

enum SidebarTab: String, CaseIterable, Identifiable {
    case today = "今日概览"
    case activities = "活动中心"
    case trends = "身体与趋势"
    case studio = "课表与课程"
    case gearSync = "装备与同步"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .today: return "sun.max"
        case .activities: return "figure.run"
        case .trends: return "chart.xyaxis.line"
        case .studio: return "calendar.badge.clock"
        case .gearSync: return "shoeprints.fill"
        }
    }

    func localizedTitle(lang: AppLanguage) -> String {
        switch self {
        case .today: return lang == .ja ? "今日概要" : "今日概览"
        case .activities: return lang == .ja ? "アクティビティ" : "活动中心"
        case .trends: return lang == .ja ? "身体とトレンド" : "身体与趋势"
        case .studio: return lang == .ja ? "練習メニュー" : "课表与课程"
        case .gearSync: return lang == .ja ? "ギアと同期" : "装备与同步"
        }
    }

    var jpLabel: String {
        switch self {
        case .today: return "TODAY"
        case .activities: return "ACTIVITIES"
        case .trends: return "TRENDS"
        case .studio: return "STUDIO"
        case .gearSync: return "GEAR & SYNC"
        }
    }
}

@MainActor
@Observable
final class AppState {
    let bridge = BridgeClient()
    let cache = LocalCacheStore()
    var prefs: UserPreferences = .shared

    var selectedTab: SidebarTab = .today
    var authStatus: AuthStatus?
    var showAuthSheet: Bool = false
    var showSettingsSheet: Bool = false
    var runtimeMode: String = ""

    var dashboard: DashboardSnapshot?
    var activities: [ActivityItem] = []
    var selectedActivityId: Int?
    var currentBundle: ActivityDetailBundle?

    // Fast in-memory RAM cache for instantaneous, zero-delay activity switching
    private var memoryBundleCache: [Int: ActivityDetailBundle] = [:]

    var isSyncingDashboard: Bool = false
    private var dashboardSyncPending = false
    var isLoadingActivities: Bool = false
    var isLoadingBundle: Bool = false
    var isOperatingWorkout: Bool = false
    var isExportingFIT: Bool = false

    /// Global unified loading status across all modules (syncing, details, workouts, export)
    var isAnyLoading: Bool {
        isSyncingDashboard || isLoadingActivities || isLoadingBundle || isOperatingWorkout || isExportingFIT
    }

    var hasMoreActivities: Bool = true
    var bannerMessage: String?
    var bannerIsError: Bool = false
    var lastSyncLabel: String = "尚未同步"

    var selectedDate: Date = Date()
    var isTrackingToday: Bool = true
    var trendDays: Int = 30

    private var hasBootstrapped = false

    func selectDate(_ date: Date) {
        selectedDate = date
        isTrackingToday = Calendar.current.isDateInToday(date)
        Task { await syncDashboard(alignTodayIfTracking: false) }
    }

    func resetToToday() {
        selectedDate = Date()
        isTrackingToday = true
        Task { await syncDashboard(alignTodayIfTracking: true) }
    }

    func bootstrap() async {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true
        runtimeMode = await bridge.runtimeDescription()

        // 监听系统唤醒/切换回前台通知：若跨天过夜且当前处于「今日」跟踪模式，自动滚动至当天并静默同步
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                if self.isTrackingToday && !Calendar.current.isDateInToday(self.selectedDate) {
                    self.selectedDate = Date()
                    await self.syncDashboard(alignTodayIfTracking: true)
                }
            }
        }

        // Instant cold-start from local cache
        if let cachedDash = cache.loadDashboard() {
            dashboard = cachedDash
            lastSyncLabel = "\(prefs.language == .ja ? "キャッシュ" : "本地缓存") · \(String(cachedDash.capturedAt.prefix(19).replacingOccurrences(of: "T", with: " ")))"
        }
        let cachedActs = cache.loadActivities()
        if !cachedActs.isEmpty {
            activities = cachedActs
            if selectedActivityId == nil {
                selectedActivityId = cachedActs.first?.id
            }
        }

        await refreshAuthStatus()
        if authStatus?.authenticated == true {
            // SWR (Stale-While-Revalidate):
            // 启动时已瞬间呈现本地历史缓存，立刻在后台静默拉取 Garmin 最新数据并无缝热更新
            Task {
                await syncAll()
            }
        } else {
            showAuthSheet = true
        }
    }

    func refreshAuthStatus() async {
        do {
            let status = try await bridge.call(method: "auth_status", as: AuthStatus.self)
            authStatus = status
        } catch {
            setBanner("无法启动数据桥接：\(error.localizedDescription)", isError: true)
        }
    }

    func syncAll(forceToday: Bool = false) async {
        // 点击全量同步或刷新按钮时，如果处于跟踪今日模式或处于过夜跨天状态，自动更新到最新的今天
        if isTrackingToday || forceToday || Calendar.current.isDateInYesterday(selectedDate) {
            selectedDate = Date()
            isTrackingToday = true
        }
        await syncDashboard(alignTodayIfTracking: true)
        await loadActivities(reset: true)
    }

    func syncDashboard(alignTodayIfTracking: Bool = true) async {
        guard !isSyncingDashboard else {
            dashboardSyncPending = true
            return
        }
        if alignTodayIfTracking && (isTrackingToday || Calendar.current.isDateInYesterday(selectedDate)) {
            selectedDate = Date()
            isTrackingToday = true
        }
        isSyncingDashboard = true
        defer {
            isSyncingDashboard = false
            if dashboardSyncPending {
                dashboardSyncPending = false
                Task { await syncDashboard(alignTodayIfTracking: false) }
            }
        }

        let dateStr = Self.isoDateString(selectedDate)
        do {
            let snap = try await bridge.call(
                method: "sync_dashboard",
                params: ["date": dateStr, "days_trend": trendDays],
                as: DashboardSnapshot.self
            )
            dashboard = snap
            cache.saveDashboard(snap)
            lastSyncLabel = "\(prefs.language == .ja ? "同期完了" : "已同步") · \(String(snap.capturedAt.prefix(19).replacingOccurrences(of: "T", with: " ")))"
            if let errs = snap.errors, !errs.isEmpty {
                setBanner("部分接口未返回（\(errs.keys.sorted().joined(separator: ", "))），其余数据已更新。", isError: false)
            } else {
                clearBanner()
            }
        } catch let err as BridgeErrorInfo {
            handleBridgeError(err)
        } catch {
            setBanner(error.localizedDescription, isError: true)
        }
    }

    func loadActivities(reset: Bool = false) async {
        guard !isLoadingActivities else { return }
        isLoadingActivities = true
        defer { isLoadingActivities = false }

        let start = reset ? 0 : activities.count
        do {
            let page = try await bridge.call(
                method: "fetch_activities",
                params: ["start": start, "limit": 25],
                as: ActivitiesPageResponse.self
            )
            if reset {
                activities = page.activities
            } else {
                let existingIds = Set(activities.map(\.id))
                let fresh = page.activities.filter { !existingIds.contains($0.id) }
                activities.append(contentsOf: fresh)
            }
            hasMoreActivities = page.hasMore ?? (page.activities.count >= 25)
            cache.saveActivities(activities)
            if selectedActivityId == nil {
                selectedActivityId = activities.first?.id
            }
            if let sel = selectedActivityId {
                await selectActivity(id: sel, forceRefresh: false)
            }
        } catch let err as BridgeErrorInfo {
            handleBridgeError(err)
        } catch {
            setBanner(error.localizedDescription, isError: true)
        }
    }

    /// Selects an activity with ZERO lag: instant RAM-cache display, fallback to disk cache, then background fetch.
    func selectActivity(id: Int, forceRefresh: Bool = false) async {
        selectedActivityId = id

        // 1. Instant RAM Cache hit (0 ms)
        if !forceRefresh, let inMem = memoryBundleCache[id] {
            currentBundle = inMem
            return
        }

        // 2. Local Disk Cache hit (< 5 ms)
        if !forceRefresh, let cached = cache.loadBundle(activityId: id) {
            memoryBundleCache[id] = cached
            currentBundle = cached
            return
        }

        // 3. Network fetch
        isLoadingBundle = true
        defer { isLoadingBundle = false }
        do {
            let bundle = try await bridge.call(
                method: "fetch_activity_bundle",
                params: ["activity_id": id],
                as: ActivityDetailBundle.self
            )
            memoryBundleCache[id] = bundle
            currentBundle = bundle
            cache.saveBundle(bundle)
        } catch let err as BridgeErrorInfo {
            handleBridgeError(err)
        } catch {
            setBanner(error.localizedDescription, isError: true)
        }
    }

    func downloadFIT(activityId: Int) async -> String? {
        isExportingFIT = true
        defer { isExportingFIT = false }
        do {
            let res = try await bridge.callDictionary(
                method: "download_activity_fit",
                params: ["activity_id": activityId]
            )
            let files = res["extracted_files"] as? [String] ?? []
            let targetPath = files.first ?? (res["zip_path"] as? String)
            let msg = targetPath ?? "已保存至 Downloads"
            setBanner("原始 FIT 已导出：\(msg)", isError: false)
            if let targetPath {
                let fileURL = URL(fileURLWithPath: targetPath)
                NSWorkspace.shared.activateFileViewerSelecting([fileURL])
            }
            return msg
        } catch {
            setBanner("导出 FIT 失败：\(error.localizedDescription)", isError: true)
            return nil
        }
    }

    func setActivityGear(activityId: Int, gearUuid: String, action: String) async {
        isOperatingWorkout = true
        defer { isOperatingWorkout = false }
        do {
            _ = try await bridge.callDictionary(
                method: "set_activity_gear",
                params: ["activity_id": activityId, "gear_uuid": gearUuid, "action": action]
            )
            memoryBundleCache.removeValue(forKey: activityId)
            await selectActivity(id: activityId, forceRefresh: true)
            await syncDashboard()
            setBanner("活动装备已更新", isError: false)
        } catch {
            setBanner("更新装备失败：\(error.localizedDescription)", isError: true)
        }
    }

    // MARK: - Workout Actions

    func inspectWorkout(id: Int) async throws -> WorkoutInspectResponse {
        try await bridge.call(method: "workout_inspect", params: ["workout_id": id], as: WorkoutInspectResponse.self)
    }

    func createWorkout(name: String, description: String, steps: [EditableWorkoutStep], scheduleDate: String?, send: Bool) async throws -> Int {
        isOperatingWorkout = true
        defer { isOperatingWorkout = false }
        let spec: [String: Any] = [
            "name": name,
            "description": description,
            "steps": steps.map { $0.toSpecDict() }
        ]
        var params: [String: Any] = ["spec": spec, "send": send]
        if let scheduleDate, !scheduleDate.isEmpty {
            params["schedule_date"] = scheduleDate
        }
        let res = try await bridge.callDictionary(method: "workout_create", params: params)
        await syncDashboard()
        setBanner(send ? "课程已创建并加入手表同步队列" : "课程已创建到 Garmin 云端", isError: false)
        return res["workout_id"] as? Int ?? 0
    }

    func updateWorkout(id: Int, name: String, description: String, steps: [EditableWorkoutStep], send: Bool) async throws {
        isOperatingWorkout = true
        defer { isOperatingWorkout = false }
        let spec: [String: Any] = [
            "name": name,
            "description": description,
            "steps": steps.map { $0.toSpecDict() }
        ]
        _ = try await bridge.callDictionary(
            method: "workout_update",
            params: ["workout_id": id, "spec": spec, "send": send]
        )
        await syncDashboard()
        setBanner(send ? "课程已更新并推送到手表队列" : "课程已更新", isError: false)
    }

    func sendWorkout(id: Int) async {
        isOperatingWorkout = true
        defer { isOperatingWorkout = false }
        do {
            let res = try await bridge.callDictionary(method: "workout_send", params: ["workout_id": id])
            let status = res["status"] as? String ?? "queued"
            setBanner(status == "already_queued" ? "该课程已在手表待发队列中，未重复推送" : "已加入手表发送队列，请打开 Connect App 同步", isError: false)
        } catch {
            setBanner("发送失败：\(error.localizedDescription)", isError: true)
        }
    }

    func deleteWorkout(id: Int) async {
        isOperatingWorkout = true
        defer { isOperatingWorkout = false }
        do {
            _ = try await bridge.callDictionary(method: "workout_delete", params: ["workout_id": id])
            await syncDashboard()
            setBanner("训练课程已删除", isError: false)
        } catch {
            setBanner("删除失败：\(error.localizedDescription)", isError: true)
        }
    }

    func scheduleWorkout(id: Int, date: String) async {
        isOperatingWorkout = true
        defer { isOperatingWorkout = false }
        do {
            _ = try await bridge.callDictionary(method: "workout_schedule", params: ["workout_id": id, "date": date])
            await syncDashboard()
            setBanner("已排期至 \(date)", isError: false)
        } catch {
            setBanner("排期失败：\(error.localizedDescription)", isError: true)
        }
    }

    // MARK: - Auth & Error Helpers

    func handleBridgeError(_ err: BridgeErrorInfo) {
        if err.code == "auth_required" {
            setBanner("Garmin 登录凭证已失效或未登录，请重新认证。", isError: true)
            showAuthSheet = true
        } else if err.code == "rate_limited" {
            setBanner("触发 Garmin 429 接口限流，请稍等几分钟后再同步（当前仍可查看本地缓存）。", isError: true)
        } else {
            setBanner(err.message, isError: true)
        }
    }

    func setBanner(_ text: String, isError: Bool) {
        bannerMessage = text
        bannerIsError = isError
    }

    func clearBanner() {
        bannerMessage = nil
        bannerIsError = false
    }

    static func isoDateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }
}
