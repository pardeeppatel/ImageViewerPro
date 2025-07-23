import SwiftUI
import AppKit

struct CropView: View {
    let image: NSImage
    let onEndCrop: (NSImage?) -> Void
    
    // The crop rectangle in the image's own pixel coordinate space.
    @State private var cropRect: CGRect
    
    @Environment(\.dismiss) private var dismiss

    init(image: NSImage, onEndCrop: @escaping (NSImage?) -> Void) {
        self.image = image
        self.onEndCrop = onEndCrop
        // Start with a default crop rect (e.g., center 80%) in the image's pixel coordinates.
        let initialRect = CGRect(x: image.size.width * 0.1, y: image.size.height * 0.1, width: image.size.width * 0.8, height: image.size.height * 0.8)
        self._cropRect = State(initialValue: initialRect)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top control bar
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Apply Crop") {
                    // The cropRect is already in the correct pixel coordinate space.
                    let croppedImage = image.crop(to: cropRect)
                    onEndCrop(croppedImage)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))

            // Main cropping interface
            GeometryReader { geo in
                let imageDisplayRect = calculateImageDisplayRect(in: geo.size)

                ZStack {
                    // Display the image, centered
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width, height: geo.size.height)

                    // The interactive cropping overlay
                    CropShape(imageSize: image.size, imageDisplayRect: imageDisplayRect, cropRect: $cropRect)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.8))
        }
        .frame(minWidth: 800, minHeight: 600)
    }
    
    // Helper function to deterministically calculate the on-screen frame of the scaled image.
    private func calculateImageDisplayRect(in containerSize: CGSize) -> CGRect {
        let imageSize = image.size
        let imageAspectRatio = imageSize.width / imageSize.height
        let containerAspectRatio = containerSize.width / containerSize.height

        var displaySize: CGSize = .zero
        if imageAspectRatio > containerAspectRatio {
            // Image is wider than container, so width is the constraint
            displaySize.width = containerSize.width
            displaySize.height = containerSize.width / imageAspectRatio
        } else {
            // Image is taller than or same as container, so height is the constraint
            displaySize.height = containerSize.height
            displaySize.width = containerSize.height * imageAspectRatio
        }

        let displayOrigin = CGPoint(
            x: (containerSize.width - displaySize.width) / 2,
            y: (containerSize.height - displaySize.height) / 2
        )

        return CGRect(origin: displayOrigin, size: displaySize)
    }
}

struct CropShape: View {
    let imageSize: CGSize
    let imageDisplayRect: CGRect
    @Binding var cropRect: CGRect
    
    @State private var startDragRect: CGRect? = nil

    // Calculate the scaling factor between the image's pixels and the view's points
    private var scale: CGSize {
        guard imageDisplayRect.width > 0, imageDisplayRect.height > 0 else { return .zero }
        return CGSize(
            width: imageSize.width / imageDisplayRect.width,
            height: imageSize.height / imageDisplayRect.height
        )
    }
    
    // The crop rectangle converted to the view's coordinate space for display
    private var displayCropRect: CGRect {
        guard scale.width > 0, scale.height > 0 else { return .zero }
        let viewWidth = cropRect.width / scale.width
        let viewHeight = cropRect.height / scale.height
        // Convert from image pixel coords (origin bottom-left) to view point coords (origin top-left)
        let viewX = (cropRect.minX / scale.width) + imageDisplayRect.minX
        let viewY = ((imageSize.height - cropRect.maxY) / scale.height) + imageDisplayRect.minY
        
        return CGRect(x: viewX, y: viewY, width: viewWidth, height: viewHeight)
    }

