import Charts
import MapKit
import SwiftUI

enum TelemetryMetric: String, CaseIterable, Identifiable {
    case pace = "配速"
    case hr = "心率"
    case cadence = "步频"
    case elevation = "海拔"
    case power = "功率"

    var id: String { rawValue }

    func localized(lang: AppLanguage) -> String {
        switch self {
        case .pace: return lang == .ja ? "ペース" : "配速"
        case .hr: return lang == .ja ? "心拍数" : "心率"
        case .cadence: return lang == .ja ? "ピッチ" : "步频"
        case .elevation: return lang == .ja ? "高度" : "海拔"
        case .power: return lang == .ja ? "パワー" : "功率"
        }
    }
}

struct ActivitiesView: View {
    @Environment(AppState.self) private var appState

    @State private var searchText: String = ""
    @State private var typeFilter: String = "all"
    @State private var selectedMetric: TelemetryMetric = .pace
    @State private var hoveredTime: Double?
    @State private var isListCollapsed: Bool = false

    private var filteredActivities: [ActivityItem] {
        appState.activities.filter { act in
            let matchesType: Bool
            switch typeFilter {
            case "running":
                matchesType = (act.type ?? "").contains("running")
            case "strength":
                matchesType = (act.type ?? "").contains("strength")
            case "other":
                matchesType = !(act.type ?? "").contains("running") && !(act.type ?? "").contains("strength")
            default:
                matchesType = true
            }
            if !matchesType { return false }
            if searchText.trimmingCharacters(in: .whitespaces).isEmpty { return true }
            return (act.name ?? "").localizedCaseInsensitiveContains(searchText)
                || (act.startTime ?? "").localizedCaseInsensitiveContains(searchText)
                || String(act.id).contains(searchText)
        }
    }

    var body: some View {
        HSplitView {
            if !isListCollapsed {
                activityListPane
                    .frame(minWidth: 280, idealWidth: 320, maxWidth: 380)
            }

            activityDetailPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(KazeTheme.canvas)
    }

    private var activityListPane: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                TextField(appState.prefs.language == .ja ? "名前 / 日付 / ID で検索" : "搜索名称 / 日期 / ID", text: $searchText)
                    .textFieldStyle(.roundedBorder)

                Picker("类型", selection: $typeFilter) {
                    Text(appState.prefs.language == .ja ? "すべて" : "全部").tag("all")
                    Text(appState.prefs.language == .ja ? "ラン" : "跑步").tag("running")
                    Text(appState.prefs.language == .ja ? "筋トレ" : "力量").tag("strength")
                    Text(appState.prefs.language == .ja ? "その他" : "其他").tag("other")
                }
                .pickerStyle(.segmented)
            }
            .padding(12)
            .background(KazeTheme.surface)

            Divider()

