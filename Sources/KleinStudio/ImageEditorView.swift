import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

class ImageEditorViewModel: ObservableObject {
    @Published var image: NSImage
    @Published var originalImage: NSImage
    @Published var brightness: Float = 0.0
    @Published var contrast: Float = 1.0
    @Published var saturation: Float = 1.0
    
    let context = CIContext()
    
    init(image: NSImage) {
        self.image = image
        self.originalImage = image
    }
    
    func applyFilters() {
        guard let tiffData = originalImage.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let ciImage = CIImage(bitmapImageRep: bitmapImage) else { return }
        
        let filter = CIFilter.colorControls()
        filter.inputImage = ciImage
        filter.brightness = brightness
        filter.contrast = contrast
        filter.saturation = saturation
        
        guard let outputImage = filter.outputImage,
              let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else { return }
        
        let size = NSSize(width: cgImage.width, height: cgImage.height)
        self.image = NSImage(cgImage: cgImage, size: size)
    }
    
    func reset() {
        brightness = 0.0
        contrast = 1.0
        saturation = 1.0
        image = originalImage
    }
}

struct ImageEditorView: View {
    @StateObject var viewModel: ImageEditorViewModel
    @Environment(\.dismiss) var dismiss
    let onSave: (NSImage) -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(nsImage: viewModel.image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.1))
                .cornerRadius(12)
            
            VStack(spacing: 16) {
                HStack {
                    Text("Brightness")
                    Slider(value: $viewModel.brightness, in: -1...1)
                        .onChange(of: viewModel.brightness) { viewModel.applyFilters() }
                }
                HStack {
                    Text("Contrast")
                    Slider(value: $viewModel.contrast, in: 0...2)
                        .onChange(of: viewModel.contrast) { viewModel.applyFilters() }
                }
                HStack {
                    Text("Saturation")
                    Slider(value: $viewModel.saturation, in: 0...2)
                        .onChange(of: viewModel.saturation) { viewModel.applyFilters() }
                }
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))
            .cornerRadius(12)
            
            HStack {
                Button("Reset") {
                    viewModel.reset()
                }
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                Button("Save Copy") {
                    onSave(viewModel.image)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(minWidth: 500, minHeight: 600)
    }
}