    var body: some View {
        ZStack {
            // Dimming overlay that masks the area outside the crop selection
            Rectangle()
                .fill(Color.black.opacity(0.5))
                .mask(
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: displayCropRect.width, height: displayCropRect.height)
                        .position(x: displayCropRect.midX, y: displayCropRect.midY)
                        .blendMode(.destinationOut)
                )
                .compositingGroup()

            // The draggable frame
            Rectangle()
                .stroke(Color.white, lineWidth: 1)
                .frame(width: displayCropRect.width, height: displayCropRect.height)
                .position(x: displayCropRect.midX, y: displayCropRect.midY)
                .contentShape(Rectangle())
                .gesture(moveGesture)

            // The resize handles, positioned relative to the frame
            ForEach(Handle.allCases) { handle in
                ResizeHandle(handle: handle, cropRect: $cropRect, imageSize: imageSize, scale: scale)
                    .position(
                        x: displayCropRect.minX + displayCropRect.width * handle.position.x,
                        y: displayCropRect.minY + displayCropRect.height * handle.position.y
                    )
            }
        }
    }
    
    // Gesture for moving the entire crop area
    private var moveGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if startDragRect == nil {
                    startDragRect = cropRect
                }
                guard let startRect = startDragRect, scale.width > 0, scale.height > 0 else { return }

                let deltaX = value.translation.width * scale.width
                let deltaY = -value.translation.height * scale.height
                
                var newOriginX = startRect.origin.x + deltaX
                var newOriginY = startRect.origin.y + deltaY
                
                // Clamp the movement to stay within the image bounds
                newOriginX = max(0, min(newOriginX, imageSize.width - startRect.width))
                newOriginY = max(0, min(newOriginY, imageSize.height - startRect.height))
                
                cropRect.origin = CGPoint(x: newOriginX, y: newOriginY)
            }
            .onEnded { _ in
                startDragRect = nil
            }
    }
}

// Represents the 8 handles on a selection rectangle
enum Handle: CaseIterable, Identifiable {
    case topLeft, top, topRight, left, right, bottomLeft, bottom, bottomRight
    var id: Self { self }
    
    var position: CGPoint {
        switch self {
        case .topLeft: return .init(x: 0, y: 0)
        case .top: return .init(x: 0.5, y: 0)
        case .topRight: return .init(x: 1, y: 0)
        case .left: return .init(x: 0, y: 0.5)
        case .right: return .init(x: 1, y: 0.5)
        case .bottomLeft: return .init(x: 0, y: 1)
        case .bottom: return .init(x: 0.5, y: 1)
        case .bottomRight: return .init(x: 1, y: 1)
        }
    }
}

// A single draggable resize handle
struct ResizeHandle: View {
    let handle: Handle
    @Binding var cropRect: CGRect
    let imageSize: CGSize
    let scale: CGSize
    
    @State private var startDragRect: CGRect? = nil
    private static let minCropSize: CGFloat = 50 // Minimum crop size in pixels
    
    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 12, height: 12)
            .contentShape(Rectangle().inset(by: -10)) // Make handle easier to grab
            .gesture(dragGesture)
    }
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if startDragRect == nil {
                    startDragRect = cropRect
                }
                // FIX: Use the stable startDragRect for all calculations to prevent jitter.
                guard var newRect = startDragRect, scale.width > 0, scale.height > 0 else { return }
                
                let deltaX = value.translation.width * scale.width
                let deltaY = -value.translation.height * scale.height
                
                // Horizontal adjustments
                if [.topLeft, .left, .bottomLeft].contains(handle) {
                    let proposedWidth = newRect.width - deltaX
                    if proposedWidth >= Self.minCropSize && newRect.minX + deltaX >= 0 {
                        newRect.origin.x = startDragRect!.minX + deltaX
                        newRect.size.width = proposedWidth
                    }
                }
                if [.topRight, .right, .bottomRight].contains(handle) {
                    let proposedWidth = newRect.width + deltaX
                    if proposedWidth >= Self.minCropSize && newRect.maxX + deltaX <= imageSize.width {
                        newRect.size.width = proposedWidth
                    }
                }
                
                // Vertical adjustments
                if [.topLeft, .top, .topRight].contains(handle) {
                    let proposedHeight = newRect.height + deltaY
                    if proposedHeight >= Self.minCropSize && newRect.maxY + deltaY <= imageSize.height {
                        newRect.size.height = proposedHeight
                    }
                }
                if [.bottomLeft, .bottom, .bottomRight].contains(handle) {
                    let proposedHeight = newRect.height - deltaY
                    if proposedHeight >= Self.minCropSize && newRect.minY + deltaY >= 0 {
                        newRect.origin.y = startDragRect!.minY + deltaY
                        newRect.size.height = proposedHeight
                    }
                }
                
                cropRect = newRect
            }
            .onEnded { _ in
                startDragRect = nil
            }
    }
}
