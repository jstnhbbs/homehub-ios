import SwiftUI
import UIKit

/// The outline a photo will be shown in, so the crop screen can draw it over the photo.
enum PhotoCropShape {
    /// A person's photo.
    case circle
    /// The family photo, the same rounded square as `HouseholdMarkView`.
    case roundedSquare

    func path(in rect: CGRect) -> Path {
        switch self {
        case .circle:
            Path(ellipseIn: rect)
        case .roundedSquare:
            RoundedRectangle(cornerRadius: rect.width * 0.32, style: .continuous).path(in: rect)
        }
    }
}

/// A photo picked for an avatar, waiting to be cropped. `Identifiable` so a sheet can be driven by it.
struct PhotoCropCandidate: Identifiable {
    let id = UUID()
    let image: UIImage
}

/// "Move and Scale": the photo behind a cut-out in the shape it will be shown in, with everything
/// outside the shape dimmed so the edges of the crop are plain. Drag to move, pinch or use the
/// slider to zoom, double-tap to start over. Choose hands back the square that is inside the shape.
struct PhotoCropView: View {
    let image: UIImage
    var shape: PhotoCropShape
    var onCancel: () -> Void
    var onDone: (UIImage) -> Void

    @State private var zoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var dragStart: CGSize?
    @State private var pinchStart: CGFloat?
    /// The side of the cut-out as last drawn; the offset is in those points, so Choose needs it.
    @State private var windowSide: CGFloat = 0

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let side = Self.windowSide(in: proxy.size)
                let geometry = current(side: side)
                VStack(spacing: 0) {
                    cropArea(geometry: geometry, side: side)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    zoomControl(side: side)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 18)
                }
                .onChange(of: side, initial: true) { _, new in windowSide = new }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Move and Scale")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Choose") { choose() }
                        .fontWeight(.semibold)
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled()
    }

    /// The side of the cut-out: as wide as fits, with room around it and for the slider below.
    private static func windowSide(in size: CGSize) -> CGFloat {
        max(120, min(size.width - 40, size.height - 110, 520))
    }

    private func current(side: CGFloat) -> PhotoCropGeometry {
        var geometry = PhotoCropGeometry(imageSize: image.size, cropSide: side)
        geometry.setZoom(zoom)
        geometry.setOffset(offset)
        return geometry
    }

    private func cropArea(geometry: PhotoCropGeometry, side: CGFloat) -> some View {
        GeometryReader { area in
            let window = CGRect(
                x: (area.size.width - side) / 2,
                y: (area.size.height - side) / 2,
                width: side,
                height: side
            )
            // The photo layer is cut to the visible area first, so the overlay below is drawn in the
            // area's own coordinates (the photo itself is usually bigger than the area).
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .frame(width: geometry.displaySize.width, height: geometry.displaySize.height)
                    .offset(geometry.offset)
                    .accessibilityHidden(true)
            }
            .frame(width: area.size.width, height: area.size.height)
            .clipped()
            .overlay {
                // Everything outside the shape is dimmed, so the edge of the crop is the edge of the
                // bright part.
                ZStack {
                    Path { path in
                        path.addRect(CGRect(origin: .zero, size: area.size))
                        path.addPath(shape.path(in: window))
                    }
                    .fill(Color.black.opacity(0.62), style: FillStyle(eoFill: true))

                    shape.path(in: window)
                        .stroke(Color.white.opacity(0.9), lineWidth: 2)
                }
                .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .gesture(dragGesture(side: side))
            .simultaneousGesture(pinchGesture(side: side))
            .onTapGesture(count: 2) {
                withAnimation(.snappy) {
                    zoom = 1
                    offset = .zero
                }
            }
            .accessibilityElement()
            .accessibilityLabel("Photo crop")
            .accessibilityHint("Use the zoom slider to zoom. Choose uses the part inside the outline.")
        }
    }

    private func dragGesture(side: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let start = dragStart ?? current(side: side).offset
                dragStart = start
                var geometry = current(side: side)
                geometry.setOffset(CGSize(
                    width: start.width + value.translation.width,
                    height: start.height + value.translation.height
                ))
                offset = geometry.offset
            }
            .onEnded { _ in dragStart = nil }
    }

    private func pinchGesture(side: CGFloat) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let start = pinchStart ?? zoom
                pinchStart = start
                var geometry = current(side: side)
                geometry.setZoom(start * value.magnification)
                zoom = geometry.zoom
                offset = geometry.offset
            }
            .onEnded { _ in pinchStart = nil }
    }

    private func zoomControl(side: CGFloat) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "minus.magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Slider(
                value: Binding(
                    get: { Double(zoom) },
                    set: { value in
                        var geometry = current(side: side)
                        geometry.setZoom(CGFloat(value))
                        zoom = geometry.zoom
                        offset = geometry.offset
                    }
                ),
                in: 1...Double(PhotoCropGeometry.maxZoom)
            )
            .accessibilityLabel("Zoom")
            Image(systemName: "plus.magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
    }

    private func choose() {
        let geometry = current(side: windowSide)
        onDone(ProfilePhotoHelpers.cropped(image, to: geometry.cropRect()))
    }
}
