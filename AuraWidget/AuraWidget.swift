import Foundation
import WidgetKit
import SwiftUI

struct AuraEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

let sampleWidgetSnapshot = WidgetSnapshot(
    accountID: "sample",
    balance: 2480,
    streakDays: 6,
    lastQualifiedDay: widgetDayNumber(for: Date()),
    questDay: widgetDayNumber(for: Date()),
    questProgress: 3,
    questTarget: 5,
    questClaimedDay: 0,
    updatedAt: Date()
)

struct AuraProvider: TimelineProvider {
    func placeholder(in context: Context) -> AuraEntry {
        AuraEntry(date: Date(), snapshot: sampleWidgetSnapshot)
    }

    func getSnapshot(in context: Context, completion: @escaping (AuraEntry) -> Void) {
        let stored = storedSnapshot()
        completion(AuraEntry(date: Date(), snapshot: context.isPreview ? stored ?? sampleWidgetSnapshot : stored))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AuraEntry>) -> Void) {
        let now = Date()
        let nextDay = startOfNextWidgetDay(after: now)
        let entries = [
            AuraEntry(date: now, snapshot: storedSnapshot()),
            AuraEntry(date: nextDay, snapshot: storedSnapshot()),
        ]
        completion(Timeline(entries: entries, policy: .after(nextDay)))
    }

    private func storedSnapshot() -> WidgetSnapshot? {
        decodeWidgetSnapshot(UserDefaults(suiteName: WidgetConfig.appGroupID)?.data(forKey: WidgetConfig.snapshotKey))
    }
}

struct AuraWidgetView: View {
    let entry: AuraEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let snapshot = entry.snapshot {
            HStack(alignment: .top, spacing: AuraSpacing.large) {
                progressColumn(snapshot)
                if family == .systemMedium {
                    Spacer(minLength: 0)
                    pointsColumn(snapshot)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: AuraSpacing.small) {
                Text("Aura")
                    .font(.auraCardTitle)
                    .foregroundStyle(Color.auraText)
                Text("Open Aura to sign in and see your streak.")
                    .font(.auraNotice)
                    .foregroundStyle(Color.auraMuted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func progressColumn(_ snapshot: WidgetSnapshot) -> some View {
        let today = widgetDayNumber(for: entry.date)
        let streak = widgetStreak(snapshot, today: today)
        let progress = widgetQuestProgress(snapshot, today: today)

        return VStack(alignment: .leading, spacing: AuraSpacing.xxSmall) {
            HStack(spacing: AuraSpacing.xxSmall) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(Color.auraMagenta)
                Text("\(streak)")
                    .font(.auraHeading)
                    .foregroundStyle(Color.auraText)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("\(streak) day streak"))
            Text("day streak")
                .font(.auraErrorText)
                .foregroundStyle(Color.auraMuted)
                .accessibilityHidden(true)

            Spacer(minLength: 0)

            Text(widgetQuestText(snapshot, today: today))
                .font(.auraChipSelected)
                .foregroundStyle(Color.auraText)
            ProgressView(value: Double(progress), total: Double(max(1, snapshot.questTarget)))
                .tint(Color.auraMint)
                .accessibilityHidden(true)
            Text("Updated \(snapshot.updatedAt, style: .relative) ago")
                .font(.auraErrorText)
                .foregroundStyle(Color.auraMuted)
                .lineLimit(1)
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    private func pointsColumn(_ snapshot: WidgetSnapshot) -> some View {
        VStack(alignment: .trailing, spacing: AuraSpacing.xxSmall) {
            Text("\(snapshot.balance.formatted())")
                .font(.auraHeading)
                .foregroundStyle(Color.auraText)
            Text("points")
                .font(.auraErrorText)
                .foregroundStyle(Color.auraMuted)
        }
        .accessibilityElement(children: .combine)
    }
}

struct AuraWidget: Widget {
    let kind = "AuraWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AuraProvider()) { entry in
            AuraWidgetView(entry: entry)
                .containerBackground(Color.auraBackground, for: .widget)
                .widgetURL(URL(string: WidgetConfig.questsLink))
        }
        .configurationDisplayName("Aura streak")
        .description("Your streak, today's quest and points.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    AuraWidget()
} timeline: {
    AuraEntry(date: .now, snapshot: sampleWidgetSnapshot)
    AuraEntry(date: .now, snapshot: nil)
}
