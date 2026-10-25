import SwiftUI

struct PermissionsView: View {
    let locationService: LocationService
    let onContinue: () -> Void

    @State private var isWaitingForLocationAnswer = false

    var body: some View {
        VStack(spacing: AuraSpacing.medium) {
            Spacer()

            AuraPill(text: "Camera + Location")
            Text("Aura needs two things")
                .font(.auraHeading)
                .foregroundStyle(Color.auraText)
                .multilineTextAlignment(.center)
            Text("Location finds walls near you. The camera shows walls in AR. You can change both later in Settings.")
                .foregroundStyle(Color.auraMuted)
                .multilineTextAlignment(.center)

            VStack(spacing: AuraSpacing.small) {
                PermissionRow(systemImage: "location.fill", title: "Location", detail: "Asked now, and only used while Aura is open.")
                PermissionRow(systemImage: "camera.fill", title: "Camera", detail: "Asked the first time you open AR.")
            }
            .padding(.top, AuraSpacing.small)

            Spacer()

            Button("Allow location", action: allowLocationTapped)
                .buttonStyle(AuraButtonStyle())
                .disabled(isWaitingForLocationAnswer)
            Button("Not now", action: onContinue)
                .buttonStyle(AuraButtonStyle(kind: .outline))
        }
        .padding(AuraSpacing.screen)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.auraBackground)
        .onChange(of: locationService.access) {
            if isWaitingForLocationAnswer && locationService.access != .notAsked {
                onContinue()
            }
        }
    }

    private func allowLocationTapped() {
        if locationService.access == .notAsked {
            isWaitingForLocationAnswer = true
            locationService.requestAccessIfNeeded()
        } else {
            onContinue()
        }
    }
}

private struct PermissionRow: View {
    let systemImage: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: AuraSpacing.medium) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.auraInk)
                .frame(width: AuraSize.minTap, height: AuraSize.minTap)
                .background(Color.auraMint, in: .rect(cornerRadius: AuraRadius.control))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: AuraSpacing.xxSmall) {
                Text(title)
                    .font(.auraCardTitle)
                    .foregroundStyle(Color.auraText)
                Text(detail)
                    .font(.auraNotice)
                    .foregroundStyle(Color.auraMuted)
            }
            Spacer(minLength: 0)
        }
        .padding(AuraSpacing.medium)
        .background(Color.auraCard, in: .rect(cornerRadius: AuraRadius.card))
    }
}
