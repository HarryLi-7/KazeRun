import Foundation

// MARK: - Auth & Bridge Models

struct AuthStatus: Codable {
    let authenticated: Bool
    let isCn: Bool
    let displayName: String?
    let email: String?
    let tokenDir: String
    let devImportAvailable: Bool
    let devImportPath: String?

    enum CodingKeys: String, CodingKey {
        case authenticated
        case isCn = "is_cn"
        case displayName = "display_name"
        case email
        case tokenDir = "token_dir"
        case devImportAvailable = "dev_import_available"
        case devImportPath = "dev_import_path"
    }
}

struct BridgeErrorInfo: Error, LocalizedError {
    let code: String
    let message: String

    var errorDescription: String? {
        "[\(code)] \(message)"
    }
}

// MARK: - Dashboard Snapshot (matches kaze_bridge sync_dashboard)

struct DashboardSnapshot: Codable {
    let capturedAt: String
    let date: String
    let displayName: String?
    let isCn: Bool?
    let sleepSummary: SleepSummary?
    let hrvData: HRVData?
    let hrvTrend: HRVTrendResponse?
    let rhrDay: RHRDayResponse?
    let stats: DailyStats?
    let bodyBattery: [BodyBatteryDay]?
    let stressSummary: StressSummary?
    let respirationSummary: RespirationSummary?
    let spo2Data: SpO2Data?
    let trainingStatus: TrainingStatus?
    let trainingLoadBalance: TrainingLoadBalance?
    let vo2maxTrend: VO2MaxTrendResponse?
    let lactateThreshold: LactateThreshold?
    let racePredictions: RacePredictionsResponse?
    let personalRecord: AnyCodableValue?
    let heartRateZones: [HRZoneDefinition]?
    let gear: GearResponse?
    let devices: [GarminDevice]?
    let deviceLastUsed: DeviceLastUsed?
    let workouts: WorkoutsResponse?
    let garminCoachWorkouts: CoachWorkoutsResponse?
    let scheduledWorkouts: ScheduledWorkoutsResponse?
    let calendarEvents: CalendarEventsResponse?
    let errors: [String: SectionError]?

    enum CodingKeys: String, CodingKey {
        case capturedAt = "captured_at"
        case date
        case displayName = "display_name"
        case isCn = "is_cn"
        case sleepSummary = "sleep_summary"
        case hrvData = "hrv_data"
        case hrvTrend = "hrv_trend"
        case rhrDay = "rhr_day"
        case stats
        case bodyBattery = "body_battery"
        case stressSummary = "stress_summary"
        case respirationSummary = "respiration_summary"
        case spo2Data = "spo2_data"
        case trainingStatus = "training_status"
        case trainingLoadBalance = "training_load_balance"
        case vo2maxTrend = "vo2max_trend"
        case lactateThreshold = "lactate_threshold"
        case racePredictions = "race_predictions"
        case personalRecord = "personal_record"
        case heartRateZones = "heart_rate_zones"
        case gear
        case devices
        case deviceLastUsed = "device_last_used"
        case workouts
        case garminCoachWorkouts = "garmin_coach_workouts"
        case scheduledWorkouts = "scheduled_workouts"
        case calendarEvents = "calendar_events"
        case errors
    }

    var restingHRValue: Int? {
        if let v = stats?.restingHeartRateBpm { return Int(v) }
        if let v = sleepSummary?.restingHeartRateBpm { return Int(v) }
        if let first = rhrDay?.allMetrics?.metricsMap?.restingHeartRate?.first?.value {
            return Int(first)
        }
        return nil
    }
}

struct SectionError: Codable {
    let errorCode: String?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case errorCode = "error_code"
        case message
    }
}

struct SleepSummary: Codable {
    let sleepSeconds: Double?
    let napSeconds: Double?
    let sleepScore: Int?
    let sleepScoreQualifier: String?
    let deepSleepSeconds: Double?
    let lightSleepSeconds: Double?
    let remSleepSeconds: Double?
    let awakeSeconds: Double?
    let avgSleepStress: Double?
    let restingHeartRateBpm: Double?
    let avgOvernightHrv: Double?
    let deepSleepPercent: Double?
    let lightSleepPercent: Double?
    let remSleepPercent: Double?
    let sleepHours: Double?

