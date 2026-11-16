import Foundation
import SwiftUI

enum PaceUnit: String, CaseIterable, Identifiable, Codable {
    case minPerKm = "min_km"
    case kmPerHour = "kmh"
    case minPerMile = "min_mi"

    var id: String { rawValue }

    func label(lang: AppLanguage) -> String {
        switch self {
        case .minPerKm:
            return lang == .ja ? "分:秒/km (標準)" : "分:秒/公里 (默认)"
        case .kmPerHour:
            return lang == .ja ? "時速 (km/h)" : "时速 (km/h)"
        case .minPerMile:
            return lang == .ja ? "分:秒/mi (マイル)" : "分:秒/英里 (min/mi)"
        }
    }

    func unitSuffix(lang: AppLanguage) -> String {
        switch self {
        case .minPerKm: return "/km"
        case .kmPerHour: return "km/h"
        case .minPerMile: return "/mi"
        }
    }
}

enum DistanceUnit: String, CaseIterable, Identifiable, Codable {
    case km = "km"
    case miles = "miles"

    var id: String { rawValue }

    func label(lang: AppLanguage) -> String {
        switch self {
        case .km: return lang == .ja ? "キロメートル (km)" : "公里 (km)"
        case .miles: return lang == .ja ? "マイル (mi)" : "英里 (mi)"
        }
    }
}

enum TemperatureUnit: String, CaseIterable, Identifiable, Codable {
    case celsius = "celsius"
    case fahrenheit = "fahrenheit"

    var id: String { rawValue }

    func label(lang: AppLanguage) -> String {
        switch self {
        case .celsius: return lang == .ja ? "摂氏 (°C)" : "摄氏度 (°C)"
        case .fahrenheit: return lang == .ja ? "華氏 (°F)" : "华氏度 (°F)"
        }
    }
}

enum ElevationUnit: String, CaseIterable, Identifiable, Codable {
    case meters = "meters"
    case feet = "feet"

    var id: String { rawValue }

    func label(lang: AppLanguage) -> String {
        switch self {
        case .meters: return lang == .ja ? "メートル (m)" : "米 (m)"
        case .feet: return lang == .ja ? "フィート (ft)" : "英尺 (ft)"
        }
    }
}

enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case zhHans = "zh_Hans"
    case ja = "ja"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .zhHans: return "简体中文"
        case .ja: return "日本語"
        }
    }
}

enum AIProvider: String, CaseIterable, Identifiable, Codable {
    case deepseek = "deepseek"
    case gemini = "gemini"

    var id: String { rawValue }

    func label(lang: AppLanguage) -> String {
        switch self {
        case .deepseek: return "DeepSeek (深度求索)"
        case .gemini: return "Google Gemini"
        }
    }
}

enum MapProvider: String, CaseIterable, Identifiable, Codable {
    case auto = "auto"
    case amap = "amap"
    case google = "google"
    case apple = "apple"

    var id: String { rawValue }

    func label(lang: AppLanguage) -> String {
        switch self {
        case .auto:
            return lang == .ja ? "スマート自動選択 (国内高徳・海外Google)" : "智能自动选择 (国内高德 · 海外谷歌)"
        case .amap:
            return lang == .ja ? "高徳地図 (AutoNavi / 国内推奨)" : "高德地图 (AutoNavi / 国内推荐)"
        case .google:
            return lang == .ja ? "Google マップ (Google Maps / 海外推奨)" : "谷歌地图 (Google Maps / 海外跑马推荐)"
        case .apple:
            return lang == .ja ? "Apple システム地図 (Apple Maps)" : "Apple 原生地图 (Apple Maps)"
        }
    }
}

