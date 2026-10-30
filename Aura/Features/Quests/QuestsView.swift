import SwiftUI

struct QuestsView: View {
    let statsStore: StatsStore
    let shop: ShopStore

    private var stats: UserStats { statsStore.stats ?? UserStats() }
    private var today: Int { statsStore.today }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AuraSpacing.medium) {
                    HStack {
                        Text("Daily quests")
                            .font(.auraScreenTitle)
                            .foregroundStyle(Color.auraText)
                        Spacer()
                        let streak = displayedStreak(stats, today: today)
                        if streak > 0 {
                            AuraPill(text: "\(streak) day streak")
                        }
                    }

                    PointsSummaryCard(stats: stats)

                    todaysQuestsSection

                    QuestRow(
                        systemImage: "mappin.and.ellipse",
                        title: "Discover new walls",
                        detail: "+\(discoveryRewardPoints) pts for each wall you open for the first time within 50 m. \(stats.discoveryCount) found so far."
                    )

                    NavigationLink {
                        RewardsView(shop: shop, statsStore: statsStore)
                    } label: {
                        QuestRow(
                            systemImage: "gift",
                            title: "Rewards shop",
                            detail: "Spend points on the Neon brush and streak freezes."
                        )
                    }
                    .buttonStyle(AuraBounceButtonStyle())

                    NavigationLink {
                        BadgesView(stats: stats)
                    } label: {
                        QuestRow(
                            systemImage: "rosette",
                            title: "Badges",
                            detail: "\(badges(for: stats).filter(\.isEarned).count) of \(badges(for: stats).count) earned"
                        )
                    }
                    .buttonStyle(AuraBounceButtonStyle())
                }
                .padding(AuraSpacing.screen)
            }
            .background(Color.auraBackground)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var todaysQuestsSection: some View {
        VStack(alignment: .leading, spacing: AuraSpacing.small) {
            Text("Today's quests")
                .font(.auraMidLabel)
                .foregroundStyle(Color.auraMuted)

            ForEach(statsStore.todaysQuests) { quest in
                QuestCard(
                    quest: quest,
                    state: statsStore.state(of: quest),
                    isClaiming: statsStore.claimingQuestID == quest.id,
                    isBusy: statsStore.claimingQuestID != nil,
                    onClaim: { Task { await statsStore.claimQuest(quest) } }
                )
            }

            if let message = statsStore.questMessage {
                Text(message)
                    .font(.auraMidNotice)
                    .foregroundStyle(Color.auraText)
            }

            Text("New quests appear every day at midnight, Colombo time.")
                .font(.auraMidSmall)
                .foregroundStyle(Color.auraMuted)
        }
    }
}

private struct QuestCard: View {
    let quest: Quest
    let state: QuestState
    let isClaiming: Bool
    let isBusy: Bool
    let onClaim: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AuraSpacing.small) {
            HStack(spacing: AuraSpacing.medium) {
                Image(systemName: quest.systemImage)
                    .foregroundStyle(Color.auraInk)
                    .frame(width: AuraSize.messageSwatch, height: AuraSize.messageSwatch)
                    .background(state == .claimed ? Color.auraMint : Color.auraYellow, in: .rect(cornerRadius: AuraRadius.swatch))
                    .symbolEffect(.bounce, value: state == .claimed)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: AuraSpacing.xxSmall) {
                    Text(quest.title)
                        .font(.auraMidCardTitle)
                        .foregroundStyle(Color.auraText)
                    Text(questStatusText(quest, state: state))
                        .font(.auraMidNotice)
                        .foregroundStyle(Color.auraMuted)
                }
                Spacer(minLength: 0)
            }

            Text(quest.detail)
                .font(.auraMidSmall)
                .foregroundStyle(Color.auraMuted)

            ProgressView(value: Double(progress), total: Double(quest.target))
                .tint(Color.auraMint)
                .accessibilityLabel("\(quest.title) progress")

            if state == .readyToClaim {
                Button {
                    onClaim()
                } label: {
                    if isClaiming {
                        ProgressView().tint(Color.auraInk)
                    } else {
                        Text("Claim +\(quest.reward) pts")
                    }
                }
                .buttonStyle(AuraButtonStyle(kind: .highlight))
                .disabled(isBusy)
            }
        }
        .padding(AuraSpacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.auraCard, in: .rect(cornerRadius: AuraRadius.card))
        .sensoryFeedback(.success, trigger: state == .claimed) { _, isClaimed in isClaimed }
        .auraPopIn()
    }

    private var progress: Int {
        switch state {
        case .inProgress(let value): value
        case .readyToClaim, .claimed: quest.target
        }
    }
}