            List(selection: Binding(
                get: { appState.selectedActivityId },
                set: { newId in
                    if let newId {
                        Task { await appState.selectActivity(id: newId, forceRefresh: false) }
                    }
                }
            )) {
                ForEach(filteredActivities) { act in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(act.name ?? "活动 #\(act.id)")
                                .font(.system(size: 13, weight: .semibold))
                                .lineLimit(1)
                            Spacer()
                            Text(KazeI18n.activityType(act.type, lang: appState.prefs.language))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        HStack(spacing: 8) {
                            Text(act.shortDate)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer()
                            if let d = act.distanceMeters, d > 0 {
                                Text("\(appState.prefs.formatDistance(meters: d)) \(appState.prefs.distanceUnitSuffix())")
                                    .foregroundStyle(KazeTheme.vermilion)
                                    .lineLimit(1)
                                    .fixedSize()
                            }
                            Text(KazeFormat.duration(act.durationSeconds))
                                .lineLimit(1)
                                .fixedSize()
                            if let hr = act.avgHrBpm {
                                Text("\(Int(hr)) bpm")
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .fixedSize()
                            }
                        }
                        .font(.system(size: 11, design: .monospaced))
                    }
                    .padding(.vertical, 4)
                    .tag(act.id)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            isListCollapsed = true
                        }
                    }
                }

                if appState.hasMoreActivities {
                    HStack {
                        Spacer()
                        Button(appState.isLoadingActivities ? (appState.prefs.language == .ja ? "読み込み中..." : "加载中...") : (appState.prefs.language == .ja ? "さらに読み込む" : "加载更多历史活动")) {
                            Task { await appState.loadActivities(reset: false) }
                        }
                        .buttonStyle(.bordered)
                        .disabled(appState.isLoadingActivities)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            }
            .listStyle(.inset)
        }
    }

    @ViewBuilder
    private var activityDetailPane: some View {
        if let selectedId = appState.selectedActivityId,
           let item = appState.activities.first(where: { $0.id == selectedId }) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    activityHeader(item: item, bundle: appState.currentBundle)

                    if appState.isLoadingBundle {
                        KazeCard {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text(appState.prefs.language == .ja ? "GPS軌跡とテレメトリ曲線を読み込み中..." : "正在加载圈段、GPS轨迹与20k采样时序曲线...")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else if let bundle = appState.currentBundle, bundle.activityId == selectedId {
                        if !bundle.polyline.isEmpty {
                            routeMapCard(
                                polyline: bundle.polyline,
                                hoveredCoordinate: computeHoveredCoordinate(bundle: bundle)
                            )
                        }
                        if !bundle.telemetryPoints.isEmpty {
                            telemetryChartCard(points: bundle.telemetryPoints)
                            sportsScienceDiagnosticsCard(points: bundle.telemetryPoints)
                            aiDebriefCard(activity: item, bundle: bundle, analysis: computeSportsScience(points: bundle.telemetryPoints))
                        }
                        HStack(alignment: .top, spacing: 14) {
                            hrZonesCard(zones: bundle.hrZones ?? [])
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            gearAndWeatherCard(bundle: bundle, activityId: selectedId)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        splitsTableCard(laps: bundle.splits?.lapDTOs ?? [])
                    } else {
                        KazeCard {
                            Button(appState.prefs.language == .ja ? "詳細データとラップを読み込む" : "加载详细曲线与圈段") {
                                Task { await appState.selectActivity(id: selectedId, forceRefresh: true) }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(KazeTheme.vermilion)
                        }
                    }
                }
                .padding(18)
            }
        } else {
            ContentUnavailableView(
                appState.prefs.language == .ja ? "アクティビティを選択" : "选择一条运动记录",
                systemImage: "figure.run",
                description: Text(appState.prefs.language == .ja ? "左のリストからランニングまたは筋トレ記録を選択してください。" : "从左侧列表选择任意跑步或力量记录，查看地图轨迹、心率/配速曲线与圈段详情。")
            )
        }
    }

    private func activityHeader(item: ActivityItem, bundle: ActivityDetailBundle?) -> some View {
        let dto = bundle?.activityId == item.id ? bundle?.summary?.summaryDTO : nil
        return KazeCard {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ID \(item.id) · \(item.shortDate)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text(item.name ?? "活动")
                        .font(.system(size: 20, weight: .bold))
                }
                Spacer()
                HStack(spacing: 8) {
                    Button {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            isListCollapsed.toggle()
                        }
                    } label: {
                        Label(
                            isListCollapsed
                                ? (appState.prefs.language == .ja ? "リスト表示" : "展开列表")
                                : (appState.prefs.language == .ja ? "全画面" : "宽屏沉浸"),
                            systemImage: isListCollapsed ? "sidebar.left" : "arrow.up.left.and.arrow.down.right"
                        )
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut("b", modifiers: .command)
                    .help(isListCollapsed ? (appState.prefs.language == .ja ? "リストを展開 (⌘B)" : "展开跑步列表 (⌘B)") : (appState.prefs.language == .ja ? "リストを非表示にして全画面表示 (⌘B)" : "收起列表，全宽沉浸查看详情 (⌘B)"))

                    Button {
                        Task { _ = await appState.downloadFIT(activityId: item.id) }
                    } label: {
                        Label(appState.prefs.language == .ja ? "FIT生データ出力" : "导出原始 FIT", systemImage: "arrow.down.doc")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        triggerAIDebrief(item: item, bundle: bundle)
                    } label: {
                        if appState.isGeneratingAIDebrief {
                            HStack(spacing: 5) {
                                ProgressView()
                                    .controlSize(.small)
                                Text(appState.prefs.language == .ja ? "分析中..." : "AI 复盘中...")
                            }
                        } else {
                            Label(
                                appState.aiDebriefCache[item.id] != nil
                                    ? (appState.prefs.language == .ja ? "AI コーチ再分析" : "AI 重新复盘")
                                    : (appState.prefs.language == .ja ? "AI コーチ分析" : "AI 跑步复盘"),
                                systemImage: "sparkles"
                            )
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(KazeTheme.vermilion)
                    .disabled(appState.isGeneratingAIDebrief)
                    .help(appState.prefs.language == .ja ? "現在のテレメトリと有酸素デカップリングに基づくAIコーチレビュー" : "基于本场 20k 采样、有氧脱钩与步频稳态生成教练复盘")

                    Button {
                        Task { await appState.selectActivity(id: item.id, forceRefresh: true) }
                    } label: {
                        Label(appState.prefs.language == .ja ? "更新" : "刷新", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                }
            }

            Divider()

            // Horizontal scrolling bar to prevent any number wrap / truncation!
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    KazeMetricBadge(
                        label: appState.prefs.language == .ja ? "距離" : "距离",
                        value: appState.prefs.formatDistance(meters: dto?.distance ?? item.distanceMeters),
                        unit: appState.prefs.distanceUnitSuffix(),
                        tone: KazeTheme.vermilion
                    )
                    KazeMetricBadge(
                        label: appState.prefs.language == .ja ? "タイム" : "总用时",
                        value: KazeFormat.duration(dto?.duration ?? item.durationSeconds)
                    )
                    KazeMetricBadge(
                        label: appState.prefs.language == .ja ? "平均ペース" : "平均配速",
                        value: appState.prefs.formatPace(secondsPerKm: item.avgPaceSecPerKm),
                        unit: appState.prefs.paceUnitSuffix()
                    )
                    KazeMetricBadge(
                        label: appState.prefs.language == .ja ? "平均心拍" : "平均心率",
                        value: KazeFormat.integer(dto?.averageHR ?? item.avgHrBpm),
                        unit: "bpm"
                    )
                    KazeMetricBadge(
                        label: appState.prefs.language == .ja ? "最大心拍" : "最高心率",
                        value: KazeFormat.integer(dto?.maxHR ?? item.maxHrBpm),
                        unit: "bpm"
                    )
                    KazeMetricBadge(
                        label: appState.prefs.language == .ja ? "平均ピッチ" : "平均步频",
                        value: KazeFormat.integer(dto?.averageRunCadence),
                        unit: "spm"
                    )
                    KazeMetricBadge(
                        label: appState.prefs.language == .ja ? "有酸素TE" : "有氧 TE",
                        value: dto?.trainingEffect.map { String(format: "%.1f", $0) } ?? "--"
                    )
                    KazeMetricBadge(
                        label: appState.prefs.language == .ja ? "負荷" : "负荷",
                        value: dto?.activityTrainingLoad.map { String(format: "%.0f", $0) } ?? "--"
                    )
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func computeHoveredCoordinate(bundle: ActivityDetailBundle) -> CLLocationCoordinate2D? {
        guard let hoveredTime else { return nil }
        // 1. Direct match with telemetry point that has GPS fix
        if let pt = bundle.telemetryPoints.min(by: { abs($0.t - hoveredTime) < abs($1.t - hoveredTime) }),
           let lat = pt.lat, let lon = pt.lon {
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        // 2. Proportional interpolation along polyline
        guard !bundle.polyline.isEmpty else { return nil }
        let maxT = bundle.telemetryPoints.last?.t ?? bundle.summary?.summaryDTO?.duration ?? 1.0
        guard maxT > 0 else { return nil }
        let ratio = max(0.0, min(1.0, hoveredTime / maxT))
        let idx = Int(ratio * Double(bundle.polyline.count - 1))
        let pair = bundle.polyline[idx]
        if pair.count >= 2 {
            return CLLocationCoordinate2D(latitude: pair[0], longitude: pair[1])
        }
        return nil
    }

    private func routeMapCard(polyline: [[Double]], hoveredCoordinate: CLLocationCoordinate2D? = nil) -> some View {
        let sample = polyline.first ?? [0.0, 0.0]
        let isOverseas = CoordinateTransform.isOutOfChina(lat: sample[0], lon: sample[1])
        let mapName: String = {
            switch appState.prefs.mapProvider {
            case .auto:
                return isOverseas ? (appState.prefs.language == .ja ? "Google マップ (海外)" : "Google Maps (海外)") : (appState.prefs.language == .ja ? "高徳地図 (国内)" : "高德地图 (国内)")
            case .amap:
                return appState.prefs.language == .ja ? "高徳地図" : "高德地图"
            case .google:
                return "Google Maps"
            case .apple:
                return "Apple Maps"
            }
        }()

        return KazeCard {
            HStack {
                KazeSectionHeader(
                    jpTag: "ROUTE",
                    title: appState.prefs.language == .ja ? "GPS 走行軌跡" : "GPS 运动轨迹",
                    subtitle: nil
                )
                Spacer()
                Text(mapName)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(Capsule())
            }

            KazeMapView(
                polyline: polyline,
                hoveredCoordinate: hoveredCoordinate,
                provider: appState.prefs.mapProvider,
                calibrateGcj02: appState.prefs.mapGCJ02Calibration
            )
            .frame(height: 250)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func telemetryChartCard(points: [TelemetryPoint]) -> some View {
        let maxMinutes = max(1.0, (points.last?.t ?? 60.0) / 60.0)
        let hoveredPoint = hoveredTime.flatMap { t in
            points.min(by: { abs($0.t - t) < abs($1.t - t) })
        }

        return KazeCard {
            HStack {
                KazeSectionHeader(
                    jpTag: "TELEMETRY",
                    title: appState.prefs.language == .ja ? "テレメトリ曲線分析" : "时序曲线分析"
                )
                Picker("指标", selection: $selectedMetric) {
                    ForEach(TelemetryMetric.allCases) { m in
                        Text(m.localized(lang: appState.prefs.language)).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 320)
            }

            // Rich Hover Tooltip Bar
            HStack(spacing: 16) {
                if let pt = hoveredPoint {
                    Text("⏱️ \(KazeFormat.duration(pt.t))")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    if let d = pt.dist {
                        Text("📍 \(appState.prefs.formatDistance(meters: d)) \(appState.prefs.distanceUnitSuffix())")
                            .font(.system(size: 11, design: .monospaced))
                    }
                    if let p = pt.pace {
                        let paceText = p > 720 ? (appState.prefs.language == .ja ? "歩行/停止" : "慢走/停顿") : "\(appState.prefs.formatPace(secondsPerKm: p))\(appState.prefs.paceUnitSuffix())"
                        Text("⚡️ \(paceText)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(KazeTheme.indigo)
                    }
                    if let hr = pt.hr {
                        Text("❤️ \(Int(hr)) bpm")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(KazeTheme.vermilion)
                    }
                    if let cad = pt.cadence {
                        Text("👟 \(Int(cad)) spm")
                            .font(.system(size: 11, design: .monospaced))
                    }
                    if let el = pt.elev {
                        Text("⛰️ \(appState.prefs.formatElevation(meters: el))")
                            .font(.system(size: 11, design: .monospaced))
                    }
                } else {
                    Text(appState.prefs.language == .ja ? "マウスを曲線上に合わせると各地点の数値が表示されます" : "鼠标在图表上移动可实时查看该位置详细配速、心率与距离信息")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(KazeTheme.surfaceSubtle)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            Chart {
                ForEach(points) { pt in
                    if let y = metricValue(pt) {
                        LineMark(
                            x: .value("时间(分)", pt.t / 60.0),
                            y: .value(selectedMetric.localized(lang: appState.prefs.language), y)
                        )
                        .foregroundStyle(metricColor)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                }
                if let pt = hoveredPoint {
                    RuleMark(x: .value("时间(分)", pt.t / 60.0))
                        .foregroundStyle(KazeTheme.vermilion.opacity(0.8))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))

                    if let y = metricValue(pt) {
                        PointMark(
                            x: .value("时间(分)", pt.t / 60.0),
                            y: .value(selectedMetric.localized(lang: appState.prefs.language), y)
                        )
                        .foregroundStyle(KazeTheme.vermilion)
                        .symbolSize(42)
                    }
                }
            }
            .chartXScale(domain: 0 ... maxMinutes) // 铺满整个图表宽度，右侧绝不留白断开！
            .chartXAxisLabel(appState.prefs.language == .ja ? "時間 (分)" : "时间 (分钟)")
            .chartYScale(domain: yAxisDomain(points))
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let d = value.as(Double.self) {
                            Text(formatAxisLabel(d))
                                .font(.system(size: 10, design: .monospaced))
                        }
                    }
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let loc):
                                if let minutes: Double = proxy.value(atX: loc.x) {
                                    hoveredTime = minutes * 60.0
                                }
                            case .ended:
                                hoveredTime = nil
                            }
                        }
                }
            }
            .frame(height: 220)
            .clipped() // 严格限制在图表绘图区内，绝对不冲破上方信息条
        }
    }

    private func metricValue(_ pt: TelemetryPoint) -> Double? {
        switch selectedMetric {
        case .pace:
            guard let paceSec = pt.pace else { return nil }
            switch appState.prefs.paceUnit {
            case .minPerKm:
                // Smoothly clamp extreme outliers (walking/stops > 11:00/km) so normal running waveform stays clean
                let clamped = min(660.0, max(150.0, paceSec))
                // Invert (negate) so that faster pace (smaller seconds) is positioned higher on the Y axis!
                return -clamped
            case .kmPerHour:
                return paceSec > 0 ? min(24.0, 3600.0 / paceSec) : nil
            case .minPerMile:
                let clamped = min(660.0 * 1.609344, max(150.0 * 1.609344, paceSec * 1.609344))
                return -clamped
            }
        case .hr: return pt.hr
        case .cadence: return pt.cadence
        case .elevation:
            guard let el = pt.elev else { return nil }
            return appState.prefs.elevationUnit == .meters ? el : (el * 3.28084)
        case .power: return pt.power
        }
    }

    private func yAxisDomain(_ points: [TelemetryPoint]) -> ClosedRange<Double> {
        let vals = points.compactMap { metricValue($0) }
        guard !vals.isEmpty else { return 0...100 }
        let minVal = vals.min()!
        let maxVal = vals.max()!

        if selectedMetric == .pace && appState.prefs.paceUnit != .kmPerHour {
            // vals are negative (e.g. -660 ... -150)
            // minVal is -660 (slowest/bottom), maxVal is -150 (fastest/top)
            let lower = floor(minVal / 30.0) * 30.0
            let upper = ceil(maxVal / 30.0) * 30.0
            return lower ... max(lower + 60.0, upper)
        }
        let padding = max(1.0, (maxVal - minVal) * 0.1)
        return (minVal - padding)...(maxVal + padding)
    }

    private func formatAxisLabel(_ value: Double) -> String {
        switch selectedMetric {
        case .pace:
            if appState.prefs.paceUnit == .kmPerHour {
                return String(format: "%.1f", value)
            }
            let total = Int(abs(value).rounded())
            let m = total / 60
            let s = total % 60
            return String(format: "%d'%02d\"", m, s)
        case .hr, .cadence, .power:
            return String(Int(value.rounded()))
        case .elevation:
            return String(format: "%.0f", value)
        }
    }

    private var metricColor: Color {
        switch selectedMetric {
        case .pace: return KazeTheme.indigo
        case .hr: return KazeTheme.vermilion
        case .cadence: return KazeTheme.sage
        case .elevation: return KazeTheme.amber
        case .power: return .purple
        }
    }

    private struct SportsScienceAnalysis {
        let decouplingPercent: Double
        let paceCV: Double
        let cadenceStability: Double
        let half1PaceSec: Double
        let half1HR: Double
        let half2PaceSec: Double
        let half2HR: Double

        var decouplingFormatted: String {
            String(format: "%@%.1f%%", decouplingPercent > 0 ? "+" : "", decouplingPercent)
        }

        var decouplingTone: Color {
            if decouplingPercent <= 3.5 { return KazeTheme.sage }
            if decouplingPercent <= 5.0 { return KazeTheme.indigo }
            return KazeTheme.amber
        }

        func decouplingStatus(isJa: Bool) -> String {
            if decouplingPercent < 0.0 {
                return isJa ? "負のデカップリング (後半効率向上)" : "负脱钩 (后半程效率提升)"
            } else if decouplingPercent <= 3.5 {
                return isJa ? "極めて良好な有酸素安定性 (<3.5%)" : "极佳有氧稳态 (<3.5%)"
            } else if decouplingPercent <= 5.0 {
                return isJa ? "良好な有酸素持久力 (3.5%~5%)" : "良好稳态 (微幅漂移)"
            } else {
                return isJa ? "顕著な有酸素デカップリング (>5%)" : "显著有氧脱钩 (>5%)"
            }
        }

        func decouplingBrief(isJa: Bool) -> String {
            if decouplingPercent < 0.0 {
                return isJa ? "後半の出力効率が前半を上回り、良好なネガティブスプリットを実現。" : "后半程单位心率输出速度更高，呈现优秀负分割或充分热身开跑。"
            } else if decouplingPercent <= 3.5 {
                return isJa ? "心拍とペース比率がほぼ一定。線粒体と心血管の有酸素基礎が強固。" : "后半程心率与配速比值几乎恒定，有氧心血管与耐力基础扎实。"
            } else if decouplingPercent <= 5.0 {
                return isJa ? "生理学許容範囲内の自然ドリフト。エネルギー代謝制御は良好。" : "心血管漂移在 5% 黄金生理红线以内，配速与能量代谢控制良好。"
            } else {
                return isJa ? "後半の単位心拍あたり出力が低下。脱水・体温上昇または持久力低下に注意。" : "后半程单位心率输出速度下降，提示耐力衰竭、体温上升或排汗脱水。"
            }
        }

        var paceCVTone: Color {
            if paceCV < 4.0 { return KazeTheme.sage }
            if paceCV <= 8.0 { return KazeTheme.indigo }
            return KazeTheme.amber
        }

        func paceCVStatus(isJa: Bool) -> String {
            if paceCV < 4.0 {
                return isJa ? "メトロノーム級 (CV <4%)" : "节拍器级匀速 (CV <4%)"
            } else if paceCV <= 8.0 {
                return isJa ? "安定したペース配分 (4%~8%)" : "平稳节奏把控 (4%~8%)"
            } else {
                return isJa ? "起伏・加減速大 (CV >8%)" : "起伏变速较大 (CV >8%)"
            }
        }

        func paceCVBrief(isJa: Bool) -> String {
            if paceCV < 4.0 {
                return isJa ? "ペースの揺らぎが極めて少なく、卓越した巡航リズムを維持。" : "全程配速波动极微，展现出卓越的匀速巡航控制与体能分配纪律。"
            } else if paceCV <= 8.0 {
                return isJa ? "安定した巡航帯を維持し、起伏や気象に柔軟に適応。" : "配速维持在稳定波段，兼顾微幅起伏地形与体能平稳输出。"
            } else {
                return isJa ? "ペースの上下動大。インターバル、越野または加減速が頻発。" : "速度波动明显，通常对应间歇变速跑、越野起伏或后半程撞墙减速。"
            }
        }

        var cadenceTone: Color {
            if cadenceStability >= 80.0 { return KazeTheme.sage }
            if cadenceStability >= 60.0 { return KazeTheme.indigo }
            return KazeTheme.amber
        }

        func cadenceStatus(isJa: Bool) -> String {
            if cadenceStability >= 80.0 {
                return isJa ? "高ピッチ安定度 (≥80%)" : "高专注步频稳态 (≥80%)"
            } else if cadenceStability >= 60.0 {
                return isJa ? "適度なピッチ制御 (60%~80%)" : "平稳步频输出 (60%~80%)"
            } else {
                return isJa ? "動的ピッチ適応 (<60%)" : "动态步频调节 (<60%)"
            }
        }

        func cadenceBrief(isJa: Bool) -> String {
            if cadenceStability >= 80.0 {
                return isJa ? "神経筋の出力連動が強固で、ランニングエコノミーが高い状態。" : "中枢神经对步频记忆稳固，动力链输出连贯协调，跑步经济性极高。"
            } else {
                return isJa ? "地形やペース変化に応じてピッチを柔軟に微調整。" : "步频随配速、坡度或体能状态发生较多自适应调节。"
            }
        }
    }

    private func computeSportsScience(points: [TelemetryPoint]) -> SportsScienceAnalysis? {
        let valid = points.filter { pt in
            guard let hr = pt.hr, hr >= 90,
                  let spd = pt.speed, spd >= 1.2,
                  let pace = pt.pace, pace >= 150, pace <= 720 else { return false }
            return true
        }
        guard valid.count >= 60 else { return nil }

        let halfCount = valid.count / 2
        let half1 = valid[..<halfCount]
        let half2 = valid[halfCount...]

        let ef1List = half1.compactMap { pt -> Double? in
            guard let spd = pt.speed, let hr = pt.hr, hr > 0 else { return nil }
            return spd / hr
        }
        let ef2List = half2.compactMap { pt -> Double? in
            guard let spd = pt.speed, let hr = pt.hr, hr > 0 else { return nil }
            return spd / hr
        }
        guard !ef1List.isEmpty, !ef2List.isEmpty else { return nil }

        let avgEf1 = ef1List.reduce(0.0, +) / Double(ef1List.count)
        let avgEf2 = ef2List.reduce(0.0, +) / Double(ef2List.count)
        guard avgEf1 > 0 else { return nil }

        let decoupling = ((avgEf1 - avgEf2) / avgEf1) * 100.0

        let paces = valid.compactMap(\.pace)
        let meanPace = paces.reduce(0.0, +) / Double(paces.count)
        let variance = paces.map { pow($0 - meanPace, 2) }.reduce(0.0, +) / Double(paces.count)
        let stdDev = sqrt(variance)
        let cv = (stdDev / meanPace) * 100.0

        let cadences = valid.compactMap(\.cadence).filter { $0 >= 120 }
        let stability: Double
        if !cadences.isEmpty {
            let meanCad = cadences.reduce(0.0, +) / Double(cadences.count)
            let inRange = cadences.filter { abs($0 - meanCad) <= 3.0 }.count
            stability = (Double(inRange) / Double(cadences.count)) * 100.0
        } else {
            stability = 0.0
        }

        let h1Paces = half1.compactMap(\.pace)
        let h1HRs = half1.compactMap(\.hr)
        let h2Paces = half2.compactMap(\.pace)
        let h2HRs = half2.compactMap(\.hr)

        let avgH1Pace = h1Paces.reduce(0.0, +) / Double(max(1, h1Paces.count))
        let avgH1HR = h1HRs.reduce(0.0, +) / Double(max(1, h1HRs.count))
        let avgH2Pace = h2Paces.reduce(0.0, +) / Double(max(1, h2Paces.count))
        let avgH2HR = h2HRs.reduce(0.0, +) / Double(max(1, h2HRs.count))

        return SportsScienceAnalysis(
            decouplingPercent: decoupling,
            paceCV: cv,
            cadenceStability: stability,
            half1PaceSec: avgH1Pace,
            half1HR: avgH1HR,
            half2PaceSec: avgH2Pace,
            half2HR: avgH2HR
        )
    }

    @ViewBuilder
    private func sportsScienceDiagnosticsCard(points: [TelemetryPoint]) -> some View {
        if let analysis = computeSportsScience(points: points) {
            let isJa = appState.prefs.language == .ja

            KazeCard {
                HStack(alignment: .center) {
                    KazeSectionHeader(
                        jpTag: "SCIENCE",
                        title: isJa ? "運動生理学インテリジェント分析" : "运动生理学智能分析",
                        subtitle: isJa ? "前半・後半EF · 巡航離散度 · ピッチ安定性" : "前/后半程效率(EF) · 巡航离散度 · 步频稳态"
                    )
                    Spacer()
                    Text(isJa ? "20kサンプリング" : "20k 高频解算")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Capsule())
                }

                HStack(alignment: .top, spacing: 12) {
                    let h1Pace = appState.prefs.formatPace(secondsPerKm: analysis.half1PaceSec)
                    let h2Pace = appState.prefs.formatPace(secondsPerKm: analysis.half2PaceSec)
                    let h1HR = Int(analysis.half1HR)
                    let h2HR = Int(analysis.half2HR)
                    let sub1 = isJa ? "前半: \(h1Pace) (\(h1HR)bpm)" : "前半: \(h1Pace) · \(h1HR) bpm"
                    let sub2 = isJa ? "後半: \(h2Pace) (\(h2HR)bpm)" : "后半: \(h2Pace) · \(h2HR) bpm"

                    scienceMetricColumn(
                        tag: "PA:HR",
                        title: isJa ? "有酸素デカップリング" : "有氧脱钩率",
                        value: analysis.decouplingFormatted,
                        tone: analysis.decouplingTone,
                        status: analysis.decouplingStatus(isJa: isJa),
                        subMetrics: [sub1, sub2],
                        brief: analysis.decouplingBrief(isJa: isJa)
                    )

                    scienceMetricColumn(
                        tag: "PACE CV",
                        title: isJa ? "ペース変動係数" : "巡航配速离散度",
                        value: String(format: "%.1f%%", analysis.paceCV),
                        tone: analysis.paceCVTone,
                        status: analysis.paceCVStatus(isJa: isJa),
                        subMetrics: [isJa ? "標準偏差 σ/μ" : "配速标准差 / 均值 (σ/μ)"],
                        brief: analysis.paceCVBrief(isJa: isJa)
                    )

                    scienceMetricColumn(
                        tag: "CADENCE",
                        title: isJa ? "ピッチ安定度" : "核心步频专注度",
                        value: String(format: "%.0f%%", analysis.cadenceStability),
                        tone: analysis.cadenceTone,
                        status: analysis.cadenceStatus(isJa: isJa),
                        subMetrics: [isJa ? "±3 spm 最適窓" : "均频 ±3 spm 黄金窗口占比"],
                        brief: analysis.cadenceBrief(isJa: isJa)
                    )
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func scienceMetricColumn(
        tag: String,
        title: String,
        value: String,
        tone: Color,
        status: String,
        subMetrics: [String],
        brief: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Text(tag)
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(tone)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(tone.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                Text(title)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Color.primary)
            }

            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tone)

            HStack(spacing: 4) {
                Circle()
                    .fill(tone)
                    .frame(width: 4.5, height: 4.5)
                Text(status)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(tone)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .background(tone.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(tone.opacity(0.20), lineWidth: 0.8)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 2) {
                ForEach(subMetrics, id: \.self) { line in
                    Text(line)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.top, 2)

            Text(brief)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 1)

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(KazeTheme.surfaceSubtle)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(KazeTheme.hairline, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func hrZonesCard(zones: [ActivityHRZoneBucket]) -> some View {
        let totalSecs = max(1, zones.reduce(0.0) { $0 + ($1.secsInZone ?? 0) })
        let zoneColors: [Color] = [.gray, KazeTheme.indigo, KazeTheme.sage, KazeTheme.amber, KazeTheme.vermilion]
        return KazeCard {
            KazeSectionHeader(
                jpTag: "ZONES",
                title: appState.prefs.language == .ja ? "心拍ゾーン分布" : "心率区间分布"
            )
            if zones.isEmpty {
                Text(appState.prefs.language == .ja ? "心拍ゾーンデータなし" : "暂无心率区间数据").font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            } else {
                VStack(spacing: 8) {
                    ForEach(zones.sorted(by: { ($0.zoneNumber ?? 0) < ($1.zoneNumber ?? 0) })) { z in
                        let num = z.zoneNumber ?? 1
                        let secs = z.secsInZone ?? 0
                        let pct = secs / totalSecs
                        let color = zoneColors[min(max(0, num - 1), zoneColors.count - 1)]
                        HStack(spacing: 8) {
                            Text("Z\(num) (\(z.zoneLowBoundary ?? 0)+)")
                                .font(.system(size: 11, design: .monospaced))
                                .frame(width: 72, alignment: .leading)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(KazeTheme.surfaceSubtle)
                                    Capsule().fill(color).frame(width: max(2, geo.size.width * pct))
                                }
                            }
                            .frame(height: 8)
                            Text("\(KazeFormat.duration(secs)) · \(Int((pct * 100).rounded()))%")
                                .font(.system(size: 11, design: .monospaced))
                                .frame(width: 96, alignment: .trailing)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .frame(minHeight: 185)
    }

    private struct ActivityWeatherSectionView: View {
        let weather: ActivityWeatherDTO
        let prefs: UserPreferences
        @State private var isHoveringDewPoint: Bool = false
        @State private var isPinned: Bool = false

        private var isDetailVisible: Bool { isHoveringDewPoint || isPinned }

        private func conditionColor(icon: String) -> Color {
            if icon.contains("sun") { return KazeTheme.amber }
            if icon.contains("rain") { return KazeTheme.indigo }
            return KazeTheme.sage
        }

        var body: some View {
            let cond = KazeI18n.weatherCondition(weather.weatherTypeDTO?.desc, lang: prefs.language)
            let tempStr = prefs.formatTemperature(rawGarminFahrenheit: weather.temp)
            let humidityStr = weather.relativeHumidity.map { String(format: "%.0f%%", $0) } ?? "--"
            let dewPointStr = prefs.formatDewPoint(rawGarminFahrenheit: weather.temp, relativeHumidity: weather.relativeHumidity)
            let windStr = weather.windSpeed.map { String(format: "%.0f km/h", $0) } ?? "--"
            let condColor = conditionColor(icon: cond.icon)
            let dewDetail = (prefs.language == .ja)
                ? "実測気温 \(tempStr) · 相対湿度 \(humidityStr)"
                : "实际气温 \(tempStr) · 相对湿度 \(humidityStr)"

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 20) {
                    // 1. 天气状况
                    VStack(alignment: .leading, spacing: 3) {
                        Text(prefs.language == .ja ? "天気" : "天气")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        HStack(spacing: 5) {
                            Image(systemName: cond.icon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(condColor)
                            Text(cond.title)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(KazeTheme.inkPrimary)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }
                    .contentShape(Rectangle())

                    // 2. 露点核心指标（悬停感应区）
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 3) {
                            Text(prefs.language == .ja ? "露点" : "露点")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                            Image(systemName: "info.circle")
                                .font(.system(size: 9))
                                .foregroundStyle(isDetailVisible ? KazeTheme.indigo : Color.secondary.opacity(0.45))
                        }
                        Text(dewPointStr)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(KazeTheme.inkPrimary)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(isDetailVisible ? KazeTheme.surfaceSubtle : Color.clear)
                    )
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        isHoveringDewPoint = hovering
                    }
                    .onTapGesture {
                        isPinned.toggle()
                    }

                    // 3. 风速
                    VStack(alignment: .leading, spacing: 3) {
                        Text(prefs.language == .ja ? "風速" : "风速")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text(windStr)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(KazeTheme.inkPrimary)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .padding(.vertical, 3)
                    .contentShape(Rectangle())

                    Spacer(minLength: 0)
                }

                // 悬停展开气象解算细节（零遮挡、零截断、零闪烁）
                if isDetailVisible {
                    HStack(spacing: 6) {
                        Image(systemName: "thermometer.medium")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(KazeTheme.vermilion)
                        Text(dewDetail)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(KazeTheme.inkPrimary)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(KazeTheme.surfaceSubtle)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(KazeTheme.hairline, lineWidth: 1)
                    )
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.15), value: isDetailVisible)
            .padding(.vertical, 2)
        }
    }

    private func weatherMetricsView(weather w: ActivityWeatherDTO) -> some View {
        ActivityWeatherSectionView(weather: w, prefs: appState.prefs)
    }

    private func gearAndWeatherCard(bundle: ActivityDetailBundle, activityId: Int) -> some View {
        let allShoes = appState.dashboard?.gear?.gear ?? []
        let linkedIds = Set((bundle.gear ?? []).compactMap(\.uuid))

        return KazeCard {
            KazeSectionHeader(
                jpTag: "ENV",
                title: appState.prefs.language == .ja ? "気象とシューズ" : "天气与关联跑鞋"
            )
            if let w = bundle.weather {
                weatherMetricsView(weather: w)
            } else {
                Text(appState.prefs.language == .ja ? "気象記録なし" : "暂无气象记录").font(.caption).foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text(appState.prefs.language == .ja ? "連携シューズ (Garmin クラウドと同期)" : "绑定跑鞋（直接同步 Garmin 云端）")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                if let linked = bundle.gear, !linked.isEmpty {
                    ForEach(linked) { g in
                        HStack {
                            Text(g.title).font(.system(size: 12, weight: .medium))
                            Spacer()
                            if let uuid = g.uuid {
                                Button(appState.prefs.language == .ja ? "解除" : "移除") {
                                    Task { await appState.setActivityGear(activityId: activityId, gearUuid: uuid, action: "remove") }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                            }
                        }
                    }
                } else {
                    Text(appState.prefs.language == .ja ? "シューズ未登録" : "未绑定跑鞋").font(.caption).foregroundStyle(.secondary)
                }

                if !allShoes.isEmpty {
                    Menu(appState.prefs.language == .ja ? "シューズを選択..." : "关联跑鞋...") {
                        ForEach(allShoes) { shoe in
                            if !linkedIds.contains(shoe.uuid) {
                                Button(shoe.displayTitle) {
                                    Task { await appState.setActivityGear(activityId: activityId, gearUuid: shoe.uuid, action: "add") }
                                }
                            }
                        }
                    }
                    .controlSize(.small)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: 185)
    }

    private func splitsTableCard(laps: [ActivityLapDTO]) -> some View {
        KazeCard {
            KazeSectionHeader(
                jpTag: "LAPS",
                title: appState.prefs.language == .ja ? "ラップ詳細" : "分段圈段明细",
                subtitle: appState.prefs.language == .ja ? "全 \(laps.count) ラップ" : "共 \(laps.count) 圈"
            )
            if laps.isEmpty {
                Text(appState.prefs.language == .ja ? "ラップデータなし" : "无分段数据").font(.caption).foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal) {
                  VStack(spacing: 0) {
                    HStack {
                        Text("#").frame(width: 30, alignment: .leading)
                        Text(appState.prefs.language == .ja ? "タイプ" : "类型").frame(width: 72, alignment: .leading)
                        Text(appState.prefs.language == .ja ? "距離" : "距离").frame(width: 68, alignment: .trailing)
                        Text(appState.prefs.language == .ja ? "タイム" : "用时").frame(width: 72, alignment: .trailing)
                        Text(appState.prefs.language == .ja ? "ペース" : "配速").frame(width: 66, alignment: .trailing)
                        Text(appState.prefs.language == .ja ? "平均HR" : "均心率").frame(width: 56, alignment: .trailing)
                        Text(appState.prefs.language == .ja ? "最大HR" : "最大心率").frame(width: 58, alignment: .trailing)
                        Text(appState.prefs.language == .ja ? "ピッチ" : "步频").frame(width: 50, alignment: .trailing)
                        Text(appState.prefs.language == .ja ? "高度差" : "爬升").frame(width: 50, alignment: .trailing)
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)

                    Divider()

                    ForEach(Array(laps.enumerated()), id: \.offset) { idx, lap in
                        HStack {
                            Text("\(lap.lapIndex ?? (idx + 1))").frame(width: 30, alignment: .leading)
                            Text(lap.intensityType ?? "-").frame(width: 72, alignment: .leading).lineLimit(1)
                            Text("\(appState.prefs.formatDistance(meters: lap.distance))k").frame(width: 68, alignment: .trailing)
                            Text(KazeFormat.duration(lap.duration)).frame(width: 72, alignment: .trailing)
                            Text(appState.prefs.formatPaceFromSpeedMps(lap.averageSpeed)).frame(width: 66, alignment: .trailing)
                                .foregroundStyle(KazeTheme.indigo)
                            Text(KazeFormat.integer(lap.averageHR)).frame(width: 56, alignment: .trailing)
                            Text(KazeFormat.integer(lap.maxHR)).frame(width: 58, alignment: .trailing)
                            Text(KazeFormat.integer(lap.averageRunCadence)).frame(width: 50, alignment: .trailing)
                            Text(lap.elevationGain.map { String(format: "+%.0f", $0) } ?? "-").frame(width: 50, alignment: .trailing)
                        }
                        .font(.system(size: 12, design: .monospaced))
                        .padding(.vertical, 5)
                        Divider()
                    }
                  }
                }
            }
        }
    }

    // MARK: - AI Debrief Card

    @ViewBuilder
    private func aiDebriefCard(activity: ActivityItem, bundle: ActivityDetailBundle, analysis: SportsScienceAnalysis?) -> some View {
        let isJa = appState.prefs.language == .ja
        let providerName = appState.prefs.aiProvider.rawValue.capitalized
        let activeModel = appState.prefs.aiProvider == .deepseek ? appState.prefs.deepseekModel : appState.prefs.geminiModel

        KazeCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    KazeSectionHeader(
                        jpTag: "AI COACH",
                        title: isJa ? "AI インテリジェントコーチ分析" : "AI 智能教练深度复盘",
                        subtitle: isJa ? "生理学シグナル · ペース制御 · リカバリー処方" : "运动生理学诊断 · 巡航体能分配 · 恢复与下一练"
                    )
                    Spacer()

                    HStack(spacing: 8) {
                        Text("\(providerName) · \(activeModel)")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(Capsule())

                        if appState.aiDebriefCache[activity.id] != nil && !appState.isGeneratingAIDebrief {
                            Button {
                                triggerAIDebrief(item: activity, bundle: bundle)
                            } label: {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help(isJa ? "再分析を実行" : "重新生成分析")
                        }
                    }
                }

                if appState.isGeneratingAIDebrief {
                    HStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.regular)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(isJa ? "運動生理学と心拍ドリフトを深層解算中..." : "正在结合 20k 高频采样、心率脱钩与步频专注度深度解算中...")
                                .font(.system(size: 13, weight: .medium))
                            Text(isJa ? "\(providerName) モデルがパーソナライズされたレビューを生成しています" : "正在调用 \(providerName) (\(activeModel)) 生成教练级实战指导")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else if let debrief = appState.aiDebriefCache[activity.id] {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(debrief)
                            .font(.system(size: 13))
                            .lineSpacing(5)
                            .textSelection(.enabled)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(KazeTheme.canvas.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    HStack {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10))
                            .foregroundStyle(KazeTheme.vermilion)
                        Text(isJa ? "本レビューは客観的テレメトリに基づく運動生理学ガイダンスです" : "复盘基于当前活动客观生理与环境指标生成 · 仅供运动科学参考")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                } else if let err = appState.aiDebriefError {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(KazeTheme.vermilion)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(isJa ? "AI分析に失敗しました" : "AI 复盘生成失败")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(KazeTheme.vermilion)
                            Text(err)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(isJa ? "再試行" : "重试") {
                            triggerAIDebrief(item: activity, bundle: bundle)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(12)
                    .background(KazeTheme.vermilion.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    // Empty callout state
                    HStack(spacing: 14) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 26))
                            .foregroundStyle(KazeTheme.vermilion.opacity(0.85))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(isJa ? "AI専属ランニングコーチによる詳細レビュー" : "AI 专属运动生理学教练复盘")
                                .font(.system(size: 13, weight: .semibold))
                            Text(isJa
                                ? "本アクティビティのペース変動、有酸素デカップリング(Pa:HR)、ピッチ安定性を分析し、次回メニューとリカバリー計画を提案します。"
                                : "一键解算本场跑步的巡航离散度、有氧脱钩漂移与动力链连贯性，生成客观专业的节奏复盘与下阶段课表指引。")
                                .font(.system(size: 11.5))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button {
                            triggerAIDebrief(item: activity, bundle: bundle)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                Text(isJa ? "コーチ分析を生成" : "生成教练复盘")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(KazeTheme.vermilion)
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }

    private func triggerAIDebrief(item: ActivityItem, bundle: ActivityDetailBundle?) {
        let hasKey = appState.prefs.aiProvider == .deepseek
            ? !appState.prefs.deepseekApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            : !appState.prefs.geminiApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        if !hasKey {
            appState.showSettingsSheet = true
            return
        }

        let pts = bundle?.telemetryPoints ?? []
        let analysis = computeSportsScience(points: pts)

        let h1Pace = analysis != nil ? appState.prefs.formatPace(secondsPerKm: analysis!.half1PaceSec) : nil
        let h2Pace = analysis != nil ? appState.prefs.formatPace(secondsPerKm: analysis!.half2PaceSec) : nil

        var zonesSummary: String? = nil
        if let zones = bundle?.hrZones, !zones.isEmpty {
            let total = zones.reduce(0.0) { $0 + ($1.secsInZone ?? 0.0) }
            if total > 0 {
                zonesSummary = zones.compactMap { z in
                    guard let sec = z.secsInZone, let num = z.zoneNumber else { return nil }
                    let pct = Int((sec / total) * 100)
                    return "Z\(num): \(pct)%"
                }.joined(separator: ", ")
            }
        }

        var weatherStr: String? = nil
        if let w = bundle?.weather {
            var parts: [String] = []
            if let temp = w.temp { parts.append("\(Int(temp))°C") }
            if let cond = w.weatherTypeDTO?.desc { parts.append(cond) }
            if let wind = w.windSpeed { parts.append("风速 \(Int(wind))km/h") }
            weatherStr = parts.joined(separator: " · ")
        }

        let shoeStr = bundle?.gear?.first?.title ?? bundle?.gear?.first?.displayName

        Task {
            await appState.generateAIDebrief(
                activityId: item.id,
                name: item.name ?? "跑步活动",
                type: item.type ?? "running",
                date: item.startTime ?? item.shortDate,
                distanceMeters: item.distanceMeters,
                durationSeconds: item.durationSeconds,
                avgHr: item.avgHrBpm,
                maxHr: item.maxHrBpm,
                decouplingPercent: analysis?.decouplingPercent,
                paceCV: analysis?.paceCV,
                cadenceStability: analysis?.cadenceStability,
                half1Pace: h1Pace,
                half2Pace: h2Pace,
                hrZonesSummary: zonesSummary,
                weather: weatherStr,
                shoe: shoeStr
            )
        }
    }
}
