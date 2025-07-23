import SwiftUI
import AppKit
import UniformTypeIdentifiers // Required for UTType

class ImageViewModel: ObservableObject {
    @Published var imageURLs: [URL] = []
    @Published var currentIndex: Int? = nil
    @Published var showDeleteConfirmation = false
    @Published var showErrorAlert = false
    @Published var errorMessage = ""
    @Published var isEditing = false
    @Published var isLoading = false

    var currentImageURL: URL? {
        if let index = currentIndex, imageURLs.indices.contains(index) {
            return imageURLs[index]
        }
        return nil
    }
    
    var currentImage: NSImage? {
        guard let url = currentImageURL else { return nil }
        return NSImage(contentsOf: url)
    }
    
    var currentImageName: String {
        return currentImageURL?.lastPathComponent ?? "No Image Selected"
    }

    private let supportedExtensions = ["jpg", "jpeg", "png", "gif", "heic", "tiff", "bmp", "webp"]

    // --- Core Functions ---

    // MODIFIED: This function now just shows the panel. The logic is moved.
    func openFileOrFolder() {
        let openPanel = NSOpenPanel()
        
        let imageTypes = supportedExtensions.compactMap { UTType(filenameExtension: $0) }
        let folderType = UTType.folder
        openPanel.allowedContentTypes = imageTypes + [folderType]
        
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false

        if openPanel.runModal() == .OK, let url = openPanel.url {
            // After getting a URL, it's passed to the new handler.
            handleOpenFile(url: url)
        }
    }
    
    // ADDED: New public function to handle any incoming URL.
    func handleOpenFile(url: URL) {
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)

        if isDirectory.boolValue {
            loadImages(from: url)
        } else {
            // IMPORTANT: This requires the App Sandbox to be disabled in Xcode.
            let folderURL = url.deletingLastPathComponent()
            loadImages(from: folderURL, selecting: url)
        }
    }
    
    private func loadImages(from folderURL: URL, selecting selectedURL: URL? = nil) {
        self.isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let allFiles = try FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
                let filteredImages = allFiles.filter { self.supportedExtensions.contains($0.pathExtension.lowercased()) }
                                             .sorted { $0.lastPathComponent < $1.lastPathComponent }

                DispatchQueue.main.async {
                    if filteredImages.isEmpty {
                        self.showError(message: "No supported images found in the selected folder.")
                        self.imageURLs = []
                        self.currentIndex = nil
                    } else {
                        self.imageURLs = filteredImages
                        
                        if let selectedURL = selectedURL, let index = filteredImages.firstIndex(of: selectedURL) {
                            self.currentIndex = index
                        } else {
                            self.currentIndex = 0
                        }
                    }
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.showError(message: "Could not read folder contents: \(error.localizedDescription)")
                    self.isLoading = false
                }
            }
        }
    }

    func nextImage() {
        guard let index = currentIndex, index < imageURLs.count - 1 else { return }
        currentIndex = index + 1
    }

    func previousImage() {
        guard let index = currentIndex, index > 0 else { return }
        currentIndex = index - 1
    }
    
    func selectImage(at index: Int) {
        guard imageURLs.indices.contains(index) else { return }
        currentIndex = index
    }

    func deleteCurrentImage() {
        guard let index = currentIndex, let urlToDelete = currentImageURL else { return }
        do {
            try FileManager.default.trashItem(at: urlToDelete, resultingItemURL: nil)
            imageURLs.remove(at: index)
            if imageURLs.isEmpty {
                currentIndex = nil
            } else if index >= imageURLs.count {
                currentIndex = imageURLs.count - 1
            }
        } catch {
            showError(message: "Failed to move image to Trash: \(error.localizedDescription)")
        }
    }
    
    // --- Editing & Saving ---
    
    func saveEditedImage(image: NSImage, format: ImageFormat, action: SaveAction) {
        guard let url = currentImageURL else {
            showError(message: "Original image URL not found.")
            return
        }

        let newURL: URL
        switch action {
        case .replace:
            newURL = url.deletingPathExtension().appendingPathExtension(format.rawValue)
        case .createNew:
            let name = url.deletingPathExtension().lastPathComponent
            newURL = url.deletingLastPathComponent()
                       .appendingPathComponent("\(name)-edited.\(format.rawValue)")
        }
        
        guard let data = image.data(for: format) else {
            showError(message: "Failed to convert image to \(format.rawValue) format.")
            return
        }

        do {
            try data.write(to: newURL)
            if case .createNew = action {
                loadImages(from: url.deletingLastPathComponent(), selecting: newURL)
            } else if case .replace = action, url != newURL {
                if let index = currentIndex {
                    imageURLs[index] = newURL
                }
            }
        } catch {
            showError(message: "Failed to save image: \(error.localizedDescription)")
        }
        isEditing = false
    }
    
    private func showError(message: String) {
        self.errorMessage = message
        self.showErrorAlert = true
    }
}
