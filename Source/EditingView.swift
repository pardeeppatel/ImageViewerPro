import SwiftUI
import CoreImage

struct EditingView: View {
    @ObservedObject var viewModel: ImageViewModel
    @State var editedImage: NSImage
    @State private var selectedFilter: FilterType = .none
    @State private var showSaveOptions = false
    @State private var showCropView = false
    
    // --- Text Overlay Properties ---
    @State private var textOverlay = ""
    @State private var textColor = Color.white
    @State private var textFont = "Helvetica"
    @State private var textSize: CGFloat = 50
    @State private var textPosition: CGPoint = .zero
    @State private var textBackgroundColor: Color = .black.opacity(0.5)
    
    // --- View State ---
    @State private var imageDisplayRect: CGRect = .zero
    
    private let ciContext = CIContext()

    init(viewModel: ImageViewModel, imageToEdit: NSImage) {
        self.viewModel = viewModel
        self._editedImage = State(initialValue: imageToEdit.copy() as! NSImage)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top control bar
            HStack {
                Button("Cancel") { viewModel.isEditing = false }
                Spacer()
                Text("Edit Mode").font(.headline)
                Spacer()
                Button("Save...") { showSaveOptions = true }
            }
            .padding().background(Color(nsColor: .windowBackgroundColor).shadow(radius: 2))

            HStack {
                // --- Main Image Preview Area ---
                GeometryReader { geo in
                    let displayRect = calculateImageDisplayRect(in: geo.size)
                    
                    ZStack {
                        // Layer 1: The image with filters applied, acts as a stable background
                        Image(nsImage: applyFiltersOnly())
                            .resizable()
                            .scaledToFit()

                        // Layer 2: The interactive text overlay, positioned within the ZStack's coordinate space
                        if !textOverlay.isEmpty {
                            Text(textOverlay)
                                .font(.custom(textFont, size: textSize))
                                .foregroundColor(textColor)
                                .padding(10)
                                .background(
                                    textBackgroundColor
                                )
                                .cornerRadius(8)
                                .position(textPosition)
                                .gesture(textDragGesture(imageBounds: displayRect))
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .onAppear {
                        // Set the initial state for the image display frame and text position
                        self.imageDisplayRect = displayRect
                        if textPosition == .zero {
                            textPosition = CGPoint(x: displayRect.midX, y: displayRect.midY)
                        }
                    }
                    .onChange(of: geo.size) { _, newSize in
                        // Update the frame if the window is resized
                        self.imageDisplayRect = calculateImageDisplayRect(in: newSize)
                    }
                }
                .padding()

                // --- Editing Tools Sidebar ---
                VStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            // Filters Section
                            Text("Filters").font(.headline)
                            Picker("Filter", selection: $selectedFilter) {
                                ForEach(FilterType.allCases) { Text($0.name).tag($0) }
                            }.pickerStyle(MenuPickerStyle()).labelsHidden()

                            Divider()

                            // Crop Section
                            Text("Crop").font(.headline)
                            Button("Open Crop Tool") { showCropView = true }
                                .frame(maxWidth: .infinity)
                            
                            Divider()

                            // Text Overlay Section
                            Text("Text Overlay").font(.headline)
                            TextField("Enter text...", text: $textOverlay)
                            Picker("Font", selection: $textFont) {
                                Text("Helvetica").tag("Helvetica")
                                Text("Chalkduster").tag("Chalkduster")
                                Text("SignPainter").tag("SignPainter-HouseScript")
                                Text("Savoye LET").tag("SavoyeLetPlain")
                            }
                            ColorPicker("Text Color", selection: $textColor)
                            VStack(alignment: .leading) {
                                Text("Size: \(Int(textSize))")
                                Slider(value: $textSize, in: 10...200)
                            }
                            ColorPicker("Background Color", selection: $textBackgroundColor)
                        }
                        .padding()
                    }
                }
                .frame(width: 300)
                .background(Color(NSColor.controlBackgroundColor))
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .sheet(isPresented: $showCropView) {
            CropView(image: editedImage) { croppedImage in
                if let croppedImage = croppedImage {
                    self.editedImage = croppedImage
                }
                self.showCropView = false
            }
        }
        .confirmationDialog("Save Image", isPresented: $showSaveOptions, titleVisibility: .visible) {
            ForEach(ImageFormat.allCases, id: \.self) { format in
                Button("Save as New \(format.rawValue.uppercased())") {
                    let finalImage = generateFinalImage()
                    viewModel.saveEditedImage(image: finalImage, format: format, action: .createNew)
                }
                Button("Replace with \(format.rawValue.uppercased())") {
                    let finalImage = generateFinalImage()
                    viewModel.saveEditedImage(image: finalImage, format: format, action: .replace)
                }
            }
        }
    }
    