struct PointsSummaryCard: View {
    let stats: UserStats

    var body: some View {
        VStack(alignment: .leading, spacing: AuraSpacing.small) {
            HStack {
                StatColumn(value: formattedPoints(stats.balance), label: "Balance")
                Spacer()
                StatColumn(value: "Lv \(level(forXP: stats.lifetimeXP))", label: "\(stats.lifetimeXP) XP")
                Spacer()
                StatColumn(value: "\(stats.discoveryCount)", label: "Walls found")
            }
            if let progress = levelProgress(forXP: stats.lifetimeXP) {
                ProgressView(value: Double(progress.current), total: Double(progress.needed))
                    .tint(Color.auraMint)
                Text("\(progress.current) / \(progress.needed) XP to level \(level(forXP: stats.lifetimeXP) + 1)")
                    .font(.auraMidSmall)
                    .foregroundStyle(Color.auraMuted)
            }
        }
        .padding(AuraSpacing.medium)
        .background(Color.auraCard, in: .rect(cornerRadius: AuraRadius.card))
        .auraPopIn()
    }
}

private struct StatColumn: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: AuraSpacing.xxSmall) {
            Text(value)
                .font(.auraMidCardTitle)
                .foregroundStyle(Color.auraText)
            Text(label)
                .font(.auraMidSmall)
                .foregroundStyle(Color.auraMuted)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct QuestRow: View {
    let systemImage: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: AuraSpacing.medium) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.auraInk)
                .frame(width: AuraSize.messageSwatch, height: AuraSize.messageSwatch)
                .background(Color.auraYellow, in: .rect(cornerRadius: AuraRadius.swatch))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: AuraSpacing.xxSmall) {
                Text(title)
                    .font(.auraMidCardTitle)
                    .foregroundStyle(Color.auraText)
                Text(detail)
                    .font(.auraMidNotice)
                    .foregroundStyle(Color.auraMuted)
            }
            Spacer(minLength: 0)
        }
        .padding(AuraSpacing.medium)
        .background(Color.auraCard, in: .rect(cornerRadius: AuraRadius.row))
        .auraPopIn()
    }
}

struct BadgesView: View {
    let stats: UserStats

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: AuraSpacing.small)]

    var body: some View {
        let allBadges = badges(for: stats)
        ScrollView {
            VStack(alignment: .leading, spacing: AuraSpacing.medium) {
                Text("\(allBadges.filter(\.isEarned).count) of \(allBadges.count) earned")
                    .font(.auraMidLabel)
                    .foregroundStyle(Color.auraMuted)

                LazyVGrid(columns: columns, spacing: AuraSpacing.small) {
                    ForEach(allBadges) { badge in
                        VStack(spacing: AuraSpacing.xxSmall) {
                            Image(systemName: badge.isEarned ? "rosette" : "lock")
                            Text(badge.title)
                                .font(.auraMidChip)
                            Text(badge.isEarned ? "Earned" : "\(badge.progress) / \(badge.target)")
                                .font(.auraMidSmall)
                        }
                        .foregroundStyle(Color.auraInk)
                        .multilineTextAlignment(.center)
                        .padding(AuraSpacing.small)
                        .frame(maxWidth: .infinity, minHeight: AuraSize.badgeTileHeight)
                        .background(badge.isEarned ? Color.auraYellow : Color.auraLilac, in: .rect(cornerRadius: AuraRadius.row))
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(Text("\(badge.title), \(badge.detail), \(badge.isEarned ? "earned" : "\(badge.progress) of \(badge.target)")"))
                    }
                }
            }
            .padding(AuraSpacing.screen)
        }
        .background(Color.auraBackground)
        .navigationTitle("Badges")
        .navigationBarTitleDisplayMode(.inline)
    }
}
