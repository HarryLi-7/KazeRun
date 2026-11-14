import Charts
import SwiftUI

struct TrendsView: View {
    @Environment(AppState.self) private var appState

    @State private var hoveredHRVDate: String? = nil
    @State private var hoveredVO2Date: String? = nil

    private static let plotDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("PHYSIOLOGY & PERFORMANCE")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(KazeTheme.vermilion)
                        Text(appState.prefs.language == .ja ? "身体トレンドと自己ベスト" : "身体趋势与个人纪录")
                            .font(.system(size: 22, weight: .bold))
                    }
                    Spacer()
                    Picker("趋势窗口", selection: Binding(
                        get: { appState.trendDays },
                        set: { days in
                            appState.trendDays = days
                            Task { await appState.syncDashboard() }
                        }
                    )) {
                        Text(appState.prefs.language == .ja ? "14 日間" : "14 天").tag(14)
                        Text(appState.prefs.language == .ja ? "30 日間" : "30 天").tag(30)
                        Text(appState.prefs.language == .ja ? "60 日間" : "60 天").tag(60)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                }

                if let dash = appState.dashboard {
                    let timeline = sharedTimeline(for: dash)
                    HStack(alignment: .top, spacing: 14) {
                        hrvTrendCard(dash, domain: timeline.domain, axisDates: timeline.axisDates)
                        vo2TrendCard(dash, domain: timeline.domain, axisDates: timeline.axisDates)
                    }
                    lactateAndZonesRow(dash)
                    personalRecordsCard(dash)
                } else {
                    KazeCard {
                        Text(appState.prefs.language == .ja ? "データを同期するとトレンドが表示されます。" : "请先同步数据以查看趋势图表。")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(20)
        }
        .background(KazeTheme.canvas)
    }

    // MARK: - Sample Dates for X-Axis to prevent text collision

    private func sampleAxisDates(from dates: [String], maxCount: Int = 6) -> [String] {
        guard dates.count > maxCount else { return dates }
        let step = Double(dates.count - 1) / Double(maxCount - 1)
        var result: [String] = []
        for i in 0..<maxCount {
            let index = min(dates.count - 1, Int((Double(i) * step).rounded()))
            let d = dates[index]
            if !result.contains(d) {
                result.append(d)
            }
        }
        return result
    }

    private func sharedTimeline(for dash: DashboardSnapshot) -> (domain: ClosedRange<Date>, axisDates: [Date]) {
        let hrvDates = (dash.hrvTrend?.trend ?? []).compactMap { $0.lastNightAvgHrvMs != nil ? $0.date : nil }
        let vo2Dates = (dash.vo2maxTrend?.trend ?? []).compactMap { $0.vo2Max != nil ? $0.date : nil }
        let union = Array(Set(hrvDates + vo2Dates)).sorted()

        guard let firstStr = union.first, let lastStr = union.last,
              let firstDate = Self.plotDateFormatter.date(from: firstStr),
              let lastDate = Self.plotDateFormatter.date(from: lastStr) else {
            let now = Date()
            return (now.addingTimeInterval(-86400 * 30)...now, [])
        }

        let sampleStrs = sampleAxisDates(from: union, maxCount: 4)
        let axisDates = sampleStrs.compactMap { Self.plotDateFormatter.date(from: $0) }
        let padSeconds: TimeInterval = 43200 // 12小时微内边距，确保边界点清晰不压边
        let domain = firstDate.addingTimeInterval(-padSeconds)...lastDate.addingTimeInterval(padSeconds)
        return (domain, axisDates)
    }

    // MARK: - HRV Recovery Trend Card

    private func hrvTrendCard(_ dash: DashboardSnapshot, domain: ClosedRange<Date>, axisDates: [Date]) -> some View {
        let points = (dash.hrvTrend?.trend ?? [])
            .filter { $0.lastNightAvgHrvMs != nil && Self.plotDateFormatter.date(from: $0.date) != nil }
            .sorted { $0.date < $1.date }
        let low = dash.hrvData?.baselineBalancedLowMs
        let high = dash.hrvData?.baselineBalancedUpperMs
        let allDates = points.map(\.date)

        let hoveredPoint = hoveredHRVDate.flatMap { d in
            points.first(where: { $0.date == d })
        }

        return KazeCard {
            HStack {
                KazeSectionHeader(
                    jpTag: "HRV",
                    title: appState.prefs.language == .ja ? "HRV 回復トレンド" : "HRV 恢复趋势",
                    subtitle: dash.hrvTrend?.periodAvgHrvMs.map { String(format: appState.prefs.language == .ja ? "平均 %.1f ms" : "均值 %.1f ms", $0) }
                )
            }

            // Interactive Tooltip & Legend Bar
            HStack(spacing: 12) {
                if let pt = hoveredPoint {
                    Text("📅 \(pt.date)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                    if let val = pt.lastNightAvgHrvMs {
                        Text("💚 夜间: \(Int(val)) ms")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(KazeTheme.sage)
                    }
                    if let wk = pt.weeklyAvgHrvMs {
                        Text("💙 7日均: \(Int(wk)) ms")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(KazeTheme.indigo)
                    }
                    if let status = pt.status {
                        Text(KazeI18n.hrvStatus(status, lang: appState.prefs.language))
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(KazeTheme.sage.opacity(0.15))
                            .clipShape(Capsule())
                    }
                } else {
                    HStack(spacing: 14) {
                        HStack(spacing: 4) {
                            Circle().fill(KazeTheme.sage).frame(width: 6, height: 6)
                            Text("夜间实测").font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                        HStack(spacing: 4) {
                            Rectangle().fill(KazeTheme.indigo).frame(width: 10, height: 2)
                            Text("7日滚动均线").font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                        if let l = low, let h = high {
                            HStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 2).fill(KazeTheme.sage.opacity(0.3)).frame(width: 10, height: 6)
                                Text("均衡基线范围 (\(Int(l))-\(Int(h))ms)").font(.system(size: 10)).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Spacer()
            }
            .frame(height: 22)
            .padding(.horizontal, 10)
            .padding(.vertical, 2)
            .background(KazeTheme.surfaceSubtle)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            if points.isEmpty {
                Text("暂无 HRV 趋势数据").font(.caption).foregroundStyle(.secondary)
                    .frame(height: 200)
            } else {
                Chart {
                    // 1. Shaded Baseline Band across full 30-day window (横贯全图的恒定基准带)
                    if let low, let high {
                        RectangleMark(
                            yStart: .value("Low", low),
                            yEnd: .value("High", high)
                        )
                        .foregroundStyle(KazeTheme.sage.opacity(0.10))

                        RuleMark(y: .value("Low", low))
                            .lineStyle(StrokeStyle(lineWidth: 1.0, dash: [4, 4]))
                            .foregroundStyle(KazeTheme.sage.opacity(0.55))

                        RuleMark(y: .value("High", high))
                            .lineStyle(StrokeStyle(lineWidth: 1.0, dash: [4, 4]))
                            .foregroundStyle(KazeTheme.sage.opacity(0.55))
                    }

                    // 2. Nightly HRV Series (Solid Green with dots)
                    ForEach(points) { pt in
                        if let val = pt.lastNightAvgHrvMs {
                            LineMark(
                                x: .value("日期", Self.plotDateFormatter.date(from: pt.date)!),
                                y: .value("夜间HRV", val),
                                series: .value("曲线", "夜间HRV")
                            )
                            .foregroundStyle(KazeTheme.sage)
                            .lineStyle(StrokeStyle(lineWidth: 2))

                            PointMark(
                                x: .value("日期", Self.plotDateFormatter.date(from: pt.date)!),
                                y: .value("夜间HRV", val)
                            )
                            .foregroundStyle(KazeTheme.sage)
                            .symbolSize(20)
                        }
                    }

                    // 3. 7-Day Rolling Average Series (Dashed Indigo)
                    ForEach(points) { pt in
                        if let wk = pt.weeklyAvgHrvMs {
                            LineMark(
                                x: .value("日期", Self.plotDateFormatter.date(from: pt.date)!),
                                y: .value("7日均", wk),
                                series: .value("曲线", "7日均")
                            )
                            .foregroundStyle(KazeTheme.indigo)
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 3]))
                        }
                    }

                    // 4. Hover Vertical Rule & Highlighted Point
                    if let pt = hoveredPoint {
                        RuleMark(x: .value("日期", Self.plotDateFormatter.date(from: pt.date)!))
                            .foregroundStyle(KazeTheme.vermilion.opacity(0.8))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))

                        if let val = pt.lastNightAvgHrvMs {
                            PointMark(
                                x: .value("日期", Self.plotDateFormatter.date(from: pt.date)!),
                                y: .value("夜间HRV", val)
                            )
                            .foregroundStyle(KazeTheme.vermilion)
                            .symbolSize(55)
                        }
                    }
                }
                .chartXScale(domain: domain)
                .chartXAxis {
                    AxisMarks(values: axisDates) { value in
                        AxisGridLine()
                        AxisTick()
                        if let d = value.as(Date.self) {
                            AxisValueLabel(anchor: d == axisDates.first ? .leading : (d == axisDates.last ? .trailing : .center), collisionResolution: .disabled) {
                                Text(String(Self.plotDateFormatter.string(from: d).suffix(5)))
                                    .font(.system(size: 10, design: .monospaced))
                                    .fixedSize()
                            }
                        }
                    }
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .chartYAxis {
                    AxisMarks(position: .trailing) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let d = value.as(Double.self) {
                                Text("\(Int(d))")
                                    .font(.system(size: 10, design: .monospaced))
                                    .frame(width: 32, alignment: .leading)
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
                                    if let date: Date = proxy.value(atX: loc.x) {
                                        hoveredHRVDate = allDates.min {
                                            abs(Self.plotDateFormatter.date(from: $0)!.timeIntervalSince(date)) < abs(Self.plotDateFormatter.date(from: $1)!.timeIntervalSince(date))
                                        }
                                    } else {
                                        hoveredHRVDate = nil
                                    }
                                case .ended:
                                    hoveredHRVDate = nil
                                }
                            }
                    }
                }
                .frame(height: 200)
            }
        }
    }

    // MARK: - VO2Max Trend Card

    private func vo2TrendCard(_ dash: DashboardSnapshot, domain: ClosedRange<Date>, axisDates: [Date]) -> some View {
        let points = (dash.vo2maxTrend?.trend ?? [])
            .filter { $0.vo2Max != nil && Self.plotDateFormatter.date(from: $0.date) != nil }
            .sorted { $0.date < $1.date }
        let allDates = points.map(\.date)

        let hoveredPoint = hoveredVO2Date.flatMap { d in
            points.first(where: { $0.date == d })
        }

        return KazeCard {
            HStack {
                KazeSectionHeader(
                    jpTag: "VO2MAX",
                    title: appState.prefs.language == .ja ? "最大酸素摂取量の推移" : "最大摄氧量演变",
                    subtitle: dash.vo2maxTrend?.change.map { String(format: appState.prefs.language == .ja ? "期間変化 %+.1f" : "区间变化 %+.1f", $0) }
                )
            }

            // Interactive Tooltip & Legend Bar
            HStack(spacing: 12) {
                if let pt = hoveredPoint {
                    Text("📅 \(pt.date)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                    if let v = pt.vo2Max {
                        Text("🏃 VO2Max: \(String(format: "%.1f", v))")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(KazeTheme.vermilion)
                    }
                } else {
                    HStack(spacing: 14) {
                        HStack(spacing: 4) {
                            Rectangle().fill(KazeTheme.vermilion).frame(width: 10, height: 2)
                            Text("最大摄氧量趋势曲线").font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
            }
            .frame(height: 22)
            .padding(.horizontal, 10)
            .padding(.vertical, 2)
            .background(KazeTheme.surfaceSubtle)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            if points.isEmpty {
                Text("暂无 VO2Max 趋势数据").font(.caption).foregroundStyle(.secondary)
                    .frame(height: 200)
            } else {
                let minY = (points.compactMap(\.vo2Max).min() ?? 50) - 0.5
                Chart {
                    ForEach(points) { pt in
                        if let v = pt.vo2Max {
                            LineMark(
                                x: .value("日期", Self.plotDateFormatter.date(from: pt.date)!),
                                y: .value("VO2Max", v)
                            )
                            .foregroundStyle(KazeTheme.vermilion)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))

                            AreaMark(
                                x: .value("日期", Self.plotDateFormatter.date(from: pt.date)!),
                                yStart: .value("Min", minY),
                                yEnd: .value("VO2Max", v)
                            )
                            .foregroundStyle(KazeTheme.vermilion.opacity(0.10))
                        }
                    }

                    if let pt = hoveredPoint, let v = pt.vo2Max {
                        RuleMark(x: .value("日期", Self.plotDateFormatter.date(from: pt.date)!))
                            .foregroundStyle(KazeTheme.vermilion.opacity(0.8))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))

                        PointMark(
                            x: .value("日期", Self.plotDateFormatter.date(from: pt.date)!),
                            y: .value("VO2Max", v)
                        )
                        .foregroundStyle(KazeTheme.vermilion)
                        .symbolSize(55)
                    }
                }
                .chartXScale(domain: domain)
                .chartXAxis {
                    AxisMarks(values: axisDates) { value in
                        AxisGridLine()
                        AxisTick()
                        if let d = value.as(Date.self) {
                            AxisValueLabel(anchor: d == axisDates.first ? .leading : (d == axisDates.last ? .trailing : .center), collisionResolution: .disabled) {
                                Text(String(Self.plotDateFormatter.string(from: d).suffix(5)))
                                    .font(.system(size: 10, design: .monospaced))
                                    .fixedSize()
                            }
                        }
                    }
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .chartYAxis {
                    AxisMarks(position: .trailing) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let d = value.as(Double.self) {
                                Text(String(format: "%.1f", d))
                                    .font(.system(size: 10, design: .monospaced))
                                    .frame(width: 32, alignment: .leading)
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
                                    if let date: Date = proxy.value(atX: loc.x) {
                                        hoveredVO2Date = allDates.min {
                                            abs(Self.plotDateFormatter.date(from: $0)!.timeIntervalSince(date)) < abs(Self.plotDateFormatter.date(from: $1)!.timeIntervalSince(date))
                                        }
                                    } else {
                                        hoveredVO2Date = nil
                                    }
                                case .ended:
                                    hoveredVO2Date = nil
                                }
                            }
                    }
                }
                .frame(height: 200)
            }
        }
    }

    private func lactateAndZonesRow(_ dash: DashboardSnapshot) -> some View {
        HStack(alignment: .top, spacing: 14) {
            KazeCard {
                KazeSectionHeader(
                    jpTag: "LT",
                    title: appState.prefs.language == .ja ? "乳酸性作業閾値 (Lactate Threshold)" : "乳酸阈值 (Lactate Threshold)",
                    subtitle: dash.lactateThreshold?.speedHrDate.map { String($0.prefix(10)) }
                )
                HStack(spacing: 20) {
                    KazeMetricBadge(
                        label: appState.prefs.language == .ja ? "閾値ペース" : "阈值配速",
                        value: appState.prefs.formatPaceFromSpeedMps(dash.lactateThreshold?.lactateThresholdSpeedMps),
                        unit: appState.prefs.paceUnitSuffix(),
                        tone: KazeTheme.vermilion
                    )
                    KazeMetricBadge(
                        label: appState.prefs.language == .ja ? "閾値心拍" : "阈值心率",
                        value: dash.lactateThreshold?.lactateThresholdHeartRateBpm.map(String.init) ?? "--",
                        unit: "bpm"
                    )
                    KazeMetricBadge(
                        label: appState.prefs.language == .ja ? "閾値パワー" : "阈值功率",
                        value: dash.lactateThreshold?.functionalThresholdPowerWatts.map(String.init) ?? "--",
                        unit: "W"
                    )
                    KazeMetricBadge(
                        label: appState.prefs.language == .ja ? "体重" : "体重",
                        value: dash.lactateThreshold?.weightKg.map { String(format: "%.1f", $0) } ?? "--",
                        unit: "kg"
                    )
                }
            }

            KazeCard {
                KazeSectionHeader(
                    jpTag: "HRZ",
                    title: appState.prefs.language == .ja ? "心拍ゾーン設定" : "账户心率区间设置",
                    subtitle: KazeI18n.hrMethod(dash.heartRateZones?.first?.trainingMethod, lang: appState.prefs.language)
                )
                if let firstProfile = dash.heartRateZones?.first, !firstProfile.bands.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(firstProfile.bands, id: \.zone) { band in
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Z\(band.zone)")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(KazeTheme.vermilion)
                                Text(band.range)
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    .lineLimit(1)
                                    .fixedSize()
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(KazeTheme.surfaceSubtle)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                } else {
                    Text("未读取到心率区间配置").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Personal Records (PR) with Pace calculation

    private func calculatePRPace(rawType: String, valStr: String, rawVal: Double?) -> Double? {
        var sec: Double? = rawVal
        if sec == nil || sec! <= 0 {
            let parts = valStr.split(separator: ":").compactMap { Double($0) }
            if parts.count == 2 {
                sec = parts[0] * 60.0 + parts[1]
            } else if parts.count == 3 {
                sec = parts[0] * 3600.0 + parts[1] * 60.0 + parts[2]
            }
        }
        guard let totalSec = sec, totalSec > 0 else { return nil }

        let lower = rawType.lowercased()
        // 1公里成绩即为每公里配速本身，不重复显示配速徽章
        if lower.contains("1k") || lower.contains("1 公里") || lower.contains("1km") {
            return nil
        }
        if lower.contains("mile") || lower.contains("1 英里") || lower.contains("1mi") {
            return totalSec / 1.609344
        }
        if lower.contains("5k") || lower.contains("5 公里") || lower.contains("5km") {
            return totalSec / 5.0
        }
        if lower.contains("10k") || lower.contains("10 公里") || lower.contains("10km") {
            return totalSec / 10.0
        }
        if lower.contains("half") || lower.contains("半程") || lower.contains("半马") {
            return totalSec / 21.0975
        }
        if lower.contains("marathon") || lower.contains("全程") || lower.contains("全马") {
            return totalSec / 42.195
        }
        return nil
    }

    private func personalRecordsCard(_ dash: DashboardSnapshot) -> some View {
        let records = dash.personalRecord?.arrayValue ?? []
        return KazeCard {
            KazeSectionHeader(
                jpTag: "PR",
                title: appState.prefs.language == .ja ? "自己記録 (PR)" : "个人纪录墙",
                subtitle: "\(records.count) 项"
            )
            if records.isEmpty {
                Text("暂无个人纪录数据").font(.caption).foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 10)], spacing: 10) {
                    ForEach(Array(records.enumerated()), id: \.offset) { _, rec in
                        let obj = rec.objectValue ?? [:]
                        let rawTitle = obj["record_type"]?.stringValue
                            ?? obj["typeName"]?.stringValue
                            ?? obj["type_id"]?.stringValue
                            ?? "Record"
                        let title = KazeI18n.recordTitle(rawTitle, lang: appState.prefs.language)
                        let val = obj["formatted_value"]?.stringValue
                            ?? obj["value"]?.stringValue
                            ?? "--"
                        let rawVal = obj["raw_value"]?.doubleValue
                            ?? obj["rawValue"]?.doubleValue
                        let dateStr = obj["date"]?.stringValue
                            ?? obj["created_date"]?.stringValue
                            ?? obj["activity_start_time"]?.stringValue
                            ?? ""
                        let paceSec = calculatePRPace(rawType: rawTitle, valStr: val, rawVal: rawVal)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(title)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)

                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(val)
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(KazeTheme.vermilion)
                                    .lineLimit(1)
                                    .fixedSize()

                                if let paceSec {
                                    Text(appState.prefs.formatPace(secondsPerKm: paceSec) + appState.prefs.paceUnitSuffix())
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundStyle(KazeTheme.indigo)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1.5)
                                        .background(KazeTheme.indigo.opacity(0.10))
                                        .clipShape(RoundedRectangle(cornerRadius: 3))
                                        .lineLimit(1)
                                }
                            }

                            if !dateStr.isEmpty {
                                Text(String(dateStr.prefix(10)))
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(KazeTheme.surfaceSubtle)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }
}
