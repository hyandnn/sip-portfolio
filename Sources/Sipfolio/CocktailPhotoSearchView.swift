import SwiftUI
import SipfolioCore

struct CocktailPhotoSearchView: View {
    let recipeID: UUID
    let recipeName: String
    let store: CollectionStore
    let service: CocktailPhotoService
    @Environment(\.dismiss) private var dismiss
    @State private var query: String
    @State private var resultTerm: String
    @State private var candidates: [CocktailPhotoCandidate]
    @State private var previews: [String: Data]
    @State private var failedPreviews: Set<String> = []
    @State private var selectedID: String?
    @State private var enlargedCandidate: CocktailPhotoCandidate?
    @State private var showingAlternatives = false
    @State private var searching = false
    @State private var saving = false
    @State private var searched = false
    @State private var notices: [String] = []
    @State private var error: String?
    @State private var searchTask: Task<Void, Never>?
    @State private var searchID = UUID()
    @State private var previewTasks: [String: Task<Void, Never>] = [:]
    @State private var hasAppeared = false
    private let seeded: Bool

    init(recipeID: UUID, recipeName: String, store: CollectionStore, service: CocktailPhotoService = CocktailPhotoService(), candidates: [CocktailPhotoCandidate] = [], previews: [String: Data] = [:]) {
        self.recipeID = recipeID; self.recipeName = recipeName; self.store = store; self.service = service
        _query = State(initialValue: CocktailNames.lookupName(recipeName))
        _resultTerm = State(initialValue: CocktailNames.lookupName(recipeName))
        _candidates = State(initialValue: candidates); _previews = State(initialValue: previews)
        _selectedID = State(initialValue: candidates.first(where: { previews[$0.id] != nil })?.id)
        _searched = State(initialValue: !candidates.isEmpty)
        seeded = !candidates.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("成品照片").font(.pixel(size: 24))
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark").padding(8) }.buttonStyle(.plain).disabled(saving)
            }
            Text("为 \(recipeName) 优先显示最佳匹配，也可以换一张。")
                .foregroundStyle(Palette.muted).lineLimit(2)
            HStack(spacing: 12) {
                TextField("鸡尾酒英文名或搜索关键词", text: $query).textFieldStyle(PixelTextFieldStyle())
                    .onSubmit { search() }
                Button(searching ? "停止搜索" : "搜索") {
                    if searching { stopSearch() } else { search() }
                }.disabled(!searching && CocktailNames.imageSearchTerm(query).isEmpty || saving)
            }
            if searching { HStack { ProgressView().controlSize(.small); Text("正在搜索成品图…").foregroundStyle(Palette.muted) } }
            else if searched {
                HStack {
                    Text("\(candidates.count) 张候选 · \(resultTerm)").foregroundStyle(Palette.muted).lineLimit(1)
                    Spacer()
                    if candidates.count > 1 {
                        Button(showingAlternatives ? "只看最佳匹配" : "看看其他照片") { showingAlternatives.toggle() }.buttonStyle(.borderless)
                    }
                    Button("重新联网搜索") { search(refresh: true) }
                        .buttonStyle(.borderless).disabled(CocktailNames.imageSearchTerm(query).isEmpty)
                }
            }
            if !notices.isEmpty {
                Text(notices.joined(separator: "\n")).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
            }
            ScrollView {
                if searched && candidates.isEmpty && !searching {
                    VStack(spacing: 16) {
                        PixelGlyph(kind: .glass, size: 45)
                        Text("暂未找到合适照片")
                        Text("可以试试英文名或另一种写法，也可以导入自己的照片。")
                            .foregroundStyle(Palette.muted)
                    }.frame(maxWidth: .infinity).padding(.vertical, 60)
                } else {
                    VStack(spacing: 16) {
                        if !showingAlternatives, let best = candidates.first {
                            candidateCard(best, prominent: true)
                        } else {
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible())], spacing: 16) {
                                ForEach(candidates) { candidate in candidateCard(candidate) }
                            }
                        }
                    }.padding(3)
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack {
                Text(saving ? "正在核对来源并保存…" : "照片保留完整背景，下载后可离线查看。")
                    .foregroundStyle(Palette.muted)
                Spacer()
                Button("采用照片") { save() }.buttonStyle(PrimaryButton())
                    .disabled(selectedID == nil || selectedID.flatMap { previews[$0] } == nil || saving || searching)
            }
        }.padding(26).frame(width: 740, height: 710).background(Palette.paper).foregroundStyle(Palette.ink)
            .font(.pixel(size: 12)).buttonStyle(PixelSecondaryButton()).preferredColorScheme(.light)
            .disabled(saving).interactiveDismissDisabled(saving)
            .onAppear {
                guard !hasAppeared else { return }
                hasAppeared = true
                if seeded { loadPreviews(token: searchID) } else { search() }
            }
            .onDisappear { cancelTasks() }
            .sheet(item: $enlargedCandidate) { candidate in
                CocktailCandidatePreview(candidate: candidate, data: previews[candidate.id]) {
                    selectedID = candidate.id
                    enlargedCandidate = nil
                }
            }
            .alert("照片操作未完成", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("好", role: .cancel) { error = nil }
            } message: { Text(error ?? "请重试。") }
    }

    private func candidateCard(_ candidate: CocktailPhotoCandidate, prominent: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { selectedID = candidate.id } label: {
                ZStack {
                    Palette.sidebar
                    if let data = previews[candidate.id], let image = NSImage(data: data) {
                        GeometryReader { proxy in
                            Image(nsImage: image).resizable().aspectRatio(contentMode: prominent ? .fit : .fill)
                                .frame(width: proxy.size.width, height: proxy.size.height).clipped()
                        }
                    } else if failedPreviews.contains(candidate.id) {
                        Text("预览暂时不可用").foregroundStyle(Palette.muted)
                    } else { ProgressView().controlSize(.small) }
                }.frame(height: prominent ? 230 : 142).clipShape(PixelFrame(cornerRadius: 9))
            }.buttonStyle(.plain).disabled(previews[candidate.id] == nil).accessibilityLabel("选择照片：\(candidate.title)")
            Text(candidate.title).lineLimit(2).frame(height: 32, alignment: .topLeading)
            Text(candidate.provider).foregroundStyle(Palette.purple).lineLimit(1)
            Text("\(candidate.credit) · \(candidate.license)").foregroundStyle(Palette.muted).lineLimit(1)
            HStack {
                Link("查看原始页面", destination: candidate.pageURL)
                Spacer()
                if failedPreviews.contains(candidate.id) {
                    Button("重试预览") { retryPreview(candidate) }.buttonStyle(.borderless)
                } else {
                    Button("查看大图") { enlargedCandidate = candidate }.buttonStyle(.borderless)
                        .disabled(previews[candidate.id] == nil)
                }
            }
            HStack {
                Text(selectedID == candidate.id ? "已选择" : "核对画面后选择").foregroundStyle(Palette.muted)
                Spacer()
                Button(selectedID == candidate.id ? "已选择" : "选择这张") { selectedID = candidate.id }.buttonStyle(.borderless)
                    .disabled(previews[candidate.id] == nil)
            }
        }.padding(12).background(.white, in: PixelFrame(cornerRadius: 10))
            .overlay(PixelFrame(cornerRadius: 10).stroke(selectedID == candidate.id ? Palette.purple : Palette.line, lineWidth: selectedID == candidate.id ? 3 : 2))
    }

    private func search(refresh: Bool = false) {
        guard !saving, !CocktailNames.imageSearchTerm(query).isEmpty else { return }
        cancelTasks()
        let token = UUID(); searchID = token
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        resultTerm = term
        searching = true; searched = true; candidates = []; previews = [:]; failedPreviews = []; selectedID = nil; notices = []; showingAlternatives = false
        searchTask = Task { @MainActor in
            do {
                let result = try await service.search(name: term, refresh: refresh)
                guard !Task.isCancelled, searchID == token else { return }
                candidates = result.candidates; notices = result.notices; resultTerm = term; searching = false
                await fetchPreviews(token: token)
                guard !Task.isCancelled, searchID == token else { return }
                if selectedID == nil { selectedID = candidates.first(where: { previews[$0.id] != nil })?.id }
                if !FileManager.default.fileExists(atPath: store.cocktailImages.imageURL(for: recipeID, original: true).path),
                   try store.cocktailPhotoMetadata(for: recipeID) == nil, selectedID != nil { save() }
            } catch {
                guard !Task.isCancelled, searchID == token else { return }
                searching = false; notices = [error.localizedDescription]
            }
        }
    }

    private func loadPreviews(token: UUID) {
        searchTask = Task { @MainActor in
            await fetchPreviews(token: token)
            guard !Task.isCancelled, searchID == token else { return }
            if selectedID == nil { selectedID = candidates.first(where: { previews[$0.id] != nil })?.id }
        }
    }
    private func cancelTasks() {
        searchID = UUID()
        searchTask?.cancel()
        for task in previewTasks.values { task.cancel() }
        previewTasks = [:]
    }
    private func stopSearch() {
        cancelTasks()
        searching = false
        notices = ["搜索已停止，可以修改关键词后重试。"]
    }
    private func retryPreview(_ candidate: CocktailPhotoCandidate) {
        guard !saving, !searching, previewTasks[candidate.id] == nil else { return }
        let token = searchID
        failedPreviews.remove(candidate.id)
        previewTasks[candidate.id] = Task { @MainActor in
            do {
                let data = try await service.preview(candidate, refresh: true)
                let image = try await BottleCutoutService().normalizedPNG(from: data, maxPixelSize: 1000)
                guard !Task.isCancelled, searchID == token else { return }
                previews[candidate.id] = image
            } catch {
                guard !Task.isCancelled, searchID == token else { return }
                failedPreviews.insert(candidate.id)
            }
            if searchID == token { previewTasks[candidate.id] = nil }
        }
    }
    private func fetchPreviews(token: UUID) async {
        let missing = candidates.filter { previews[$0.id] == nil }
        await withTaskGroup(of: (String, Data?).self) { group in
            for candidate in missing {
                group.addTask {
                    do {
                        let data = try await service.preview(candidate)
                        let thumbnail = try await BottleCutoutService().normalizedPNG(from: data, maxPixelSize: 1000)
                        return (candidate.id, thumbnail)
                    } catch { return (candidate.id, nil) }
                }
            }
            for await (id, data) in group {
                guard !Task.isCancelled, searchID == token else { group.cancelAll(); return }
                if let data { previews[id] = data } else { failedPreviews.insert(id) }
            }
        }
    }

    private func save() {
        guard !saving, !searching, let candidate = candidates.first(where: { $0.id == selectedID }), previews[candidate.id] != nil else { return }
        let oldMetadata = try? store.cocktailPhotoMetadata(for: recipeID)
        let term = resultTerm
        saving = true
        cancelTasks()
        searchTask = Task { @MainActor in
            do {
                let (data, metadata) = try await service.download(candidate, searchTerm: term)
                let imageService = BottleCutoutService()
                let original = try await imageService.normalizedPNG(from: data, maxPixelSize: 1600)
                let thumbnail = try await imageService.normalizedPNG(from: original, maxPixelSize: 420)
                try Task.checkCancellation()
                guard let recipe = try store.allCocktails().first(where: { $0.id == recipeID }), recipe.name == recipeName,
                      try store.cocktailPhotoMetadata(for: recipeID) == oldMetadata else {
                    saving = false; error = "配方名称或照片已发生变化，请重新打开后选择。"; return
                }
                try store.saveCocktailPhoto(id: recipeID, original: original, sticker: original, thumbnail: thumbnail, metadata: metadata)
                dismiss()
            } catch { saving = false; if !Task.isCancelled { self.error = error.localizedDescription } }
        }
    }
}

struct CocktailCandidatePreview: View {
    let candidate: CocktailPhotoCandidate
    let data: Data?
    let select: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("核对完整画面").font(.pixel(size: 24))
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark").padding(8) }.buttonStyle(.plain)
                    .accessibilityLabel("关闭照片预览")
            }
            if let data, let image = NSImage(data: data) {
                Image(nsImage: image).resizable().scaledToFit().frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Palette.sidebar, in: PixelFrame(cornerRadius: 10))
            }
            Text(candidate.title).lineLimit(3)
            Text("\(candidate.credit) · \(candidate.license)").foregroundStyle(Palette.muted)
            HStack {
                Link("查看原始页面", destination: candidate.pageURL)
                Spacer()
                Button("选择这张") { select() }.buttonStyle(PrimaryButton()).disabled(data == nil)
            }
        }.padding(24).frame(width: 650, height: 600).background(Palette.paper).foregroundStyle(Palette.ink)
            .font(.pixel(size: 12)).buttonStyle(PixelSecondaryButton()).preferredColorScheme(.light)
    }
}
