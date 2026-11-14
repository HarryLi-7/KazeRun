import SwiftUI

enum KazeTheme {
    // Adaptive Japanese Sports Palette: Washi off-white (Light) / Sumi charcoal (Dark)
    static let canvas = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.067, green: 0.075, blue: 0.082, alpha: 1.0) // #111315
            : NSColor(red: 0.969, green: 0.965, blue: 0.949, alpha: 1.0) // #F7F6F2 Washi
    })

    static let surface = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.098, green: 0.110, blue: 0.125, alpha: 1.0) // #191C20
            : NSColor.white
    })

    static let surfaceSubtle = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.133, green: 0.149, blue: 0.169, alpha: 1.0)
            : NSColor(red: 0.945, green: 0.941, blue: 0.922, alpha: 1.0) // #F1F0EB
    })

    static let hairline = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.165, green: 0.184, blue: 0.212, alpha: 1.0)
            : NSColor(red: 0.902, green: 0.894, blue: 0.867, alpha: 1.0) // #E6E4DD
    })

    static let inkPrimary = Color.primary
    static let inkSecondary = Color.secondary

    // Ekiden Vermilion Accent (#E14B32)
    static let vermilion = Color(red: 0.882, green: 0.294, blue: 0.196)
    // Sage Recovery Green (#2E8555)
    static let sage = Color(red: 0.180, green: 0.522, blue: 0.333)
    // Indigo / Track Blue (#2D5BFF)
    static let indigo = Color(red: 0.176, green: 0.357, blue: 0.929)
    // Amber Caution (#D9822B)
    static let amber = Color(red: 0.851, green: 0.510, blue: 0.169)
}

struct KazeCard<Content: View>: View {
    var padding: CGFloat = 16
    var fillHeight: Bool = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(padding)
        .frame(maxWidth: .infinity, maxHeight: fillHeight ? .infinity : nil, alignment: .topLeading)
        .background(KazeTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(KazeTheme.hairline, lineWidth: 1)
        )
    }
}

struct KazeSectionHeader: View {
    let jpTag: String
    let title: String
    var subtitle: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(jpTag)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(KazeTheme.vermilion)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(KazeTheme.vermilion.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .fixedSize()

            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(KazeTheme.inkPrimary)
                .lineLimit(1)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(KazeTheme.inkSecondary)
                    .lineLimit(1)
            }
        }
    }
}

struct KazeMetricBadge: View {
    let label: String
    let value: String
    var unit: String? = nil
    var tone: Color = KazeTheme.inkPrimary

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(KazeTheme.inkSecondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(tone)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                if let unit, !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(KazeTheme.inkSecondary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
        }
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
    }
}

enum KazeFormat {
    static func pace(secondsPerKm: Double?) -> String {
        UserPreferences.shared.formatPace(secondsPerKm: secondsPerKm)
    }

    static func distanceKm(_ meters: Double?) -> String {
        UserPreferences.shared.formatDistance(meters: meters)
    }

    static func duration(_ seconds: Double?) -> String {
        guard let sec = seconds, sec.isFinite, sec >= 0 else { return "--:--" }
        let total = Int(sec.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    static func integer(_ value: Double?) -> String {
        guard let v = value, v.isFinite else { return "--" }
        return String(Int(v.rounded()))
    }
}