enum AppAppearance: String, CaseIterable, Identifiable, Codable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var id: String { rawValue }

    func label(lang: AppLanguage) -> String {
        switch self {
        case .system: return lang == .ja ? "システムに従う" : "跟随系统"
        case .light: return lang == .ja ? "和紙ライト (和紙白)" : "浅色模式 (和纸暖白)"
        case .dark: return lang == .ja ? "墨炭ダーク (墨炭黒)" : "深色模式 (墨炭深灰)"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@Observable
final class UserPreferences {
    static let shared = UserPreferences()

    var paceUnit: PaceUnit = .minPerKm { didSet { save() } }
    var distanceUnit: DistanceUnit = .km { didSet { save() } }
    var temperatureUnit: TemperatureUnit = .celsius { didSet { save() } }
    var elevationUnit: ElevationUnit = .meters { didSet { save() } }
    var language: AppLanguage = .zhHans { didSet { save() } }
    var appearance: AppAppearance = .system { didSet { save() } }
    var mapGCJ02Calibration: Bool = true { didSet { save() } }
    var mapProvider: MapProvider = .auto { didSet { save() } }

    // AI & LLM Preferences
    var aiProvider: AIProvider = .deepseek { didSet { save() } }

    var deepseekApiKey: String = "" { didSet { save() } }
    var deepseekBaseUrl: String = "https://api.deepseek.com" { didSet { save() } }
    var deepseekModel: String = "deepseek-chat" { didSet { save() } }
    var deepseekDiscoveredModels: [String] = ["deepseek-chat", "deepseek-reasoner"] { didSet { save() } }

    var geminiApiKey: String = "" { didSet { save() } }
    var geminiBaseUrl: String = "https://generativelanguage.googleapis.com" { didSet { save() } }
    var geminiModel: String = "gemini-2.5-flash" { didSet { save() } }
    var geminiDiscoveredModels: [String] = ["gemini-2.5-flash", "gemini-2.5-pro"] { didSet { save() } }

    private let defaults = UserDefaults.standard
    private let key = "KazeRun_UserPreferences"

    init() {
        if let data = defaults.data(forKey: key),
           let saved = try? JSONDecoder().decode(SavedPrefs.self, from: data) {
            self.paceUnit = saved.paceUnit
            self.distanceUnit = saved.distanceUnit
            self.temperatureUnit = saved.temperatureUnit
            self.elevationUnit = saved.elevationUnit
            self.language = saved.language
            self.appearance = saved.appearance
            self.mapGCJ02Calibration = saved.mapGCJ02Calibration
            self.mapProvider = saved.mapProvider ?? .auto
            self.aiProvider = saved.aiProvider ?? .deepseek
            self.deepseekApiKey = saved.deepseekApiKey ?? ""
            self.deepseekBaseUrl = saved.deepseekBaseUrl ?? "https://api.deepseek.com"
            self.deepseekModel = saved.deepseekModel ?? "deepseek-chat"
            self.deepseekDiscoveredModels = saved.deepseekDiscoveredModels ?? ["deepseek-chat", "deepseek-reasoner"]
            self.geminiApiKey = saved.geminiApiKey ?? ""
            self.geminiBaseUrl = saved.geminiBaseUrl ?? "https://generativelanguage.googleapis.com"
            self.geminiModel = saved.geminiModel ?? "gemini-2.5-flash"
            self.geminiDiscoveredModels = saved.geminiDiscoveredModels ?? ["gemini-2.5-flash", "gemini-2.5-pro"]
        }
    }

    private struct SavedPrefs: Codable {
        let paceUnit: PaceUnit
        let distanceUnit: DistanceUnit
        let temperatureUnit: TemperatureUnit
        let elevationUnit: ElevationUnit
        let language: AppLanguage
        let appearance: AppAppearance
        let mapGCJ02Calibration: Bool
        let mapProvider: MapProvider?
        let aiProvider: AIProvider?
        let deepseekApiKey: String?
        let deepseekBaseUrl: String?
        let deepseekModel: String?
        let deepseekDiscoveredModels: [String]?
        let geminiApiKey: String?
        let geminiBaseUrl: String?
        let geminiModel: String?
        let geminiDiscoveredModels: [String]?
    }

    private func save() {
        let saved = SavedPrefs(
            paceUnit: paceUnit,
            distanceUnit: distanceUnit,
            temperatureUnit: temperatureUnit,
            elevationUnit: elevationUnit,
            language: language,
            appearance: appearance,
            mapGCJ02Calibration: mapGCJ02Calibration,
            mapProvider: mapProvider,
            aiProvider: aiProvider,
            deepseekApiKey: deepseekApiKey,
            deepseekBaseUrl: deepseekBaseUrl,
            deepseekModel: deepseekModel,
            deepseekDiscoveredModels: deepseekDiscoveredModels,
            geminiApiKey: geminiApiKey,
            geminiBaseUrl: geminiBaseUrl,
            geminiModel: geminiModel,
            geminiDiscoveredModels: geminiDiscoveredModels
        )
        if let data = try? JSONEncoder().encode(saved) {
            defaults.set(data, forKey: key)
        }
    }

    // MARK: - Formatters

    func formatDistance(meters: Double?) -> String {
        guard let m = meters, m.isFinite else { return "--" }
        switch distanceUnit {
        case .km:
            return String(format: "%.2f", m / 1000.0)
        case .miles:
            return String(format: "%.2f", (m / 1000.0) * 0.621371)
        }
    }

    func distanceUnitSuffix() -> String {
        distanceUnit == .km ? "km" : "mi"
    }

    func formatPace(secondsPerKm: Double?) -> String {
        guard let sec = secondsPerKm, sec.isFinite, sec > 0 else { return "--'--\"" }
        switch paceUnit {
        case .minPerKm:
            let total = Int(sec.rounded())
            let m = total / 60
            let s = total % 60
            return String(format: "%d'%02d\"", m, s)
        case .kmPerHour:
            let speed = 3600.0 / sec
            return String(format: "%.1f", speed)
        case .minPerMile:
            let secPerMi = sec * 1.609344
            let total = Int(secPerMi.rounded())
            let m = total / 60
            let s = total % 60
            return String(format: "%d'%02d\"", m, s)
        }
    }

    func formatPaceFromSpeedMps(_ speedMps: Double?) -> String {
        guard let sp = speedMps, sp.isFinite, sp > 0.2 else { return "--'--\"" }
        return formatPace(secondsPerKm: 1000.0 / sp)
    }

    func paceUnitSuffix() -> String {
        paceUnit.unitSuffix(lang: language)
    }

    /// Converts raw temperature from Garmin API (which is in Fahrenheit) to selected unit.
    func formatTemperature(rawGarminFahrenheit: Double?) -> String {
        guard let rawF = rawGarminFahrenheit, rawF.isFinite else { return "--" }
        switch temperatureUnit {
        case .celsius:
            let c = (rawF - 32.0) * 5.0 / 9.0
            return String(format: "%.0f°C", c)
        case .fahrenheit:
            return String(format: "%.0f°F", rawF)
        }
    }

    /// Computes dew point in Celsius using Magnus-Tetens formula from raw Garmin Fahrenheit temp and relative humidity (%).
    func calculateDewPoint(rawGarminFahrenheit: Double?, relativeHumidity: Double?) -> Double? {
        guard let f = rawGarminFahrenheit, let rh = relativeHumidity,
              f.isFinite, rh.isFinite, rh > 0, rh <= 100 else { return nil }
        let tempC = (f - 32.0) * 5.0 / 9.0
        let a = 17.27
        let b = 237.7
        let alpha = ((a * tempC) / (b + tempC)) + log(rh / 100.0)
        let dewC = (b * alpha) / (a - alpha)
        return dewC.isFinite ? dewC : nil
    }

    func formatDewPoint(rawGarminFahrenheit: Double?, relativeHumidity: Double?) -> String {
        guard let dewC = calculateDewPoint(rawGarminFahrenheit: rawGarminFahrenheit, relativeHumidity: relativeHumidity) else { return "--" }
        switch temperatureUnit {
        case .celsius:
            return String(format: "%.0f°C", dewC)
        case .fahrenheit:
            let dewF = dewC * 9.0 / 5.0 + 32.0
            return String(format: "%.0f°F", dewF)
        }
    }

    func formatElevation(meters: Double?) -> String {
        guard let m = meters, m.isFinite else { return "--" }
        switch elevationUnit {
        case .meters:
            return String(format: "%.0f m", m)
        case .feet:
            return String(format: "%.0f ft", m * 3.28084)
        }
    }
}

// MARK: - Comprehensive Sports Terminology Localizations

enum KazeI18n {
    static func recordTitle(_ raw: String, lang: AppLanguage) -> String {
        let clean = raw.trimmingCharacters(in: .whitespaces)
        switch clean {
        case "Fastest 1K":
            return lang == .ja ? "1km最速" : "最快 1 公里"
        case "Fastest Mile":
            return lang == .ja ? "1マイル最速" : "最快 1 英里"
        case "Fastest 5K":
            return lang == .ja ? "5km最速" : "最快 5 公里"
        case "Fastest 10K":
            return lang == .ja ? "10km最速" : "最快 10 公里"
        case "Fastest Half Marathon":
            return lang == .ja ? "ハーフ最速" : "最快半马"
        case "Fastest Marathon":
            return lang == .ja ? "フル最速" : "最快全马"
        case "Longest Run":
            return lang == .ja ? "最長ラン" : "最长跑步"
        case "Longest Ride":
            return lang == .ja ? "最長ライド" : "最长骑行"
        case "Most Steps Day":
            return lang == .ja ? "1日最多歩数" : "单日最高步数"
        case "Most Steps Week":
            return lang == .ja ? "週間最多歩数" : "单周最高步数"
        case "Most Steps Month":
            return lang == .ja ? "月間最多歩数" : "单月最高步数"
        case "Longest Daily Goal Streak":
            return lang == .ja ? "連続達成日数" : "最长连续达成天数"
        case "Longest Weekly Goal Streak":
            return lang == .ja ? "連続達成週数" : "最长连续达成周数"
        default:
            return clean
        }
    }

    static func trainingStatus(_ raw: String?, lang: AppLanguage) -> String {
        guard let r = raw else { return "--" }
        let clean = r.uppercased()
        if clean.contains("PRODUCTIVE") {
            return lang == .ja ? "プロダクティブ (良好)" : "高效提升"
        }
        if clean.contains("MAINTAINING") {
            return lang == .ja ? "維持 (ベース安定)" : "维持训练"
        }
        if clean.contains("RECOVERY") {
            return lang == .ja ? "リカバリー (回復期)" : "恢复期"
        }
        if clean.contains("UNPRODUCTIVE") {
            return lang == .ja ? "アンプロダクティブ (疲労)" : "低效 / 疲劳积累"
        }
        if clean.contains("PEAKING") {
            return lang == .ja ? "ピーク (最高潮)" : "巅峰状态"
        }
        if clean.contains("OVERREACHING") {
            return lang == .ja ? "オーバーリーチ (過負荷)" : "过度训练"
        }
        if clean.contains("DETRAINING") {
            return lang == .ja ? "ディトレーニング" : "停训衰退"
        }
        return r
    }

    static func loadBalanceFeedback(_ raw: String?, lang: AppLanguage) -> String {
        guard let r = raw else { return "" }
        let clean = r.uppercased()
        if clean.contains("ANAEROBIC_SHORTAGE") {
            return lang == .ja ? "無酸素不足" : "无氧负荷不足"
        }
        if clean.contains("AEROBIC_LOW_SHORTAGE") {
            return lang == .ja ? "低有酸素不足" : "低有氧基础不足"
        }
        if clean.contains("AEROBIC_HIGH_SHORTAGE") {
            return lang == .ja ? "高有酸素不足" : "高有氧刺激不足"
        }
        if clean.contains("OPTIMAL") || clean.contains("BALANCED") {
            return lang == .ja ? "最適バランス" : "负荷均衡"
        }
        return r
    }

    static func hrMethod(_ raw: String?, lang: AppLanguage) -> String {
        guard let r = raw else { return "" }
        let clean = r.uppercased()
        if clean.contains("HR_RESERVE") {
            return lang == .ja ? "予備心拍法 (HRR)" : "心率储备法 (HRR)"
        }
        if clean.contains("MAX_HR") {
            return lang == .ja ? "最大心拍数法" : "最大心率法"
        }
        if clean.contains("LACTATE") {
            return lang == .ja ? "乳酸閾値法" : "乳酸阈值法"
        }
        return r
    }

    static func hrvStatus(_ raw: String?, lang: AppLanguage) -> String {
        guard let r = raw else { return "--" }
        let clean = r.uppercased()
        if clean.contains("BALANCED") && !clean.contains("UNBALANCED") {
            return lang == .ja ? "バランス" : "状态均衡"
        }
        if clean.contains("UNBALANCED") {
            return lang == .ja ? "アンバランス" : "状态不均衡"
        }
        if clean.contains("LOW") {
            return lang == .ja ? "低下" : "偏低"
        }
        if clean.contains("POOR") {
            return lang == .ja ? "不十分" : "恢复欠佳"
        }
        return r
    }

    static func activityType(_ raw: String?, lang: AppLanguage) -> String {
        guard let r = raw else { return "" }
        let clean = r.lowercased()
        if clean.contains("track_running") {
            return lang == .ja ? "トラック走" : "操场跑"
        }
        if clean.contains("trail_running") {
            return lang == .ja ? "トレイル" : "越野跑"
        }
        if clean.contains("running") {
            return lang == .ja ? "ランニング" : "跑步"
        }
        if clean.contains("treadmill") {
            return lang == .ja ? "トレッドミル" : "跑步机"
        }
        if clean.contains("strength") {
            return lang == .ja ? "筋力トレ" : "力量训练"
        }
        if clean.contains("cardio") {
            return lang == .ja ? "有酸素" : "有氧运动"
        }
        if clean.contains("cycling") {
            return lang == .ja ? "サイクリング" : "骑行"
        }
        if clean.contains("walking") {
            return lang == .ja ? "ウォーキング" : "健走"
        }
        return r
    }

    static func weatherCondition(_ raw: String?, lang: AppLanguage) -> (title: String, icon: String) {
        guard let r = raw?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines), !r.isEmpty else {
            return (lang == .ja ? "記録なし" : "暂无", "cloud")
        }
        if r.contains("thunder") || r.contains("storm") {
            return (lang == .ja ? "雷雨" : "雷阵雨", "cloud.bolt.rain.fill")
        }
        if r.contains("heavy rain") || r.contains("downpour") {
            return (lang == .ja ? "大雨" : "大雨", "cloud.heavyrain.fill")
        }
        if r.contains("rain") || r.contains("shower") || r.contains("drizzle") {
            return (lang == .ja ? "雨" : "小雨", "cloud.rain.fill")
        }
        if r.contains("snow") || r.contains("flurr") || r.contains("blizzard") {
            return (lang == .ja ? "雪" : "下雪", "snowflake")
        }
        if r.contains("fog") || r.contains("mist") || r.contains("haze") {
            return (lang == .ja ? "霧" : "薄雾", "cloud.fog.fill")
        }
        if r.contains("partly cloudy") || r.contains("scattered") {
            return (lang == .ja ? "晴れ時々曇" : "多云", "cloud.sun.fill")
        }
        if r.contains("mostly cloudy") || r.contains("broken") {
            return (lang == .ja ? "曇り" : "多云", "cloud.fill")
        }
        if r.contains("overcast") || r.contains("cloud") {
            return (lang == .ja ? "曇天" : "阴天", "cloud.fill")
        }
        if r.contains("clear") || r.contains("sunny") || r.contains("fair") {
            return (lang == .ja ? "快晴" : "晴朗", "sun.max.fill")
        }
        if r.contains("wind") || r.contains("breez") {
            return (lang == .ja ? "強風" : "大风", "wind")
        }
        return (raw ?? (lang == .ja ? "不明" : "未知"), "cloud.sun.fill")
    }
}
