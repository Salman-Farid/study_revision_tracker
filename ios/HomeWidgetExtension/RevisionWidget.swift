import WidgetKit
import SwiftUI

struct RevisionTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> RevisionEntry {
        RevisionEntry(date: Date(), data: .empty)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (RevisionEntry) -> Void) {
        let entry = RevisionEntry(date: Date(), data: WidgetDataProvider.loadRevisionData())
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<RevisionEntry>) -> Void) {
        let data = WidgetDataProvider.loadRevisionData()
        let entry = RevisionEntry(date: Date(), data: data)
        
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct RevisionEntry: TimelineEntry {
    let date: Date
    let data: WidgetDataProvider.RevisionData
}

struct RevisionWidgetEntryView: View {
    var entry: RevisionTimelineProvider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(red: 0.53, green: 0.81, blue: 0.92))
                
                Text("Revisions")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                
                Spacer()
            }
            .padding(.bottom, 6)
            
            if entry.data.hasData {
                // Stats row
                HStack(spacing: 0) {
                    if entry.data.overdueCount > 0 {
                        VStack(spacing: 2) {
                            Text("\(entry.data.overdueCount)")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(.red)
                            Text("Overdue")
                                .font(.system(size: 9, design: .rounded))
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    
                    if entry.data.todayCount > 0 {
                        VStack(spacing: 2) {
                            Text("\(entry.data.todayCount)")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(red: 0.53, green: 0.81, blue: 0.92))
                            Text("Today")
                                .font(.system(size: 9, design: .rounded))
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    
                    if entry.data.upcomingCount > 0 {
                        VStack(spacing: 2) {
                            Text("\(entry.data.upcomingCount)")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(.secondary)
                            Text("Upcoming")
                                .font(.system(size: 9, design: .rounded))
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.bottom, 6)
                
                // Status message
                Text(entry.data.statusMessage)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                // Empty state
                VStack(spacing: 6) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 24))
                        .foregroundStyle(.green.opacity(0.6))
                    
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

struct RevisionWidget: Widget {
    let kind: String = "RevisionWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RevisionTimelineProvider()) { entry in
            RevisionWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Revisions")
        .description("Shows overdue, today's, and upcoming revision tasks.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
