import SwiftUI
import AppKit
import Combine

// MARK: - Process Manager
class PythonProcessManager: ObservableObject {
    private var process: Process?
    @Published var isServerRunning = false
    
    func startServer() {
        guard process == nil else { return }
        
        let task = Process()
        let pipe = Pipe()
        
        // Assuming the app is run via `swift run` from the project root
        let backendDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("backend").path
        let pythonPath = "\(backendDir)/.venv/bin/python"
        
        task.executableURL = URL(fileURLWithPath: pythonPath)
        task.arguments = [
            "-m",
            "uvicorn",
            "server:app",
            "--app-dir",
            backendDir,
            "--port",
            "8000",
            "--host",
            "127.0.0.1"
        ]
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            self.process = task
            self.isServerRunning = true
            print("Python backend started.")
            
            // Monitor output asynchronously
            let outHandle = pipe.fileHandleForReading
            outHandle.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty { return }
                if let str = String(data: data, encoding: .utf8) {
                    print("[Backend]: \(str)", terminator: "")
                }
            }
            
            task.terminationHandler = { [weak self] _ in
                DispatchQueue.main.async {
                    self?.isServerRunning = false
                    print("Python backend terminated.")
                }
            }
            
        } catch {
            print("Failed to start python backend: \(error)")
        }
    }
    
    func stopServer() {
        process?.terminate()
        process = nil
        isServerRunning = false
    }
}

// MARK: - Inference Client
struct GenerationResponse: Codable {
    let status: String
    let image_base64: String?
    let seed: Int?
}

class InferenceClient {
    static let shared = InferenceClient()
    
    // Custom URLSession with extended timeout for image generation
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300  // 5 minutes for request
        config.timeoutIntervalForResource = 600 // 10 minutes for resource
        return URLSession(configuration: config)
    }()
    
    func generate(prompt: String, steps: Int, guidance: Double, width: Int, height: Int) async throws -> NSImage {
        let url = URL(string: "http://127.0.0.1:8000/generate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "prompt": prompt,
            "steps": steps,
            "guidance": guidance,
            "width": width,
            "height": height
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpRes = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpRes.statusCode == 503 {
            throw NSError(domain: "Inference", code: 503, userInfo: [NSLocalizedDescriptionKey: "Model is still loading... please wait."])
        }
        
        guard httpRes.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown Error"
            throw NSError(domain: "Inference", code: httpRes.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
        
        let genRes = try JSONDecoder().decode(GenerationResponse.self, from: data)
        guard let b64 = genRes.image_base64, let imgData = Data(base64Encoded: b64), let nsImage = NSImage(data: imgData) else {
            throw NSError(domain: "Inference", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid image data from server."])
        }
        
        return nsImage
    }
}

// MARK: - SwiftUI View
struct MainView: View {
    @EnvironmentObject var processManager: PythonProcessManager
    
    var body: some View {
        TabView {
            StudioView()
                .tabItem {
                    Label("Studio", systemImage: "wand.and.stars")
                }
            
            GalleryView()
                .tabItem {
                    Label("Library", systemImage: "photo.on.rectangle")
                }
        }
    }
}

struct StudioView: View {
    @State private var prompt: String = "A cinematic photo of a robot painting a canvas, hyper-realistic, 8k"
    @State private var steps: Int = 4
    @State private var guidance: Double = 3.5
    
    @State private var isGenerating = false
    @State private var generatedImage: NSImage?
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationSplitView {
            // Sidebar Controls
            VStack(alignment: .leading, spacing: 20) {
                Text("FLUX.2 [klein] 9B")
                    .font(.headline)
                
                VStack(alignment: .leading) {
                    Text("Prompt")
                        .font(.caption)
                    TextField("Enter your prompt...", text: $prompt, axis: .vertical)
                        .lineLimit(4...8)
                        .textFieldStyle(.roundedBorder)
                        .font(.body)
                }
                
                VStack(alignment: .leading) {
                    Text("Inference Steps: \(steps)")
                        .font(.caption)
                    Slider(value: Binding(
                        get: { Double(steps) },
                        set: { steps = Int($0) }
                    ), in: 1...20, step: 1)
                }
                
                VStack(alignment: .leading) {
                    Text("Guidance Scale: \(guidance, specifier: "%.1f")")
                        .font(.caption)
                    Slider(value: $guidance, in: 1.0...10.0, step: 0.5)
                }
                
                Spacer()
                
                Button(action: {
                    Task {
                        await generateImage()
                    }
                }) {
                    if isGenerating {
                        ProgressView().controlSize(.small)
                            .padding(.horizontal, 10)
                    } else {
                        Text("Generate")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isGenerating || prompt.isEmpty)
                
            }
            .padding()
            .navigationSplitViewColumnWidth(min: 250, ideal: 300, max: 350)
            
        } detail: {
            // Main Canvas Area
            ZStack {
                Color.black.opacity(0.05).ignoresSafeArea()
                
                if let img = generatedImage {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                        .shadow(radius: 10)
                        .padding()
                } else if isGenerating {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Generating via MLX on Unified Memory...")
                            .foregroundColor(.secondary)
                    }
                } else {
                    VStack {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("Enter a prompt and click Generate")
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                }
                
                if let error = errorMessage {
                    VStack {
                        Spacer()
                        Text(error)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(8)
                            .padding()
                    }
                }
            }
            .background(.regularMaterial) // Liquid Glass styling
        }
    }
    
    @MainActor
    private func generateImage() async {
        isGenerating = true
        errorMessage = nil
        
        do {
            let img = try await InferenceClient.shared.generate(
                prompt: prompt,
                steps: steps,
                guidance: guidance,
                width: 1024,
                height: 1024
            )
            self.generatedImage = img
            WorkspaceManager.shared.saveImage(img, prompt: prompt)
        } catch {
            self.errorMessage = error.localizedDescription
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                if self.errorMessage == error.localizedDescription {
                    self.errorMessage = nil
                }
            }
        }
        
        isGenerating = false
    }
}

// MARK: - Application Entry
@main
struct KleinStudioApp: App {
    @StateObject private var processManager = PythonProcessManager()
    
    init() {
        // Required for Swift executable packages to receive keyboard input
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(processManager)
                .onAppear {
                    processManager.startServer()
                }
                .onDisappear {
                    processManager.stopServer()
                }
        }
        .windowStyle(.hiddenTitleBar)
    }
}