    enum CodingKeys: String, CodingKey {
        case sleepSeconds = "sleep_seconds"
        case napSeconds = "nap_seconds"
        case sleepScore = "sleep_score"
        case sleepScoreQualifier = "sleep_score_qualifier"
        case deepSleepSeconds = "deep_sleep_seconds"
        case lightSleepSeconds = "light_sleep_seconds"
        case remSleepSeconds = "rem_sleep_seconds"
        case awakeSeconds = "awake_seconds"
        case avgSleepStress = "avg_sleep_stress"
        case restingHeartRateBpm = "resting_heart_rate_bpm"
        case avgOvernightHrv = "avg_overnight_hrv"
        case deepSleepPercent = "deep_sleep_percent"
        case lightSleepPercent = "light_sleep_percent"
        case remSleepPercent = "rem_sleep_percent"
        case sleepHours = "sleep_hours"
    }
}

struct HRVReading: Codable, Identifiable {
    var id: String { time }
    let time: String
    let hrvMs: Double?

    enum CodingKeys: String, CodingKey {
        case time
        case hrvMs = "hrv_ms"
    }
}

struct HRVData: Codable {
    let date: String?
    let lastNightAvgHrvMs: Double?
    let lastNight5MinHighHrvMs: Double?
    let weeklyAvgHrvMs: Double?
    let baselineBalancedLowMs: Double?
    let baselineBalancedUpperMs: Double?
    let baselineLowUpperMs: Double?
    let status: String?
    let feedback: String?
    let sleepStart: String?
    let sleepEnd: String?
    let hrvReadings: [HRVReading]?
    let readingsCount: Int?

    enum CodingKeys: String, CodingKey {
        case date
        case lastNightAvgHrvMs = "last_night_avg_hrv_ms"
        case lastNight5MinHighHrvMs = "last_night_5min_high_hrv_ms"
        case weeklyAvgHrvMs = "weekly_avg_hrv_ms"
        case baselineBalancedLowMs = "baseline_balanced_low_ms"
        case baselineBalancedUpperMs = "baseline_balanced_upper_ms"
        case baselineLowUpperMs = "baseline_low_upper_ms"
        case status
        case feedback
        case sleepStart = "sleep_start"
        case sleepEnd = "sleep_end"
        case hrvReadings = "hrv_readings"
        case readingsCount = "readings_count"
    }
}

struct HRVTrendResponse: Codable {
    let startDate: String?
    let endDate: String?
    let periodAvgHrvMs: Double?
    let trend: [HRVTrendPoint]?

    enum CodingKeys: String, CodingKey {
        case startDate = "start_date"
        case endDate = "end_date"
        case periodAvgHrvMs = "period_avg_hrv_ms"
        case trend
    }
}

struct HRVTrendPoint: Codable, Identifiable {
    var id: String { date }
    let date: String
    let lastNightAvgHrvMs: Double?
    let weeklyAvgHrvMs: Double?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case date
        case lastNightAvgHrvMs = "last_night_avg_hrv_ms"
        case weeklyAvgHrvMs = "weekly_avg_hrv_ms"
        case status
    }
}

struct RHRDayResponse: Codable {
    let allMetrics: RHRAllMetrics?
}

struct RHRAllMetrics: Codable {
    let metricsMap: RHRMetricsMap?
}

struct RHRMetricsMap: Codable {
    let restingHeartRate: [RHRMetricPoint]?

    enum CodingKeys: String, CodingKey {
        case restingHeartRate = "WELLNESS_RESTING_HEART_RATE"
    }
}

struct RHRMetricPoint: Codable {
    let value: Double?
    let calendarDate: String?
}

