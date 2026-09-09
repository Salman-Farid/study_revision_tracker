import WidgetKit
import SwiftUI

struct DailyRoutineTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailyRoutineEntry {
        DailyRoutineEntry(date: Date(), data: .empty)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (DailyRoutineEntry) -> Void) {
        let entry = DailyRoutineEntry(date: Date(), data: WidgetDataProvider.loadDailyRoutine())
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyRoutineEntry>) -> Void) {
        let data = WidgetDataProvider.loadDailyRoutine()
        let entry = DailyRoutineEntry(date: Date(), data: data)
        
        // Update every 15 minutes for battery efficiency
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct DailyRoutineEntry: TimelineEntry {
    let date: Date
    let data: WidgetDataProvider.DailyRoutineData
}

struct DailyRoutineWidgetEntryView: View {
    var entry: DailyRoutineTimelineProvider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(red: 0.53, green: 0.81, blue: 0.92))
                
                Text("Daily Routine")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                if entry.data.hasData && !entry.data.currentSubject.isEmpty {
                    Text("LIVE")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.green.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            .padding(.bottom, 6)
            
            if entry.data.hasData && !entry.data.currentSubject.isEmpty {
                // Current activity card
                VStack(alignment: .leading, spacing: 3) {
                    if !entry.data.currentType.isEmpty {
                        Text(WidgetDataProvider.formatTypeLabel(entry.data.currentType))
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 0.53, green: 0.81, blue: 0.92))
                    }
                    
                    Text(entry.data.currentSubject)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    if !entry.data.currentTopic.isEmpty {
                        Text(entry.data.currentTopic)
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    
                    HStack {
                        Text(entry.data.currentTime)
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(.tertiary)
                        
                        Spacer()
                        
                        if !entry.data.remaining.isEmpty {
                            Text(entry.data.remaining)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.green)
                        }
                    }
                }
                .padding(8)
                .background(Color(red: 0.53, green: 0.81, blue: 0.92).opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.bottom, 4)
                
                // Next activity
                if !entry.data.nextSubject.isEmpty {
                    HStack(spacing: 4) {
                        Text("NEXT")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundStyle(.tertiary)
                        
                        Text(entry.data.nextSubject)
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(entry.data.nextTime)
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }
                }
            } else if entry.data.hasData {
                // Has data but no current activity
                Text(entry.data.statusMessage)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Empty state
                VStack(spacing: 6) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 24))
                        .foregroundStyle(.tertiary.opacity(0.5))
                    
                    Text(entry.data.statusMessage)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(12)
    }
}

struct DailyRoutineWidget: Widget {
    let kind: String = "DailyRoutineWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailyRoutineTimelineProvider()) { entry in
            DailyRoutineWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Daily Routine")
        .description("Shows your current daily routine activity with time remaining.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
