import SwiftUI
import MapKit

struct DiscoveryMapView: View {
    @Bindable var viewModel: DiscoveryViewModel

    @Environment(\.openURL) private var openURL
    @State private var cameraPosition: MapCameraPosition = .userLocation(
        fallback: .region(MKCoordinateRegion(
            center: discoveryFallbackCenter.locationCoordinate,
            latitudinalMeters: discoveryRadiusMeters * 2,
            longitudinalMeters: discoveryRadiusMeters * 2
        ))
    )
    @State private var visibleCenter: Coordinate?

    var body: some View {
        Map(position: $cameraPosition, selection: $viewModel.selectedWallID) {
            UserAnnotation()
            ForEach(viewModel.nearbyWalls) { nearby in
                Annotation(nearby.wall.title, coordinate: nearby.wall.coordinate.locationCoordinate) {
                    WallPin(kind: nearby.wall.kind)
                }
                .tag(nearby.id)
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            visibleCenter = Coordinate(context.region.center)
        }
        .safeAreaInset(edge: .top) {
            header
        }
        .safeAreaInset(edge: .bottom) {
            if let selected = viewModel.selectedWall {
                WallPreviewCard(
                    wall: selected.wall,
                    distanceText: viewModel.distanceText(to: selected.wall),
                    onClose: { viewModel.selectedWallID = nil }
                )
            }
        }
        .onAppear { viewModel.mapAppeared() }
        .onDisappear { viewModel.mapDisappeared() }
        .task(id: viewModel.locationService.latestLocation) {
            await viewModel.locationOrAccessChanged()
        }
        .task(id: viewModel.locationService.access) {
            await viewModel.locationOrAccessChanged()
        }
    }

    private var header: some View {
        VStack(spacing: AuraSpacing.small) {
            HStack {
                Text("Aura")
                    .font(.auraHeading)
                    .foregroundStyle(Color.auraText)
                Spacer()
                if viewModel.isLoading {
                    ProgressView()
                }
            }
            .padding(.horizontal, AuraSpacing.screen)
            .padding(.vertical, AuraSpacing.small)
            .background(Color.auraBackground)

            statusBanner

            if viewModel.canSearchArea(at: visibleCenter), let visibleCenter {
                Button("Search this area") {
                    Task { await viewModel.search(around: visibleCenter) }
                }
                .buttonStyle(AuraPillButtonStyle())
            }
        }
    }

    @ViewBuilder
    private var statusBanner: some View {
        if let errorMessage = viewModel.errorMessage {
            StatusBanner(systemImage: "wifi.exclamationmark", message: errorMessage, actionTitle: "Retry") {
                Task { await viewModel.retry() }
            }
        } else if viewModel.locationService.access.isBlocked {
            StatusBanner(
                systemImage: "location.slash",
                message: "Location is off for Aura, so you're seeing walls around Colombo 7. Turn it on in Settings to find walls near you.",
                actionTitle: "Open Settings",
                action: openSettings
            )
        } else if viewModel.locationService.access == .allowed(isPrecise: false) {
            StatusBanner(
                systemImage: "location.circle",
                message: "Aura only has your approximate location, so distances may be off.",
                actionTitle: "Open Settings",
                action: openSettings
            )
        } else if viewModel.hasSearched && viewModel.nearbyWalls.isEmpty && !viewModel.isLoading {
            StatusBanner(systemImage: "mappin.slash", message: "No walls within 1 km of here yet.")
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }
}

struct WallPin: View {
    let kind: WallKind

    var body: some View {
        Circle()
            .fill(kind == .sponsored ? Color.auraYellow : Color.auraMagenta)
            .frame(width: AuraSize.pin, height: AuraSize.pin)
            .overlay(Circle().strokeBorder(.white, lineWidth: AuraSize.pinBorder))
            .overlay {
                if kind == .sponsored {
                    Image(systemName: "star.fill")
                        .font(.auraPinIcon)
                        .foregroundStyle(Color.auraInk)
                }
            }
            .accessibilityLabel(Text(kind == .sponsored ? "Sponsored wall" : "Community wall"))
    }
}

struct WallPreviewCard: View {
    let wall: Wall
    let distanceText: String?
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AuraSpacing.small) {
            HStack(alignment: .firstTextBaseline, spacing: AuraSpacing.small) {
                Text(wall.title)
                    .font(.auraCardTitle)
                    .foregroundStyle(Color.auraText)
                if wall.kind == .sponsored {
                    Text("Sponsored")
                        .font(.auraPill)
                        .foregroundStyle(Color.auraInk)
                        .padding(.horizontal, AuraSpacing.small)
                        .padding(.vertical, AuraSpacing.xxSmall)
                        .background(Color.auraYellow, in: .capsule)
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .foregroundStyle(Color.auraMuted)
                        .frame(width: AuraSize.minTap, height: AuraSize.minTap)
                }
                .accessibilityLabel("Close")
            }

            if let distanceText {
                Text(distanceText)
                    .foregroundStyle(Color.auraMuted)
            }

            Button("Directions", action: openDirections)
                .buttonStyle(AuraButtonStyle(kind: .highlight))
        }
        .padding(AuraSpacing.medium)
        .background(Color.auraCard, in: .rect(cornerRadius: AuraRadius.card))
        .padding(.horizontal, AuraSpacing.small)
        .padding(.bottom, AuraSpacing.small)
    }

    private func openDirections() {
        let location = CLLocation(latitude: wall.coordinate.latitude, longitude: wall.coordinate.longitude)
        let mapItem = MKMapItem(location: location, address: nil)
        mapItem.name = wall.title
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
    }
}
