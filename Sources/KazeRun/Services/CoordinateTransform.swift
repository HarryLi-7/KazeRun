import Foundation

enum CoordinateTransform {
    private static let a: Double = 6378245.0
    private static let ee: Double = 0.00669342162296594323

    static func isOutOfChina(lat: Double, lon: Double) -> Bool {
        if lon < 72.004 || lon > 137.8347 { return true }
        if lat < 0.8293 || lat > 55.8271 { return true }
        return false
    }

    private static func transformLat(x: Double, y: Double) -> Double {
        var ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * .pi) + 20.0 * sin(2.0 * x * .pi)) * 2.0 / 3.0
        ret += (20.0 * sin(y * .pi) + 40.0 * sin(y / 3.0 * .pi)) * 2.0 / 3.0
        ret += (160.0 * sin(y / 12.0 * .pi) + 320 * sin(y * .pi / 30.0)) * 2.0 / 3.0
        return ret
    }

    private static func transformLon(x: Double, y: Double) -> Double {
        var ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * .pi) + 20.0 * sin(2.0 * x * .pi)) * 2.0 / 3.0
        ret += (20.0 * sin(x * .pi) + 40.0 * sin(x / 3.0 * .pi)) * 2.0 / 3.0
        ret += (150.0 * sin(x / 12.0 * .pi) + 300.0 * sin(x / 30.0 * .pi)) * 2.0 / 3.0
        return ret
    }

    /// Converts WGS-84 coordinates (Garmin GPS) to GCJ-02 coordinates (Apple Maps in Mainland China).
    static func wgs84ToGcj02(lat: Double, lon: Double) -> (lat: Double, lon: Double) {
        if isOutOfChina(lat: lat, lon: lon) {
            return (lat, lon)
        }
        var dLat = transformLat(x: lon - 105.0, y: lat - 35.0)
        var dLon = transformLon(x: lon - 105.0, y: lat - 35.0)
        let radLat = lat / 180.0 * .pi
        var magic = sin(radLat)
        magic = 1 - ee * magic * magic
        let sqrtMagic = sqrt(magic)
        dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * .pi)
        dLon = (dLon * 180.0) / (a / sqrtMagic * cos(radLat) * .pi)
        return (lat + dLat, lon + dLon)
    }

    /// Reverse: GCJ-02 → WGS-84 (iterative, sub-meter precision).
    /// Used to shift Google WGS-84 tile requests to align with MKMapView's GCJ-02 coordinate space.
    static func gcj02ToWgs84(lat: Double, lon: Double) -> (lat: Double, lon: Double) {
        if isOutOfChina(lat: lat, lon: lon) {
            return (lat, lon)
        }
        var wgsLat = lat
        var wgsLon = lon
        for _ in 0..<8 {
            let gcj = wgs84ToGcj02(lat: wgsLat, lon: wgsLon)
            wgsLat += lat - gcj.lat
            wgsLon += lon - gcj.lon
            if abs(lat - gcj.lat) < 1e-9 && abs(lon - gcj.lon) < 1e-9 { break }
        }
        return (wgsLat, wgsLon)
    }
}
