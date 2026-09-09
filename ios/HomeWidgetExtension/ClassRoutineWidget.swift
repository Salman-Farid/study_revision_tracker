import WidgetKit
import SwiftUI

struct ClassRoutineTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> ClassRoutineEntry {
        ClassRoutineEntry(date: Date(), data: .empty)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (ClassRoutineEntry) -> Void) {
        let entry = ClassRoutineEntry(date: Date(), data: WidgetDataProvider.loadClassRoutine())
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<ClassRoutineEntry>) -> Void) {
        let data = WidgetDataProvider.loadClassRoutine()
        let entry = ClassRoutineEntry(date: Date(), data: data)
        
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct ClassRoutineEntry: TimelineEntry {
    let date: Date
    let data: WidgetDataProvider.ClassRoutineData
}

struct ClassRoutineWidgetEntryView: View {
    var entry: ClassRoutineTimelineProvider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 4) {
                Image(systemName: "building.2")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(red: 0.53, green: 0.81, blue: 0.92))
                
                Text("Class Routine")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                if entry.data.hasToday && !entry.data.currentSubject.isEmpty {
                    Text("NOW")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.green.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            .padding(.bottom, 6)
            
            if entry.data.hasToday && !entry.data.currentSubject.isEmpty {
                // Current class card
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.data.currentSubject)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    HStack {
                        Text(entry.data.currentTime)
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(.tertiary)
                        
                        Spacer()
                        
                        if !entry.data.currentRemaining.isEmpty {
                            Text(entry.data.currentRemaining)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.green)
                        }
                    }
                    
                    if !entry.data.currentLocation.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "mappin")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                            Text(entry.data.currentLocation)
                                .font(.system(size: 10, design: .rounded))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(8)
                .background(Color(red: 0.53, green: 0.81, blue: 0.92).opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.bottom, 4)
                
                // Next class
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
            } else if entry.data.hasToday {
                Text(entry.data.statusMessage)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Empty state
                VStack(spacing: 6) {
                    Image(systemName: "building.2.crop.circle")
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

struct ClassRoutineWidget: Widget {
    let kind: String = "ClassRoutineWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ClassRoutineTimelineProvider()) { entry in
            ClassRoutineWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Class Routine")
        .description("Shows your current or next class with subject, time, and location.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