struct DailyStats: Codable {
    let date: String?
    let totalSteps: Int?
    let dailyStepGoal: Int?
    let distanceMeters: Double?
    let totalCalories: Double?
    let activeCalories: Double?
    let restingHeartRateBpm: Double?
    let last7DaysAvgRestingHr: Double?
    let avgStressLevel: Int?
    let stressQualifier: String?
    let bodyBatteryCurrent: Int?
    let bodyBatteryHighest: Int?
    let bodyBatteryLowest: Int?
    let bodyBatteryCharged: Int?
    let bodyBatteryDrained: Int?

    enum CodingKeys: String, CodingKey {
        case date
        case totalSteps = "total_steps"
        case dailyStepGoal = "daily_step_goal"
        case distanceMeters = "distance_meters"
        case totalCalories = "total_calories"
        case activeCalories = "active_calories"
        case restingHeartRateBpm = "resting_heart_rate_bpm"
        case last7DaysAvgRestingHr = "last_7_days_avg_resting_hr"
        case avgStressLevel = "avg_stress_level"
        case stressQualifier = "stress_qualifier"
        case bodyBatteryCurrent = "body_battery_current"
        case bodyBatteryHighest = "body_battery_highest"
        case bodyBatteryLowest = "body_battery_lowest"
        case bodyBatteryCharged = "body_battery_charged"
        case bodyBatteryDrained = "body_battery_drained"
    }
}

struct BodyBatteryDay: Codable {
    let date: String?
    let charged: Int?
    let drained: Int?
    let bodyBatteryLevel: String?
    let events: [BodyBatteryEvent]?

    enum CodingKeys: String, CodingKey {
        case date, charged, drained, events
        case bodyBatteryLevel = "body_battery_level"
    }
}

struct BodyBatteryEvent: Codable, Identifiable {
    var id: String { "\(type ?? "")-\(startTime ?? "")" }
    let type: String?
    let startTime: String?
    let bodyBatteryImpact: Int?
    let feedback: String?
    let durationMinutes: Double?

    enum CodingKeys: String, CodingKey {
        case type
        case startTime = "start_time"
        case bodyBatteryImpact = "body_battery_impact"
        case feedback
        case durationMinutes = "duration_minutes"
    }
}

struct StressSummary: Codable {
    let avgStressLevel: Int?
    let maxStressLevel: Int?
    let restPercent: Double?
    let lowStressPercent: Double?
    let mediumStressPercent: Double?
    let highStressPercent: Double?

    enum CodingKeys: String, CodingKey {
        case avgStressLevel = "avg_stress_level"
        case maxStressLevel = "max_stress_level"
        case restPercent = "rest_percent"
        case lowStressPercent = "low_stress_percent"
        case mediumStressPercent = "medium_stress_percent"
        case highStressPercent = "high_stress_percent"
    }
}

struct RespirationSummary: Codable {
    let avgWakingBreathsPerMin: Double?
    let avgSleepBreathsPerMin: Double?

    enum CodingKeys: String, CodingKey {
        case avgWakingBreathsPerMin = "avg_waking_breaths_per_min"
        case avgSleepBreathsPerMin = "avg_sleep_breaths_per_min"
    }
}

struct SpO2Data: Codable {
    let avgSpo2Percent: Double?
    let lowestSpo2Percent: Double?

    enum CodingKeys: String, CodingKey {
        case avgSpo2Percent = "avg_spo2_percent"
        case lowestSpo2Percent = "lowest_spo2_percent"
    }
}

struct TrainingStatus: Codable {
    let date: String?
    let reportingDeviceName: String?
    let trainingStatusFeedback: String?
    let vo2MaxPrecise: Double?
    let acuteLoad: Double?
    let chronicLoad: Double?
    let loadRatio: Double?
    let acwrStatus: String?
    let trainingBalanceFeedback: String?

