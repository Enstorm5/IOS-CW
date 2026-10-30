import SwiftUI

struct NearbyWallsSheet: View {
    let walls: [NearbyWall]
    let distanceText: (Wall) -> String?
    let onSelect: (Wall) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AuraSpacing.small) {
                    ForEach(walls.sorted { $0.distanceMeters < $1.distanceMeters }) { nearby in
                        Button {
                            onSelect(nearby.wall)
                        } label: {
                            HStack(spacing: AuraSpacing.medium) {
                                WallPin(kind: nearby.wall.kind)
                                VStack(alignment: .leading, spacing: AuraSpacing.xxSmall) {
                                    Text(nearby.wall.title)
                                        .font(.auraCardTitle)
                                        .foregroundStyle(Color.auraText)
                                    Text(distanceText(nearby.wall) ?? formattedDistance(meters: nearby.distanceMeters))
                                        .font(.auraNotice)
                                        .foregroundStyle(Color.auraMuted)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(Color.auraMuted)
                                    .accessibilityHidden(true)
                            }
                            .padding(AuraSpacing.medium)
                            .frame(maxWidth: .infinity, minHeight: AuraSize.minTap, alignment: .leading)
                            .background(Color.auraCard, in: .rect(cornerRadius: AuraRadius.row))
                        }
                        .buttonStyle(AuraBounceButtonStyle())
                    }
                }
                .padding(AuraSpacing.screen)
            }
            .background(Color.auraBackground)
            .navigationTitle("Nearby walls")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(Color.auraText)
        .presentationDetents([.medium, .large])
    }
}
