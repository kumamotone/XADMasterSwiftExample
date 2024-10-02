import SwiftUI
import XADMasterSwift

struct ContentView: View {
    @State private var selectedFile: URL?
    @State private var extractedContents: [String] = []
    @State private var errorMessage: String?
    @State private var isFileImporterPresented = false
    @State private var tempDir: URL?
    @State private var archiveFormat: String = ""
    @State private var password: String = ""
    @State private var isPasswordRequired: Bool = false
    @State private var isPasswordAlertPresented: Bool = false

    var body: some View {
        NavigationView {
            List {
                ForEach(extractedContents.indices, id: \.self) { index in
                    HStack {
                        Text(extractedContents[index])
                        Spacer()
                        Button("抽出") {
                            extractSingleFile(at: index)
                        }
                    }
                }
            }
            .navigationTitle("アーカイブの内容")
            .toolbar {
                ToolbarItem {
                    Button(action: openFile) {
                        Label("ファイルを開く", systemImage: "folder")
                    }
                }
                ToolbarItem {
                    Button(action: openExtractedFolder) {
                        Label("解凍フォルダを開く", systemImage: "folder.badge.plus")
                    }
                    .disabled(tempDir == nil)
                }
            }
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.archive],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .alert("エラー", isPresented: Binding<Bool>(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Text(errorMessage ?? "")
        }
        .alert("パスワードが必要です", isPresented: $isPasswordAlertPresented) {
            TextField("パスワード", text: $password)
            Button("OK") {
                listContents(of: selectedFile!)
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("このアーカイブはパスワードで保護されています。���スワードを入力してください。")
        }
        .overlay(
            VStack {
                if !archiveFormat.isEmpty {
                    Text("アーカイブ形式: \(archiveFormat)")
                }
            }
            .padding()
            , alignment: .bottom
        )
    }

    private func openFile() {
        isFileImporterPresented = true
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            selectedFile = url
            print("Selected file: \(url.path)")
            getArchiveFormat(of: url)
            listContents(of: url)
        case .failure(let error):
            errorMessage = "ファイルの選択中にエラーが発生しました: \(error.localizedDescription)"
        }
    }

    private func listContents(of url: URL) {
        do {
            if isPasswordRequired {
                try XADMasterSwift.setPassword(for: url.path, password: password)
            }
            extractedContents = try XADMasterSwift.listContents(of: url.path)
            print("Listed contents: \(extractedContents)")
            isPasswordRequired = false
            isPasswordAlertPresented = false
        } catch {
            if (error as NSError).domain == "XADMasterSwift" && (error as NSError).code == 2 {
                isPasswordRequired = true
                isPasswordAlertPresented = true
            } else {
                print("Error listing contents: \(error)")
                errorMessage = "アーカイブの内容一覧の取得中にエラーが発生しました: \(error.localizedDescription)"
            }
        }
    }

    private func extractSingleFile(at index: Int) {
        guard let url = selectedFile else { return }
        let newTempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        do {
            try FileManager.default.createDirectory(at: newTempDir, withIntermediateDirectories: true, attributes: nil)
            if isPasswordRequired {
                try XADMasterSwift.setPassword(for: url.path, password: password)
            }
            try XADMasterSwift.extractFile(at: url.path, entryIndex: index, to: newTempDir.path)
            print("Extracted single file to: \(newTempDir.path)")
            tempDir = newTempDir
        } catch {
            print("Error extracting single file: \(error)")
            errorMessage = "ファイルの抽出中にエラーが発生しました: \(error.localizedDescription)"
        }
    }

    private func getArchiveFormat(of url: URL) {
        do {
            archiveFormat = try XADMasterSwift.getArchiveFormat(of: url.path)
            print("Archive format: \(archiveFormat)")
        } catch {
            print("Error getting archive format: \(error)")
            errorMessage = "アーカイブ形式の取得中にエラーが発生しました: \(error.localizedDescription)"
        }
    }

    private func openExtractedFolder() {
        guard let tempDir = tempDir else {
            errorMessage = "解凍されたフォルダが見つかりません"
            print("Attempted to open extracted folder, but tempDir is nil")
            return
        }
        print("Opening extracted folder: \(tempDir.path)")
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: tempDir.path)
    }
}

#Preview {
    ContentView()
}