    enum CodingKeys: String, CodingKey {
        case date
        case reportingDeviceName = "reporting_device_name"
        case trainingStatusFeedback = "training_status_feedback"
        case vo2MaxPrecise = "vo2_max_precise"
        case acuteLoad = "acute_load"
        case chronicLoad = "chronic_load"
        case loadRatio = "load_ratio"
        case acwrStatus = "acwr_status"
        case trainingBalanceFeedback = "training_balance_feedback"
    }
}

struct TrainingLoadBalance: Codable {
    let feedback: String?
    let aerobicLow: LoadBand?
    let aerobicHigh: LoadBand?
    let anaerobic: LoadBand?

    enum CodingKeys: String, CodingKey {
        case feedback
        case aerobicLow = "aerobic_low"
        case aerobicHigh = "aerobic_high"
        case anaerobic
    }
}

struct LoadBand: Codable {
    let load: Double?
    let targetMin: Double?
    let targetMax: Double?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case load
        case targetMin = "target_min"
        case targetMax = "target_max"
        case status
    }
}

struct VO2MaxTrendResponse: Codable {
    let firstVo2Max: Double?
    let latestVo2Max: Double?
    let change: Double?
    let trend: [VO2MaxPoint]?

    enum CodingKeys: String, CodingKey {
        case firstVo2Max = "first_vo2_max"
        case latestVo2Max = "latest_vo2_max"
        case change
        case trend
    }
}

struct VO2MaxPoint: Codable, Identifiable {
    var id: String { date }
    let date: String
    let vo2Max: Double?

    enum CodingKeys: String, CodingKey {
        case date
        case vo2Max = "vo2_max"
    }
}

struct LactateThreshold: Codable {
    let lactateThresholdSpeedMps: Double?
    let lactateThresholdHeartRateBpm: Int?
    let functionalThresholdPowerWatts: Int?
    let weightKg: Double?
    let speedHrDate: String?

    enum CodingKeys: String, CodingKey {
        case lactateThresholdSpeedMps = "lactate_threshold_speed_mps"
        case lactateThresholdHeartRateBpm = "lactate_threshold_heart_rate_bpm"
        case functionalThresholdPowerWatts = "functional_threshold_power_watts"
        case weightKg = "weight_kg"
        case speedHrDate = "speed_hr_date"
    }
}

struct RacePredictionsResponse: Codable {
    let predictionDate: String?
    let predictions: [String: RacePredictionEntry]?

    enum CodingKeys: String, CodingKey {
        case predictionDate = "prediction_date"
        case predictions
    }
}

struct RacePredictionEntry: Codable {
    let time: String?
    let timeSeconds: Int?

    enum CodingKeys: String, CodingKey {
        case time
        case timeSeconds = "time_seconds"
    }
}

struct HRZoneDefinition: Codable, Identifiable {
    var id: String { sport ?? trainingMethod ?? UUID().uuidString }
    let trainingMethod: String?
    let sport: String?
    let restingHeartRateUsed: Int?
    let lactateThresholdHeartRateUsed: Int?
    let maxHeartRateUsed: Int?
    let zone1Floor: Int?
    let zone2Floor: Int?
    let zone3Floor: Int?
    let zone4Floor: Int?
    let zone5Floor: Int?

    var bands: [(zone: Int, range: String)] {
        guard let z1 = zone1Floor, let z2 = zone2Floor, let z3 = zone3Floor,
              let z4 = zone4Floor, let z5 = zone5Floor else { return [] }
        let maxHR = maxHeartRateUsed ?? (z5 + 20)
        return [
            (1, "\(z1)–\(z2 - 1)"),
            (2, "\(z2)–\(z3 - 1)"),
            (3, "\(z3)–\(z4 - 1)"),
            (4, "\(z4)–\(z5 - 1)"),
            (5, "\(z5)–\(maxHR)")
        ]
    }
}

// MARK: - Gear & Devices

struct GearResponse: Codable {
    let gearCount: Int?
    let defaults: [String: [String]]?
    let gear: [GearItem]?

    enum CodingKeys: String, CodingKey {
        case gearCount = "gear_count"
        case defaults
        case gear
    }
}

