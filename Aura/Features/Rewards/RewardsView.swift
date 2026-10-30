import SwiftUI

// Rewards shop
struct RewardsView: View {
    let shop: ShopStore
    let statsStore: StatsStore

    @State private var itemToBuy: ShopItem?

    private var stats: UserStats { statsStore.stats ?? UserStats() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AuraSpacing.medium) {
                HStack {
                    Text("Your points")
                        .font(.auraSectionLabel)
                        .foregroundStyle(Color.auraMuted)
                    Spacer()
                    AuraPill(text: formattedPoints(stats.balance))
                }

                if let message = shop.message {
                    if shop.messageIsError {
                        ErrorMessage(text: message)
                    } else {
                        StatusBanner(systemImage: "checkmark.circle", message: message)
                    }
                }

                if statsStore.stats == nil {
                    StatusBanner(systemImage: "hourglass", message: "Loading your points…")
                }

                ForEach(shopCatalog) { item in
                    ShopItemCard(
                        item: item,
                        availability: shopAvailability(for: item, stats: stats, ownedItemIDs: shop.ownedItemIDs),
                        statusText: shopStatusText(for: item, stats: stats),
                        isBuying: shop.buyingItemID == item.id,
                        isBusy: shop.buyingItemID != nil || statsStore.stats == nil,
                        onBuy: { itemToBuy = item }
                    )
                }

                Text("Points come from discovering walls and finishing quests. Purchases can't be refunded.")
                    .font(.auraErrorText)
                    .foregroundStyle(Color.auraMuted)
            }
            .padding(AuraSpacing.screen)
        }
        .background(Color.auraBackground)
        .navigationTitle("Rewards shop")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { shop.clearMessage() }
        .confirmationDialog(
            "Buy this reward?",
            isPresented: Binding(get: { itemToBuy != nil }, set: { if !$0 { itemToBuy = nil } }),
            titleVisibility: .visible,
            presenting: itemToBuy
        ) { item in
            Button("Buy \(item.title) for \(formattedPoints(item.price))") {
                Task { await shop.buy(item, stats: statsStore.stats) }
            }
        } message: { item in
            Text(item.detail)
        }
    }
}

private struct ShopItemCard: View {
    let item: ShopItem
    let availability: ShopAvailability
    let statusText: String?
    let isBuying: Bool
    let isBusy: Bool
    let onBuy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AuraSpacing.small) {
            HStack(spacing: AuraSpacing.medium) {
                Image(systemName: item.systemImage)
                    .foregroundStyle(Color.auraInk)
                    .frame(width: AuraSize.messageSwatch, height: AuraSize.messageSwatch)
                    .background(Color.auraYellow, in: .rect(cornerRadius: AuraRadius.swatch))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: AuraSpacing.xxSmall) {
                    Text(item.title)
                        .font(.auraCardTitle)
                        .foregroundStyle(Color.auraText)
                    Text(formattedPoints(item.price))
                        .font(.auraErrorText)
                        .foregroundStyle(Color.auraMuted)
                }
                Spacer(minLength: 0)
            }

            Text(item.detail)
                .font(.auraNotice)
                .foregroundStyle(Color.auraMuted)

            if let statusText {
                Text(statusText)
                    .font(.auraErrorText)
                    .foregroundStyle(Color.auraText)
            }

            Button(action: onBuy) {
                if isBuying {
                    ProgressView().tint(Color.auraInk)
                } else {
                    Text(shopButtonTitle(for: item, availability: availability))
                }
            }
            .buttonStyle(AuraButtonStyle(kind: availability == .available ? .highlight : .outline))
            .disabled(availability != .available || isBusy)
        }
        .padding(AuraSpacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.auraCard, in: .rect(cornerRadius: AuraRadius.card))
        .auraPopIn()
    }
}
