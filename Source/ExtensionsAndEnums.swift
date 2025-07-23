import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

/*
 Contains helper extensions, enums, and other supporting code.
*/

// --- Enums ---
enum ImageFormat: String, CaseIterable { case jpg, png, webp, jpeg }
enum SaveAction { case replace, createNew }

// --- Collection Extension ---
extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// --- NSImage Extension ---
extension NSImage {
    func data(for format: ImageFormat) -> Data? {
        guard let tiffRepresentation = self.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffRepresentation) else { return nil }
        
        let fileType: NSBitmapImageRep.FileType
        switch format {
        case .png: fileType = .png
        case .jpg, .jpeg: fileType = .jpeg
        case .webp: return nil // Requires a third-party library
        }
        return bitmapImage.representation(using: fileType, properties: [:])
    }
    
    func crop(to rect: CGRect) -> NSImage? {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        guard let croppedCgImage = cgImage.cropping(to: rect) else { return nil }
        return NSImage(cgImage: croppedCgImage, size: rect.size)
    }
}

// --- CIFilter Enum ---
enum FilterType: String, CaseIterable, Identifiable {
    case none, sepia, noir, chrome, instant, process, vignette, photoEffectMono, comicEffect, crystalize, pointillize, bloom, gloom, sharpenLuminance, unsharpMask, gaussianBlur, pixellate, thermal, xray
    var id: String { self.rawValue }
    var name: String {
        switch self {
        case .none: return "None"; case .sepia: return "Sepia"; case .noir: return "Noir"; case .chrome: return "Chrome"; case .instant: return "Instant"; case .process: return "Process"; case .vignette: return "Vignette"; case .photoEffectMono: return "Mono"; case .comicEffect: return "Comic"; case .crystalize: return "Crystallize"; case .pointillize: return "Pointillize"; case .bloom: return "Bloom"; case .gloom: return "Gloom"; case .sharpenLuminance: return "Sharpen"; case .unsharpMask: return "Unsharp Mask"; case .gaussianBlur: return "Blur"; case .pixellate: return "Pixellate"; case .thermal: return "Thermal"; case .xray: return "X-Ray"
        }
    }
    var filter: CIFilter {
        switch self {
        case .none: return CIFilter()
        case .sepia: return .sepiaTone()
        case .noir: return .photoEffectNoir()
        case .chrome: return .photoEffectChrome()
        case .instant: return .photoEffectInstant()
        case .process: return .photoEffectProcess()
        case .vignette: return .vignette()
        case .photoEffectMono: return .photoEffectMono()
        case .comicEffect: return .comicEffect()
        case .crystalize: return .crystallize()
        case .pointillize: return .pointillize()
        case .bloom: return .bloom()
        case .gloom: return .gloom()
        case .sharpenLuminance: return .sharpenLuminance()
        case .unsharpMask: return .unsharpMask()
        case .gaussianBlur: return .gaussianBlur()
        case .pixellate: return .pixellate()
        case .thermal: return .thermal()
        case .xray: return .xRay()
        }
    }
}