struct GearItem: Codable, Identifiable {
    var id: String { uuid }
    let uuid: String
    let name: String?
    let fullName: String?
    let type: String?
    let status: String?
    let dateBegin: String?
    let maxDistanceKm: Double?
    let isDefaultFor: [String]?
    let stats: GearStats?

    enum CodingKeys: String, CodingKey {
        case uuid, name, type, status
        case fullName = "full_name"
        case dateBegin = "date_begin"
        case maxDistanceKm = "max_distance_km"
        case isDefaultFor = "is_default_for"
        case stats
    }

    var displayTitle: String {
        if let name, !name.isEmpty, let fullName, !fullName.isEmpty {
            return "\(fullName) · \(name)"
        }
        return fullName ?? name ?? uuid
    }
}

struct GearStats: Codable {
    let totalActivities: Int?
    let totalDistanceKm: Double?

    enum CodingKeys: String, CodingKey {
        case totalActivities = "total_activities"
        case totalDistanceKm = "total_distance_km"
    }
}

struct GarminDevice: Codable, Identifiable {
    var id: String { String(deviceId ?? 0) }
    let deviceId: Int?
    let deviceName: String?
    let model: String?
    let softwareVersion: String?
    let status: String?
    let lastSyncTime: String?
    let isPrimary: Bool?

    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case deviceName = "device_name"
        case model
        case softwareVersion = "software_version"
        case status
        case lastSyncTime = "last_sync_time"
        case isPrimary = "is_primary"
    }
}

struct DeviceLastUsed: Codable {
    let userDeviceId: Int?
    let deviceName: String?
    let lastUploadTime: String?

    enum CodingKeys: String, CodingKey {
        case userDeviceId = "user_device_id"
        case deviceName = "device_name"
        case lastUploadTime = "last_upload_time"
    }
}

// MARK: - Workouts, Coach & Calendar

struct WorkoutsResponse: Codable {
    let count: Int?
    let workouts: [WorkoutSummary]?
}

struct WorkoutSummary: Codable, Identifiable {
    let id: Int
    let name: String?
    let sport: String?
    let createdDate: String?
    let description: String?
    let estimatedDurationSeconds: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, sport, description
        case createdDate = "created_date"
        case estimatedDurationSeconds = "estimated_duration_seconds"
    }
}

struct CoachWorkoutsResponse: Codable {
    let trainingPlans: [String]?
    let plans: [CoachPlan]?
    let workouts: [CoachWorkoutItem]?

    enum CodingKeys: String, CodingKey {
        case trainingPlans = "training_plans"
        case plans, workouts
    }
}

struct CoachPlan: Codable, Identifiable {
    var id: Int { trainingPlanId ?? 0 }
    let name: String?
    let trainingPlanId: Int?
    let raceDay: String?
    let workoutsPerWeek: Int?

    enum CodingKeys: String, CodingKey {
        case name
        case trainingPlanId = "training_plan_id"
        case raceDay = "race_day"
        case workoutsPerWeek = "workouts_per_week"
    }
}

struct CoachWorkoutItem: Codable, Identifiable {
    var id: String { workoutUuid ?? "\(date ?? "")-\(name ?? "")" }
    let date: String?
    let workoutUuid: String?
    let name: String?
    let sport: String?
    let completed: Bool?
    let workoutType: String?
    let estimatedDurationSeconds: Int?

    enum CodingKeys: String, CodingKey {
        case date, name, sport, completed
        case workoutUuid = "workout_uuid"
        case workoutType = "workout_type"
        case estimatedDurationSeconds = "estimated_duration_seconds"
    }
}

struct ScheduledWorkoutsResponse: Codable {
    let workouts: [ScheduledWorkoutItem]?
    let scheduledWorkouts: [ScheduledWorkoutItem]?

    enum CodingKeys: String, CodingKey {
        case workouts
        case scheduledWorkouts = "scheduled_workouts"
    }

    var allItems: [ScheduledWorkoutItem] {
        workouts ?? scheduledWorkouts ?? []
    }
}

