import SwiftUI
import UniformTypeIdentifiers
import SipfolioCore

struct CocktailPhotoEditorView: View {
    let recipeID: UUID
    let store: CollectionStore
    @Environment(\.dismiss) private var dismiss
    private let imageService = BottleCutoutService()
    @State private var original: Data?
    @State private var loading = false
    @State private var loadTask: Task<Void, Never>?
    @State private var loadID = UUID()
    @State private var choosingPhoto = false
    @State private var saving = false
    @State private var metadata: CocktailPhotoMetadata?
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("成品照片").font(.pixel(size: 23, weight: .bold))
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark").padding(8) }.buttonStyle(.plain).disabled(saving)
            }
            Text("保留照片的完整背景，收藏墙会统一图片展示尺寸。")
                .font(.pixel(size: 12)).foregroundStyle(Palette.muted)
            ZStack {
                PixelFrame(cornerRadius: 14).fill(Palette.purple.opacity(0.06))
                if loading { ProgressView("正在读取照片…") }
                else { PhotoView(data: original).padding(16) }
            }.frame(maxWidth: .infinity).frame(height: 318).clipShape(PixelFrame(cornerRadius: 14))
            Button("导入自己的照片") { choosingPhoto = true }.buttonStyle(.borderless).tint(Palette.purple)
                .font(.pixel(size: 11)).disabled(loading)
            Spacer(minLength: 0)
            HStack {
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button(saving ? "正在保存…" : "保存照片") { save() }.buttonStyle(PrimaryButton())
                    .disabled(original == nil || loading || saving)
            }
        }.padding(26).frame(width: 620, height: 600).background(Palette.paper).foregroundStyle(Palette.ink).font(.pixel(size: 12)).buttonStyle(PixelSecondaryButton()).preferredColorScheme(.light).disabled(saving)
            .interactiveDismissDisabled(saving)
            .fileImporter(isPresented: $choosingPhoto, allowedContentTypes: [.image]) { result in
                switch result {
                case .success(let url): loadPhoto(url)
                case .failure(let error): self.error = error.localizedDescription
                }
            }
            .onAppear {
                let url = store.cocktailImages.imageURL(for: recipeID, original: true)
                if FileManager.default.fileExists(atPath: url.path) { loadPhoto(url, metadata: try? store.cocktailPhotoMetadata(for: recipeID)) }
                else { choosingPhoto = true }
            }
            .onDisappear { loadID = UUID(); loadTask?.cancel() }
            .alert("照片操作未完成", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("好", role: .cancel) { error = nil }
            } message: { Text(error ?? "请重试。") }
    }

    private func loadPhoto(_ url: URL, metadata incomingMetadata: CocktailPhotoMetadata? = nil) {
        loadTask?.cancel()
        let token = UUID()
        loadID = token; loading = true
        loadTask = Task { @MainActor in
            defer { if token == loadID { loading = false } }
            do {
                let photo = try await imageService.loadPhoto(at: url)
                guard !Task.isCancelled, token == loadID else { return }
                original = photo; metadata = incomingMetadata
            } catch {
                if !Task.isCancelled, token == loadID { self.error = error.localizedDescription }
            }
        }
    }

    private func save() {
        guard let original else { return }
        saving = true
        Task { @MainActor in
            defer { saving = false }
            do {
                let thumbnail = try await imageService.normalizedPNG(from: original, maxPixelSize: 420)
                let info = CocktailPhotoMetadata(provider: metadata?.provider ?? "自己的照片", pageURL: metadata?.pageURL, photoURL: metadata?.photoURL, photoSourceURL: metadata?.photoSourceURL, credit: metadata?.credit ?? "", creativeCommonsConfirmed: metadata?.creativeCommonsConfirmed ?? false, usesOriginalPhoto: true)
                try store.saveCocktailPhoto(id: recipeID, original: original, sticker: original, thumbnail: thumbnail, metadata: info)
                dismiss()
            } catch { self.error = error.localizedDescription }
        }
    }
}