    /// Creates the gesture for dragging the text overlay.
    private func textDragGesture(imageBounds: CGRect) -> some Gesture {
        DragGesture()
            .onChanged { value in
                // Estimate the size of the text view to constrain its frame.
                let attributes: [NSAttributedString.Key: Any] = [.font: NSFont(name: textFont, size: textSize) ?? .systemFont(ofSize: textSize)]
                let attributedString = NSAttributedString(string: textOverlay, attributes: attributes)
                // Add padding to the estimation to match the view's .padding(10) modifier.
                let estimatedSize = CGSize(width: attributedString.size().width + 20, height: attributedString.size().height + 20)
                
                let halfWidth = estimatedSize.width / 2
                let halfHeight = estimatedSize.height / 2

                var newX = value.location.x
                var newY = value.location.y
                
                // FIX: This new logic correctly handles cases where the text is larger than the image,
                // preventing it from disappearing.
                
                // Clamp X position
                if estimatedSize.width > imageBounds.width {
                    // If text is wider than the image, allow its center to move within a range
                    // that keeps the text visible on screen.
                    let minCenterX = imageBounds.maxX - halfWidth
                    let maxCenterX = imageBounds.minX + halfWidth
                    newX = max(minCenterX, min(maxCenterX, newX))
                } else {
                    // If text is narrower, keep its frame entirely within the image bounds.
                    let minCenterX = imageBounds.minX + halfWidth
                    let maxCenterX = imageBounds.maxX - halfWidth
                    newX = max(minCenterX, min(maxCenterX, newX))
                }

                // Clamp Y position
                if estimatedSize.height > imageBounds.height {
                    // If text is taller than the image.
                    let minCenterY = imageBounds.maxY - halfHeight
                    let maxCenterY = imageBounds.minY + halfHeight
                    newY = max(minCenterY, min(maxCenterY, newY))
                } else {
                    // If text is shorter, keep its frame entirely within the image bounds.
                    let minCenterY = imageBounds.minY + halfHeight
                    let maxCenterY = imageBounds.maxY - halfHeight
                    newY = max(minCenterY, min(maxCenterY, newY))
                }
                
                // Only update if the new position is valid to prevent NaN errors.
                if !newX.isNaN && !newY.isNaN {
                    self.textPosition = CGPoint(x: newX, y: newY)
                }
            }
    }
    
    /// Applies only the selected CIFilter to the image for fast previewing.
    private func applyFiltersOnly() -> NSImage {
        guard selectedFilter != .none,
              let sourceCGImage = editedImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return editedImage
        }
        var ciImage = CIImage(cgImage: sourceCGImage)

        let filter = selectedFilter.filter
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        if let output = filter.outputImage,
           let finalCGImage = ciContext.createCGImage(output, from: output.extent) {
            return NSImage(cgImage: finalCGImage, size: editedImage.size)
        }
        return editedImage
    }

    /// Generates the final composite image with filters and text "burned in" for saving.
    private func generateFinalImage() -> NSImage {
        let filteredImage = applyFiltersOnly()
        guard !textOverlay.isEmpty else { return filteredImage }
        
        let imageSize = filteredImage.size
        let newImage = NSImage(size: imageSize)
        newImage.lockFocus()
        
        filteredImage.draw(in: CGRect(origin: .zero, size: imageSize))
        
        let finalTextColor = NSColor(textColor)
        let finalBackgroundColor = NSColor(textBackgroundColor)
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont(name: textFont, size: textSize) ?? .systemFont(ofSize: textSize),
            .foregroundColor: finalTextColor
        ]
        let attributedString = NSAttributedString(string: textOverlay, attributes: attributes)
        let stringSize = attributedString.size()
        
        guard imageDisplayRect.width > 0, imageDisplayRect.height > 0 else {
            newImage.unlockFocus()
            return filteredImage
        }
        
        let scaleX = imageSize.width / imageDisplayRect.width
        let scaleY = imageSize.height / imageDisplayRect.height
        
        let relativeX = textPosition.x - imageDisplayRect.minX
        let relativeY = textPosition.y - imageDisplayRect.minY
        
        let pixelX = relativeX * scaleX - (stringSize.width / 2)
        let pixelY = (imageDisplayRect.height - relativeY) * scaleY - (stringSize.height / 2)

        let textRect = CGRect(origin: CGPoint(x: pixelX, y: pixelY), size: stringSize)
        let backgroundRect = textRect.insetBy(dx: -10, dy: -10)
        
        finalBackgroundColor.setFill()
        let backgroundPath = NSBezierPath(roundedRect: backgroundRect, xRadius: 8, yRadius: 8)
        backgroundPath.fill()
        
        attributedString.draw(in: textRect)
        
        newImage.unlockFocus()
        return newImage
    }
    
    // Helper to calculate the scaled-to-fit rect of the image within a container.
    private func calculateImageDisplayRect(in containerSize: CGSize) -> CGRect {
        let imageSize = editedImage.size
        let imageAspectRatio = imageSize.width / imageSize.height
        let containerAspectRatio = containerSize.width / containerSize.height

        var displaySize: CGSize = .zero
        if imageAspectRatio > containerAspectRatio {
            displaySize.width = containerSize.width
            displaySize.height = containerSize.width / imageAspectRatio
        } else {
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