struct ScheduledWorkoutItem: Codable, Identifiable {
    var id: String { workoutUuid ?? "\(workoutId ?? 0)-\(date ?? "")-\(workoutScheduleId ?? 0)-\(name ?? "")" }
    let workoutScheduleId: Int?
    let workoutId: Int?
    let workoutUuid: String?
    let date: String?
    let name: String?
    let workoutName: String?
    let sport: String?

    enum CodingKeys: String, CodingKey {
        case workoutScheduleId = "workout_schedule_id"
        case workoutId = "workout_id"
        case workoutUuid = "workout_uuid"
        case date, name, sport
        case workoutName = "workout_name"
    }
}

struct CalendarEventsResponse: Codable {
    let events: [CalendarEventItem]?
}

struct CalendarEventItem: Codable, Identifiable {
    var id: String { "\(eventId ?? 0)-\(date ?? "")-\(title ?? "")" }
    let eventId: Int?
    let date: String?
    let title: String?
    let eventType: String?
    let location: String?

    enum CodingKeys: String, CodingKey {
        case eventId = "event_id"
        case date, title, location
        case eventType = "event_type"
    }
}

// MARK: - Activities & Telemetry

struct ActivitiesPageResponse: Codable {
    let start: Int?
    let limit: Int?
    let count: Int?
    let hasMore: Bool?
    let activities: [ActivityItem]

    enum CodingKeys: String, CodingKey {
        case start, limit, count, activities
        case hasMore = "has_more"
    }
}

struct ActivityItem: Codable, Identifiable, Hashable {
    let id: Int
    let name: String?
    let type: String?
    let eventType: String?
    let startTime: String?
    let distanceMeters: Double?
    let durationSeconds: Double?
    let movingDurationSeconds: Double?
    let calories: Double?
    let avgHrBpm: Double?
    let maxHrBpm: Double?
    let steps: Int?
    let elevationGainMeters: Double?
    let elevationLossMeters: Double?

    enum CodingKeys: String, CodingKey {
        case id, name, type, calories, steps
        case eventType = "event_type"
        case startTime = "start_time"
        case distanceMeters = "distance_meters"
        case durationSeconds = "duration_seconds"
        case movingDurationSeconds = "moving_duration_seconds"
        case avgHrBpm = "avg_hr_bpm"
        case maxHrBpm = "max_hr_bpm"
        case elevationGainMeters = "elevation_gain_meters"
        case elevationLossMeters = "elevation_loss_meters"
    }

    var avgPaceSecPerKm: Double? {
        guard let d = distanceMeters, let dur = durationSeconds, d > 10, dur > 0 else { return nil }
        return dur / (d / 1000.0)
    }

    var shortDate: String {
        guard let s = startTime else { return "" }
        return String(s.prefix(16))
    }
}

struct ActivityDetailBundle: Codable {
    let activityId: Int
    let fetchedAt: String
    let summary: ActivityRawSummary?
    let splits: ActivitySplitsDTO?
    let weather: ActivityWeatherDTO?
    let hrZones: [ActivityHRZoneBucket]?
    let gear: [ActivityGearDTO]?
    let telemetryPoints: [TelemetryPoint]
    let polyline: [[Double]]
    let errors: [String: SectionError]?

    enum CodingKeys: String, CodingKey {
        case activityId = "activity_id"
        case fetchedAt = "fetched_at"
        case summary, splits, weather, gear, polyline, errors
        case hrZones = "hr_zones"
        case telemetryPoints = "telemetry_points"
    }
}

struct ActivityRawSummary: Codable {
    let activityName: String?
    let locationName: String?
    let summaryDTO: ActivitySummaryDTO?
}

