import SwiftUI

struct ContentView: View {
    // MODIFIED: This view now receives the view model from its parent.
    // It uses @ObservedObject instead of @StateObject.
    @ObservedObject var viewModel: ImageViewModel
    
    @State private var showControls = true
    private let controlsTimer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    // A computed property to create a "window" of thumbnails to display for performance.
    private var timelineWindow: Range<Int> {
        guard let currentIndex = viewModel.currentIndex else { return 0..<0 }
        let windowSize = 50 // Show 50 items on each side of the current one
        let lowerBound = max(0, currentIndex - windowSize)
        let upperBound = min(viewModel.imageURLs.count, currentIndex + windowSize + 1)
        return lowerBound..<upperBound
    }

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)

            if viewModel.currentImageURL != nil {
                mainImageView
            } else {
                welcomeView
            }

            if viewModel.showDeleteConfirmation {
                DeleteConfirmationView(isPresented: $viewModel.showDeleteConfirmation, onDelete: viewModel.deleteCurrentImage)
            }
            
            if viewModel.isLoading {
                ProgressView("Loading Images...")
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)
                    .padding(25)
                    .background(Color.black.opacity(0.75))
                    .foregroundColor(.white)
                    .cornerRadius(15)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: viewModel.isLoading)
        .focusable()
        .onKeyPress(keys: [.leftArrow, .rightArrow, .escape], action: handleKeyPress)
        .onDeleteCommand {
            if viewModel.currentImageURL != nil && !viewModel.isEditing {
                viewModel.showDeleteConfirmation = true
            }
        }
        .onHover { hovering in withAnimation { showControls = hovering } }
        .alert(isPresented: $showAlert) {
            Alert(title: Text(alertTitle), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
        .onReceive(NotificationCenter.default.publisher(for: .showAboutInfo)) { _ in
            self.alertTitle = "About ImageViewerPro"
            self.alertMessage = "ImageViewerPro is a modern, lightweight image viewer and editor for macOS. Version 1.0."
            self.showAlert = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .checkForUpdates)) { _ in
            self.alertTitle = "Check for Updates"
            self.alertMessage = "You are running the latest version of ImageViewerPro."
            self.showAlert = true
        }
        .sheet(isPresented: $viewModel.isEditing) {
            if let imageToEdit = viewModel.currentImage {
                EditingView(viewModel: viewModel, imageToEdit: imageToEdit)
            }
        }
    }

    private var mainImageView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 20) {
                Text(viewModel.currentImageName)
                    .font(.headline).foregroundColor(.white).padding(8)
                    .background(Color.black.opacity(0.5)).cornerRadius(8)
                Spacer()
                
                Button(action: { viewModel.isEditing = true }) {
                    HStack {
                        Image(systemName: "pencil.and.outline")
                        Text("Edit")
                    }
                }
                
                Button(action: viewModel.openFileOrFolder) {
                    HStack {
                        Image(systemName: "folder.badge.plus")
                        Text("Open")
                    }
                }
                
                Button(action: {
                    NotificationCenter.default.post(name: .checkForUpdates, object: nil)
                }) {
                    HStack {
                        Image(systemName: "arrow.down.circle")
                        Text("Updates")
                    }
                }
                
                Button(action: { viewModel.showDeleteConfirmation = true }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete")
                    }
                }.foregroundColor(.red)
            }
            .padding()
            .buttonStyle(PlainButtonStyle())
            .font(.system(size: 14))
            .foregroundColor(.white)
            .background(Color.black.opacity(0.3))
            .opacity(showControls ? 1 : 0)

            Spacer()
            if let image = viewModel.currentImage {
                Image(nsImage: image)
                    .resizable().scaledToFit()
                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                    .id(viewModel.currentImageURL)
                    .gesture(swipeGesture)
                    .onTapGesture(count: 2) {
                        NSApplication.shared.keyWindow?.toggleFullScreen(nil)
                    }
            }
            Spacer()

            if showControls {
                thumbnailTimeline
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: showControls)
    }
    
    private var thumbnailTimeline: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    let urls = viewModel.imageURLs
                    ForEach(timelineWindow, id: \.self) { index in
                        let url = urls[index]
                        ThumbnailView(url: url, isSelected: viewModel.currentIndex == index)
                            .onTapGesture { viewModel.selectImage(at: index) }
                            .id(url)
                    }
                }
                .padding(.horizontal)
            }
            .frame(height: 80)
            .background(Color.black.opacity(0.5))
            .onChange(of: viewModel.currentIndex) { _, newIndex in
                DispatchQueue.main.async {
                    if let newIndex = newIndex, let url = viewModel.imageURLs[safe: newIndex] {
                        withAnimation {
                            proxy.scrollTo(url, anchor: .center)
                        }
                    }
                }
            }
        }
    }

    private var welcomeView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled").font(.system(size: 80)).foregroundColor(.gray)
            Text("Image Viewer Pro").font(.largeTitle).fontWeight(.bold)
            Text("Select a folder or image to begin.").font(.title2).foregroundColor(.secondary)
            Button(action: viewModel.openFileOrFolder) {
                Text("Open...").padding(.horizontal, 20).padding(.vertical, 10)
                    .background(Color.blue).foregroundColor(.white).cornerRadius(10)
            }.buttonStyle(PlainButtonStyle())
        }
    }
    
    private func handleKeyPress(press: KeyPress) -> KeyPress.Result {
        guard !viewModel.isEditing else { return .ignored }
        
        if viewModel.showDeleteConfirmation {
            if press.key == .escape {
                viewModel.showDeleteConfirmation = false
                return .handled
            }
            return .ignored
        }
        
        switch press.key {
        case .leftArrow: viewModel.previousImage(); return .handled
        case .rightArrow: viewModel.nextImage(); return .handled
        case .escape:
            if let window = NSApplication.shared.keyWindow, window.styleMask.contains(.fullScreen) {
                window.toggleFullScreen(nil)
                return .handled
            }
            return .ignored
        default: return .ignored
        }
    }
    
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 50).onEnded { value in
            guard !viewModel.isEditing else { return }
            if value.translation.width > 0 { viewModel.previousImage() }
            else { viewModel.nextImage() }
        }
    }
}

// You will need a preview provider that can create a dummy view model.
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(viewModel: ImageViewModel())
    }
}
