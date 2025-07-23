// MARK: - File: HelperViews.swift
import SwiftUI
import AppKit
/*
 Contains smaller, reusable views used throughout the app.
*/
struct DeleteConfirmationView: View {
    @Binding var isPresented: Bool
    var onDelete: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).edgesIgnoringSafeArea(.all).onTapGesture { isPresented = false }
            VStack(spacing: 20) {
                Image(systemName: "trash.circle.fill").font(.system(size: 50)).foregroundColor(.red)
                Text("Move to Trash?").font(.title).fontWeight(.bold)
                Text("This file will be moved to the system Trash.").font(.body).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal)
                HStack(spacing: 20) {
                    Button("Cancel") { isPresented = false }
                        .keyboardShortcut(.escape, modifiers: [])
                        .frame(maxWidth: .infinity).padding().background(Color.secondary.opacity(0.3))
                        .foregroundColor(.primary).cornerRadius(12)
                    Button("Delete") { onDelete(); isPresented = false }
                        .keyboardShortcut(.defaultAction)
                        .frame(maxWidth: .infinity).padding().background(Color.red)
                        .foregroundColor(.white).cornerRadius(12)
                }
            }
            .padding(30).background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(20).shadow(radius: 10).frame(maxWidth: 400)
            .transition(.scale.combined(with: .opacity))
        }
        .animation(.spring(), value: isPresented)
    }
}

struct ThumbnailView: View {
    let url: URL
    let isSelected: Bool
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable().scaledToFill()
            } else {
                Rectangle().fill(Color.gray.opacity(0.3))
            }
        }
        .frame(width: 80, height: 60).clipped().cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
        )
        .onAppear(perform: loadImage)
    }
    
    private func loadImage() {
        DispatchQueue.global(qos: .userInitiated).async {
            let loadedImage = NSImage(contentsOf: url)
            DispatchQueue.main.async {
                self.image = loadedImage
            }
        }
    }
}