struct ActivitySummaryDTO: Codable {
    let distance: Double?
    let duration: Double?
    let movingDuration: Double?
    let averageSpeed: Double?
    let maxSpeed: Double?
    let averageHR: Double?
    let maxHR: Double?
    let averageRunCadence: Double?
    let maxRunCadence: Double?
    let averagePower: Double?
    let trainingEffect: Double?
    let anaerobicTrainingEffect: Double?
    let trainingEffectLabel: String?
    let activityTrainingLoad: Double?
    let calories: Double?
    let elevationGain: Double?
    let elevationLoss: Double?
    let directWorkoutFeel: Int?
    let directWorkoutRpe: Int?
    let strideLength: Double?
    let groundContactTime: Double?
    let verticalOscillation: Double?
}

struct ActivitySplitsDTO: Codable {
    let lapDTOs: [ActivityLapDTO]?
}

struct ActivityLapDTO: Codable, Identifiable {
    var id: Int { lapIndex ?? Int((startTimeGMT ?? "").hashValue) }
    let lapIndex: Int?
    let startTimeGMT: String?
    let distance: Double?
    let duration: Double?
    let movingDuration: Double?
    let averageSpeed: Double?
    let averageHR: Double?
    let maxHR: Double?
    let averageRunCadence: Double?
    let elevationGain: Double?
    let elevationLoss: Double?
    let averagePower: Double?
    let intensityType: String?
}

struct ActivityWeatherDTO: Codable {
    let temp: Double?
    let apparentTemp: Double?
    let relativeHumidity: Double?
    let windSpeed: Double?
    let windDirectionCompassPoint: String?
    let weatherTypeDTO: WeatherTypeDTO?
}

struct WeatherTypeDTO: Codable {
    let desc: String?
}

struct ActivityHRZoneBucket: Codable, Identifiable {
    var id: Int { zoneNumber ?? 0 }
    let zoneNumber: Int?
    let secsInZone: Double?
    let zoneLowBoundary: Int?
}

struct ActivityGearDTO: Codable, Identifiable {
    var id: String { uuid ?? (customMakeModel ?? "gear") }
    let uuid: String?
    let gearMakeName: String?
    let gearModelName: String?
    let displayName: String?
    let customMakeModel: String?

    var title: String {
        if let customMakeModel, !customMakeModel.isEmpty { return customMakeModel }
        let combo = [gearMakeName, gearModelName].compactMap { $0 }.joined(separator: " ")
        return combo.isEmpty ? (displayName ?? uuid ?? "Unknown") : combo
    }
}

struct TelemetryPoint: Codable, Identifiable {
    var id: Double { t }
    let t: Double
    let dist: Double?
    let hr: Double?
    let pace: Double?
    let speed: Double?
    let cadence: Double?
    let elev: Double?
    let power: Double?
    let lat: Double?
    let lon: Double?
}

// MARK: - Workout Builder Models

struct WorkoutInspectResponse: Codable {
    let workoutId: Int
    let name: String?
    let description: String?
    let sport: String?
    let estimatedDurationSeconds: Int?
    let steps: [EditableWorkoutStep]

    enum CodingKeys: String, CodingKey {
        case workoutId = "workout_id"
        case name, description, sport, steps
        case estimatedDurationSeconds = "estimated_duration_seconds"
    }
}

struct EditableWorkoutStep: Codable, Identifiable {
    var id: UUID = UUID()
    var kind: String // warmup, interval, recovery, cooldown, rest, repeat
    var endType: String = "time" // time, distance, lap_button
    var seconds: Int = 300
    var meters: Int = 1000
    var targetType: String = "none" // none, pace, hr
    var paceFastSec: Int = 255
    var paceSlowSec: Int = 270
    var hrLow: Int = 135
    var hrHigh: Int = 155
    var note: String = ""
    var iterations: Int = 4
    var steps: [EditableWorkoutStep] = []

    enum CodingKeys: String, CodingKey {
        case kind, seconds, meters, note, iterations, steps
        case endType = "end_type"
        case targetType = "target_type"
        case paceFastSec = "pace_fast_sec"
        case paceSlowSec = "pace_slow_sec"
        case hrLow = "hr_low"
        case hrHigh = "hr_high"
    }

