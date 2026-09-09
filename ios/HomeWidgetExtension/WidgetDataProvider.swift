import Foundation
import WidgetKit

/// Shared data provider for reading widget data from UserDefaults (App Group).
struct WidgetDataProvider {
    static let appGroupId = "group.HOMEWIDGET"
    
    static func sharedDefaults() -> UserDefaults? {
        UserDefaults(suiteName: appGroupId)
    }
    
    // MARK: - Daily Routine
    
    struct DailyRoutineData {
        let hasData: Bool
        let statusMessage: String
        let currentSubject: String
        let currentTopic: String
        let currentType: String
        let currentTime: String
        let remaining: String
        let nextSubject: String
        let nextTime: String
        
        static let empty = DailyRoutineData(
            hasData: false,
            statusMessage: "No routine set for today",
            currentSubject: "", currentTopic: "", currentType: "",
            currentTime: "", remaining: "", nextSubject: "", nextTime: ""
        )
    }
    
    static func loadDailyRoutine() -> DailyRoutineData {
        guard let defaults = sharedDefaults() else { return .empty }
        return DailyRoutineData(
            hasData: defaults.bool(forKey: "widget_daily_has_data"),
            statusMessage: defaults.string(forKey: "widget_daily_status_message") ?? "No routine set",
            currentSubject: defaults.string(forKey: "widget_daily_current_subject") ?? "",
            currentTopic: defaults.string(forKey: "widget_daily_current_topic") ?? "",
            currentType: defaults.string(forKey: "widget_daily_current_type") ?? "",
            currentTime: defaults.string(forKey: "widget_daily_current_time") ?? "",
            remaining: defaults.string(forKey: "widget_daily_remaining") ?? "",
            nextSubject: defaults.string(forKey: "widget_daily_next_subject") ?? "",
            nextTime: defaults.string(forKey: "widget_daily_next_time") ?? ""
        )
    }
    
    // MARK: - Revision
    
    struct RevisionData {
        let hasData: Bool
        let statusMessage: String
        let overdueCount: Int
        let todayCount: Int
        let upcomingCount: Int
        
        static let empty = RevisionData(
            hasData: false,
            statusMessage: "No revisions scheduled",
            overdueCount: 0, todayCount: 0, upcomingCount: 0
        )
    }
    
    static func loadRevisionData() -> RevisionData {
        guard let defaults = sharedDefaults() else { return .empty }
        return RevisionData(
            hasData: defaults.bool(forKey: "widget_revision_has_data"),
            statusMessage: defaults.string(forKey: "widget_revision_status_message") ?? "No revisions",
            overdueCount: defaults.integer(forKey: "widget_revision_overdue_count"),
            todayCount: defaults.integer(forKey: "widget_revision_today_count"),
            upcomingCount: defaults.integer(forKey: "widget_revision_upcoming_count")
        )
    }
    
    // MARK: - Class Routine
    
    struct ClassRoutineData {
        let hasToday: Bool
        let statusMessage: String
        let currentSubject: String
        let currentTime: String
        let currentLocation: String
        let currentRemaining: String
        let nextSubject: String
        let nextTime: String
        let nextLocation: String
        
        static let empty = ClassRoutineData(
            hasToday: false,
            statusMessage: "No classes today",
            currentSubject: "", currentTime: "", currentLocation: "",
            currentRemaining: "", nextSubject: "", nextTime: "", nextLocation: ""
        )
    }
    
    static func loadClassRoutine() -> ClassRoutineData {
        guard let defaults = sharedDefaults() else { return .empty }
        return ClassRoutineData(
            hasToday: defaults.bool(forKey: "widget_class_has_today"),
            statusMessage: defaults.string(forKey: "widget_class_status_message") ?? "No classes",
            currentSubject: defaults.string(forKey: "widget_class_current_subject") ?? "",
            currentTime: defaults.string(forKey: "widget_class_current_time") ?? "",
            currentLocation: defaults.string(forKey: "widget_class_current_location") ?? "",
            currentRemaining: defaults.string(forKey: "widget_class_current_end_time") ?? "",
            nextSubject: defaults.string(forKey: "widget_class_next_subject") ?? "",
            nextTime: defaults.string(forKey: "widget_class_next_time") ?? "",
            nextLocation: defaults.string(forKey: "widget_class_next_location") ?? ""
        )
    }
    
    // MARK: - Helpers
    
    static func formatTypeLabel(_ type: String) -> String {
        switch type {
        case "study": return "Study"
        case "revision": return "Revision"
        case "first_read": return "First Read"
        case "class": return "Class"
        case "break": return "Break"
        case "meal": return "Meal"
        case "nap": return "Power Nap"
        case "recall": return "Active Recall"
        case "question_practice": return "Questions"
        case "review": return "Review"
        default: return type.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}
