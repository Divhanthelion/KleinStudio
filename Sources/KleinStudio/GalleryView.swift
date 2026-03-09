import SwiftUI
import AppKit

struct GalleryView: View {
    @StateObject private var workspace = WorkspaceManager.shared
    @State private var showingNewFolderDialog = false
    @State private var newFolderName = ""
    @State private var imageToEdit: NSImage?
    @State private var editingItemURL: URL?
    
    let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Path & Controls
            HStack {
                Button(action: {
                    if workspace.currentFolderURL != workspace.rootURL {
                        workspace.currentFolderURL = workspace.currentFolderURL.deletingLastPathComponent()
                        workspace.refreshContents()
                    }
                }) {
                    Image(systemName: "chevron.left")
                }
                .disabled(workspace.currentFolderURL == workspace.rootURL)
                
                Text(workspace.currentFolderURL.lastPathComponent)
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    showingNewFolderDialog = true
                }) {
                    Label("New Folder", systemImage: "folder.badge.plus")
                }
                
                Button(action: {
                    workspace.refreshContents()
                }) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(workspace.contents, id: \.id) { item in
                        GalleryItemView(item: item) { url in
                            if item.isDirectory {
                                workspace.currentFolderURL = url
                                workspace.refreshContents()
                            } else {
                                if let img = NSImage(contentsOf: url) {
                                    imageToEdit = img
                                    editingItemURL = url
                                }
                            }
                        } onRename: { newName in
                            workspace.renameItem(at: item.url, newName: newName)
                        } onDelete: {
                            workspace.deleteItem(at: item.url)
                        }
                    }
                }
                .padding()
            }
        }
        .sheet(isPresented: $showingNewFolderDialog) {
            VStack(spacing: 16) {
                Text("New Folder")
                    .font(.headline)
                TextField("Folder Name", text: $newFolderName)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button("Cancel") {
                        showingNewFolderDialog = false
                    }
                    Button("Create") {
                        workspace.createFolder(name: newFolderName)
                        newFolderName = ""
                        showingNewFolderDialog = false
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newFolderName.isEmpty)
                }
            }
            .padding()
            .frame(width: 300)
        }
        .sheet(item: Binding(
            get: { imageToEdit.map { WrappedImage(image: $0) } },
            set: { imageToEdit = $0?.image }
        )) { wrapper in
            ImageEditorView(viewModel: ImageEditorViewModel(image: wrapper.image)) { editedImage in
                // Save edited copy back to workspace
                workspace.saveImage(editedImage, prompt: "Edited_\(editingItemURL?.deletingPathExtension().lastPathComponent ?? "Image")")
            }
        }
    }
}

// Helper wrapper for sheet binding
struct WrappedImage: Identifiable {
    let id = UUID()
    let image: NSImage
}

struct GalleryItemView: View {
    let item: FolderItem
    let onSelect: (URL) -> Void
    let onRename: (String) -> Void
    let onDelete: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        VStack {
            if item.isDirectory {
                Image(systemName: "folder.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.blue)
                    .frame(height: 100)
            } else {
                if let nsImage = NSImage(contentsOf: item.url) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 150, height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(radius: 2)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 150, height: 150)
                        .overlay(Image(systemName: "doc.text.image"))
                }
            }
            
            Text(item.name)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(8)
        .background(isHovering ? Color.secondary.opacity(0.1) : Color.clear)
        .cornerRadius(12)
        .onHover { hover in
            isHovering = hover
        }
        .onTapGesture {
            onSelect(item.url)
        }
        .contextMenu {
            if !item.isDirectory {
                Button("Edit Image") {
                    onSelect(item.url)
                }
                
                Button("Copy for iMessage (Compressed)") {
                    if let nsImage = NSImage(contentsOf: item.url),
                       let tiffData = nsImage.tiffRepresentation,
                       let bitmapImage = NSBitmapImageRep(data: tiffData),
                       // Compress to a highly efficient JPEG
                       let jpegData = bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: 0.6]) {
                        
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setData(jpegData, forType: .jpeg)
                    }
                }
            }
            
            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
    }
}