    init(
        kind: String = "interval",
        endType: String = "time",
        seconds: Int = 300,
        meters: Int = 1000,
        targetType: String = "none",
        paceFastSec: Int = 255,
        paceSlowSec: Int = 270,
        hrLow: Int = 135,
        hrHigh: Int = 155,
        note: String = "",
        iterations: Int = 4,
        steps: [EditableWorkoutStep] = []
    ) {
        self.kind = kind
        self.endType = endType
        self.seconds = seconds
        self.meters = meters
        self.targetType = targetType
        self.paceFastSec = paceFastSec
        self.paceSlowSec = paceSlowSec
        self.hrLow = hrLow
        self.hrHigh = hrHigh
        self.note = note
        self.iterations = iterations
        self.steps = steps
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.kind = try c.decode(String.self, forKey: .kind)
        self.endType = try c.decodeIfPresent(String.self, forKey: .endType) ?? "time"
        self.seconds = try c.decodeIfPresent(Int.self, forKey: .seconds) ?? 300
        self.meters = try c.decodeIfPresent(Int.self, forKey: .meters) ?? 1000
        self.targetType = try c.decodeIfPresent(String.self, forKey: .targetType) ?? "none"
        self.paceFastSec = try c.decodeIfPresent(Int.self, forKey: .paceFastSec) ?? 255
        self.paceSlowSec = try c.decodeIfPresent(Int.self, forKey: .paceSlowSec) ?? 270
        self.hrLow = try c.decodeIfPresent(Int.self, forKey: .hrLow) ?? 135
        self.hrHigh = try c.decodeIfPresent(Int.self, forKey: .hrHigh) ?? 155
        self.note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        self.iterations = try c.decodeIfPresent(Int.self, forKey: .iterations) ?? 4
        self.steps = try c.decodeIfPresent([EditableWorkoutStep].self, forKey: .steps) ?? []
    }

    func toSpecDict() -> [String: Any] {
        if kind == "repeat" {
            return [
                "kind": "repeat",
                "iterations": iterations,
                "steps": steps.map { $0.toSpecDict() }
            ]
        }
        var dict: [String: Any] = [
            "kind": kind,
            "end_type": endType,
            "note": note,
            "target_type": targetType
        ]
        if endType == "time" { dict["seconds"] = seconds }
        if endType == "distance" { dict["meters"] = meters }
        if targetType == "pace" {
            dict["pace_fast_sec"] = paceFastSec
            dict["pace_slow_sec"] = paceSlowSec
        } else if targetType == "hr" {
            dict["hr_low"] = hrLow
            dict["hr_high"] = hrHigh
        }
        return dict
    }
}

// MARK: - Generic JSON Helper for Flexible Endpoints (e.g. Personal Records)

enum AnyCodableValue: Codable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([AnyCodableValue])
    case object([String: AnyCodableValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else if let n = try? container.decode(Double.self) {
            self = .number(n)
        } else if let s = try? container.decode(String.self) {
            self = .string(s)
        } else if let a = try? container.decode([AnyCodableValue].self) {
            self = .array(a)
        } else if let o = try? container.decode([String: AnyCodableValue].self) {
            self = .object(o)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .number(let n): try container.encode(n)
        case .bool(let b): try container.encode(b)
        case .array(let a): try container.encode(a)
        case .object(let o): try container.encode(o)
        case .null: try container.encodeNil()
        }
    }

    var arrayValue: [AnyCodableValue]? {
        if case .array(let a) = self { return a }
        if case .object(let o) = self {
            for key in ["records", "personal_records", "items", "data"] {
                if case .array(let a)? = o[key] { return a }
            }
        }
        return nil
    }

    var objectValue: [String: AnyCodableValue]? {
        if case .object(let o) = self { return o }
        return nil
    }

    var stringValue: String? {
        switch self {
        case .string(let s): return s
        case .number(let n): return n.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(n)) : String(n)
        default: return nil
        }
    }

    var doubleValue: Double? {
        switch self {
        case .number(let n): return n
        case .string(let s): return Double(s)
        default: return nil
        }
    }
}
