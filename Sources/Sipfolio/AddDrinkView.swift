import SwiftUI
import Observation
import UniformTypeIdentifiers
import SipfolioCore

@MainActor @Observable
final class ImportDraft {
    var original: Data?
    var candidates: [CutoutCandidate] = []
    var selectedID: Int?
    var usesOriginal = false
    var isLoading = false
    var isCutting = false
    var warning: String?
    var name = ""
    var category = ""
    var notes = ""
    var tasteVariant = ""
    var bottleYear = ""
    var collectionDate = Date.now
    var isRecognizing = false
    var aiError: String?
    var aiSuggestion: DrinkKnowledge?
    var acceptedKnowledge: DrinkKnowledge?
    var includeRecommendedCocktails = true
    let service = BottleCutoutService()
    private var task: Task<Void, Never>?
    private var generation = 0
    private var recognitionTask: Task<Void, Never>?
    private var recognitionGeneration = 0

    var sticker: Data? {
        if usesOriginal { return original }
        return candidates.first { $0.id == selectedID }?.png
    }
    var canSave: Bool {
        !isLoading && !isCutting && !isRecognizing && sticker != nil && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func importPhoto(_ url: URL) {
        cancel()
        let token = generation
        original = nil; candidates = []; selectedID = nil; usesOriginal = false; warning = nil
        isLoading = true
        task = Task {
            do {
                let photo = try await service.loadPhoto(at: url)
                guard !Task.isCancelled, token == generation else { return }
                original = photo; isLoading = false; isCutting = true
                await performCutout(photo, token: token)
            } catch {
                guard !Task.isCancelled, token == generation else { return }
                isLoading = false; warning = error.localizedDescription
            }
        }
    }

    func retryCutout() {
        guard let original else { return }
        cancel()
        let token = generation
        warning = nil; isCutting = true
        task = Task { await performCutout(original, token: token) }
    }

    private func performCutout(_ data: Data, token: Int) async {
        do {
            let result = try await service.cutout(from: data)
            guard !Task.isCancelled, token == generation else { return }
            candidates = result; selectedID = result.first?.id; usesOriginal = false; isCutting = false
        } catch {
            guard !Task.isCancelled, token == generation else { return }
            isCutting = false
            warning = "这张照片暂时无法自动抠图。你可以重试、换一张照片，或使用原图收藏。"
        }
    }

    func cancel() {
        task?.cancel(); task = nil; generation += 1; isLoading = false; isCutting = false
        clearAI()
    }

    func clearAI() {
        recognitionTask?.cancel(); recognitionTask = nil; recognitionGeneration += 1
        isRecognizing = false; aiError = nil; aiSuggestion = nil; acceptedKnowledge = nil
    }

    func recognize() {
        guard let photo = sticker ?? original, !isLoading, !isCutting else { return }
        recognitionTask?.cancel(); recognitionGeneration += 1
        let token = recognitionGeneration
        let nameHint = name
        isRecognizing = true; aiError = nil; aiSuggestion = nil
        recognitionTask = Task {
            do {
                guard let key = try await Task.detached(operation: { try DeepSeekKeychain.load() }).value else { throw DeepSeekError.missingKey }
                let jpeg = try await service.jpegForRecognition(from: photo)
                let result = try await DeepSeekService(apiKey: key).identify(jpeg: jpeg, nameHint: nameHint)
                guard !Task.isCancelled, token == recognitionGeneration else { return }
                isRecognizing = false; aiSuggestion = result
            } catch {
                guard !Task.isCancelled, token == recognitionGeneration else { return }
                isRecognizing = false; aiError = error.localizedDescription
            }
        }
    }

    func accept(_ knowledge: DrinkKnowledge) {
        if let name = knowledge.name { self.name = name }
        if let category = knowledge.category { self.category = category }
        acceptedKnowledge = knowledge
    }
}

struct AddDrinkView: View {
    let store: CollectionStore
    var initialURL: URL?
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ImportDraft()
    @State private var fileImporter = false
    @State private var previewOriginal = false
    @State private var saving = false
    @State private var saveError: String?
    @State private var saveTask: Task<Void, Never>?
    @State private var showingSuggestion = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("ADD TO YOUR COLLECTION").font(.pixel(size: 8, weight: .semibold, design: .monospaced)).tracking(1.8).foregroundStyle(Palette.purple)
                    Text("收藏一瓶新故事").font(.pixel(size: 23, weight: .bold))
                }
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark").font(.pixel(size: 12)).padding(9).background(.black.opacity(0.04), in: PixelFrame(cornerRadius: 4)) }
                    .buttonStyle(.plain).disabled(saving).accessibilityLabel("关闭新收藏")
            }.padding(26)
            Rectangle().fill(Palette.line).frame(height: 1)
            ScrollView {
                HStack(alignment: .top, spacing: 26) {
                    previewColumn.frame(width: 306).disabled(saving || draft.isRecognizing)
                    informationColumn.frame(maxWidth: .infinity, alignment: .leading)
                }.padding(26)
            }
            Spacer(minLength: 0)
            Rectangle().fill(Palette.line).frame(height: 1)
            HStack {
                Label("只保存在你的 Mac 上", systemImage: "lock.fill").font(.pixel(size: 10)).foregroundStyle(Palette.muted)
                Spacer()
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction).disabled(saving)
                Button {
                    save()
                } label: {
                    HStack(spacing: 7) {
                        if saving { ProgressView().controlSize(.small).tint(.white) }
                        Text(saving ? "正在保存…" : "加入收藏册")
                        if !saving { Image(systemName: "arrow.right") }
                    }
                }.buttonStyle(PrimaryButton()).disabled(!draft.canSave || saving)
                    .opacity(draft.canSave || saving ? 1 : 0.45).keyboardShortcut(.defaultAction)
            }.padding(.horizontal, 26).padding(.vertical, 19)
        }.frame(width: 736, height: 740).background(Palette.paper).foregroundStyle(Palette.ink).font(.pixel(size: 12)).buttonStyle(PixelSecondaryButton())
            .preferredColorScheme(.light)
            .interactiveDismissDisabled(saving)
            .fileImporter(isPresented: $fileImporter, allowedContentTypes: [.image]) { result in
                switch result {
                case .success(let url): previewOriginal = false; draft.importPhoto(url)
                case .failure(let error): draft.warning = error.localizedDescription
                }
            }
            .dropDestination(for: URL.self) { urls, _ in
                guard let url = urls.first, !saving else { return false }
                previewOriginal = false; draft.importPhoto(url); return true
            }
            .onAppear { if let initialURL { draft.importPhoto(initialURL) } }
            .onDisappear { draft.cancel(); saveTask?.cancel() }
            .onChange(of: draft.selectedID) { _, _ in draft.clearAI() }
            .onChange(of: draft.usesOriginal) { _, _ in draft.clearAI() }
            .onChange(of: draft.aiSuggestion) { _, value in showingSuggestion = value != nil }
            .sheet(isPresented: $showingSuggestion) {
                if let knowledge = draft.aiSuggestion {
                    AISuggestionView(knowledge: knowledge, currentName: draft.name, currentCategory: draft.category, categoryHistory: (try? store.allDrinks().map(\.category)) ?? []) { draft.accept($0) }
                }
            }
            .alert("未能保存收藏", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
                Button("好", role: .cancel) { saveError = nil }
            } message: { Text(saveError ?? "请重试。") }
    }

    private var previewColumn: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text("01 / 你的酒瓶贴纸").font(.pixel(size: 11, weight: .semibold))
                Spacer()
                if draft.original != nil {
                    Picker("预览", selection: $previewOriginal) {
                        Text("贴纸").tag(false)
                        Text("原图").tag(true)
                    }.pickerStyle(.segmented).labelsHidden().frame(width: 116)
                }
            }
            ZStack {
                Checkerboard().clipShape(PixelFrame(cornerRadius: 14))
                if draft.isLoading || draft.isCutting {
                    VStack(spacing: 14) {
                        if let original = draft.original { PhotoView(data: original).frame(height: 178).opacity(0.3) }
                        ProgressView().controlSize(.regular)
                        Text(draft.isLoading ? "正在读取照片…" : "正在制作专属贴纸…").font(.pixel(size: 11)).foregroundStyle(Palette.muted)
                    }
                } else if draft.original != nil {
                    PhotoView(data: previewOriginal ? draft.original : (draft.sticker ?? draft.original))
                        .padding(24).shadow(color: .black.opacity(0.12), radius: 9, y: 8)
                } else {
                    VStack(spacing: 15) {
                        Image(systemName: "photo.badge.plus").font(.pixel(size: 34, weight: .light)).foregroundStyle(Palette.purple.opacity(0.6))
                        Text("从一张酒瓶照片开始").font(.pixel(size: 12, weight: .medium))
                        Button("选择照片") { fileImporter = true }.buttonStyle(PrimaryButton())
                        Text("JPEG、PNG、HEIC 等 · 最大 50 MB").font(.pixel(size: 9)).foregroundStyle(Palette.muted)
                    }
                }
            }.frame(height: 304)
                .overlay(PixelFrame(cornerRadius: 14).stroke(Palette.line))
            if draft.original != nil {
                HStack {
                    Button("换张照片") { fileImporter = true }.buttonStyle(.borderless).disabled(saving)
                    Spacer()
                    if draft.sticker != nil && !draft.isCutting {
                        Label(draft.usesOriginal ? "原图收藏" : "贴纸已就绪", systemImage: "checkmark.circle.fill")
                            .font(.pixel(size: 10)).foregroundStyle(Palette.purple)
                    }
                }.font(.pixel(size: 11))
            }
            if draft.candidates.count > 1 && !draft.isCutting {
                Text("检测到多个主体，选出你的酒瓶：").font(.pixel(size: 10)).foregroundStyle(Palette.muted)
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(Array(draft.candidates.enumerated()), id: \.element.id) { index, candidate in
                            Button {
                                draft.selectedID = candidate.id; draft.usesOriginal = false; previewOriginal = false
                            } label: {
                                PhotoView(data: candidate.png).padding(6).frame(width: 46, height: 50)
                                    .background(.white, in: PixelFrame(cornerRadius: 7))
                                    .overlay(PixelFrame(cornerRadius: 7).stroke(draft.selectedID == candidate.id && !draft.usesOriginal ? Palette.purple : Palette.line, lineWidth: 2))
                            }.buttonStyle(.plain).accessibilityLabel("选择主体 \(index + 1)")
                        }
                    }
                }.scrollIndicators(.hidden)
            }
            aiRecognitionControls
        }
    }

    private var aiRecognitionControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { draft.recognize() } label: {
                HStack(spacing: 7) {
                    if draft.isRecognizing { ProgressView().controlSize(.small) }
                    else { Image(systemName: "sparkles") }
                    Text(draft.isRecognizing ? "正在识别这瓶酒…" : "AI 识别并补充信息")
                }.font(.pixel(size: 11, weight: .semibold))
            }.buttonStyle(.borderless).tint(Palette.purple)
                .disabled(draft.original == nil || draft.isLoading || draft.isCutting || draft.isRecognizing)
            Text("将所选酒瓶图发送至 DeepSeek，按你的 API 账户计费。")
                .font(.pixel(size: 9)).foregroundStyle(Palette.muted).lineSpacing(3)
            if let aiError = draft.aiError {
                Text(aiError).font(.pixel(size: 10)).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
                SettingsLink { Text("打开 AI 设置") }.font(.pixel(size: 10))
            }
            if draft.acceptedKnowledge != nil {
                Label("已采用 AI 建议，酒款资料将一同保存", systemImage: "checkmark.circle.fill")
                    .font(.pixel(size: 9)).foregroundStyle(Palette.purple)
                if let count = draft.acceptedKnowledge?.cocktails.count, count > 0 {
                    Toggle("同时收录 \(count) 种推荐喝法到「蒙汗药」", isOn: $draft.includeRecommendedCocktails)
                        .toggleStyle(.checkbox).font(.pixel(size: 10))
                    Text("保存酒瓶后自动收录，并联网查找配方与成品图。")
                        .font(.pixel(size: 9)).foregroundStyle(Palette.muted)
                }
            }
        }
    }

    private var informationColumn: some View {
        VStack(alignment: .leading, spacing: 19) {
            Text("02 / 留下一点记忆").font(.pixel(size: 11, weight: .semibold)).padding(.bottom, 1)
            VStack(alignment: .leading, spacing: 8) {
                Text("酒名 *").font(.pixel(size: 11, weight: .medium))
                TextField("比如 Hendrick’s Gin", text: $draft.name)
                    .textFieldStyle(.plain).padding(11).background(.white, in: PixelFrame(cornerRadius: 8))
                    .overlay(PixelFrame(cornerRadius: 8).stroke(Palette.line)).accessibilityLabel("酒名")
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("类别").font(.pixel(size: 11, weight: .medium))
                CategoryInput(selection: $draft.category, history: (try? store.allDrinks().map(\.category)) ?? [])
            }
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("口味").font(.pixel(size: 11, weight: .medium))
                    TextField("如经典、佛手柑", text: $draft.tasteVariant)
                        .textFieldStyle(.plain).padding(11).background(.white, in: PixelFrame(cornerRadius: 8))
                        .overlay(PixelFrame(cornerRadius: 8).stroke(Palette.line)).accessibilityLabel("口味")
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("年份").font(.pixel(size: 11, weight: .medium))
                    TextField("如 2020（可留空）", text: $draft.bottleYear)
                        .textFieldStyle(.plain).padding(11).background(.white, in: PixelFrame(cornerRadius: 8))
                        .overlay(PixelFrame(cornerRadius: 8).stroke(Palette.line)).accessibilityLabel("年份")
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                DatePicker("收藏日期", selection: $draft.collectionDate, displayedComponents: .date)
                    .datePickerStyle(.field).font(.pixel(size: 11)).environment(\.locale, Locale(identifier: "zh_CN"))
                Text("可选择购买或收到这瓶酒的日期。")
                    .font(.pixel(size: 9)).foregroundStyle(Palette.muted)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("备注").font(.pixel(size: 11, weight: .medium))
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $draft.notes).scrollContentBackground(.hidden).padding(6)
                        .frame(height: 127).background(.white, in: PixelFrame(cornerRadius: 8))
                        .overlay(PixelFrame(cornerRadius: 8).stroke(Palette.line)).accessibilityLabel("备注")
                    if draft.notes.isEmpty {
                        Text("第一次喝它的地方，或你记住的味道…")
                            .font(.pixel(size: 11)).foregroundStyle(Palette.muted.opacity(0.7)).padding(12).allowsHitTesting(false)
                    }
                }
            }
            if let warning = draft.warning {
                VStack(alignment: .leading, spacing: 11) {
                    Label(warning, systemImage: "exclamationmark.circle").font(.pixel(size: 10)).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                    if draft.original != nil {
                        HStack {
                            Button("重新抠图") { draft.retryCutout() }.disabled(draft.isCutting)
                            Button("使用原图") { draft.usesOriginal = true; previewOriginal = false }
                        }.font(.pixel(size: 10)).buttonStyle(.borderless)
                    }
                }.padding(12).background(Color.orange.opacity(0.08), in: PixelFrame(cornerRadius: 9))
            } else if draft.original != nil && !draft.isCutting {
                Toggle("使用原图收藏", isOn: $draft.usesOriginal).toggleStyle(.checkbox).font(.pixel(size: 10)).foregroundStyle(Palette.muted)
            } else {
                Text("不必记住所有参数。\n名字和照片，就足够开启一个故事。")
                    .font(.pixel(size: 10)).lineSpacing(4).foregroundStyle(Palette.muted)
            }
        }.font(.pixel(size: 12)).disabled(saving)
    }

    private func save() {
        guard draft.canSave, let original = draft.original, let sticker = draft.sticker else { return }
        saving = true
        saveTask = Task { @MainActor in
            do {
                let thumbnail = try await draft.service.normalizedPNG(from: sticker, maxPixelSize: 420)
                try Task.checkCancellation()
                try store.add(name: draft.name, category: draft.category, notes: draft.notes, original: original, sticker: sticker, thumbnail: thumbnail, usesOriginalPhoto: draft.usesOriginal, knowledge: draft.acceptedKnowledge, tasteVariant: draft.tasteVariant, bottleYear: draft.bottleYear, collectionDate: draft.collectionDate, includeRecommendedCocktails: draft.includeRecommendedCocktails)
                saving = false; dismiss()
            } catch {
                saving = false
                if !(error is CancellationError) { saveError = error.localizedDescription }
            }
        }
    }
}

struct Checkerboard: View {
    var body: some View {
        Canvas { context, size in
            let tile: CGFloat = 14
            for row in 0...Int(size.height / tile) {
                for column in 0...Int(size.width / tile) {
                    let color = (row + column).isMultiple(of: 2) ? Color.white : Color(red: 0.96, green: 0.95, blue: 0.94)
                    context.fill(Path(CGRect(x: CGFloat(column) * tile, y: CGFloat(row) * tile, width: tile, height: tile)), with: .color(color))
                }
            }
        }.accessibilityHidden(true)
    }
}
