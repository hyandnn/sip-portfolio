import SwiftUI
import UniformTypeIdentifiers
import SipfolioCore

struct DrinkDetailView: View {
    let drink: Drink
    let store: CollectionStore
    let enrichment: CocktailEnrichmentCoordinator?
    var onCleanupWarning: (String) -> Void = { _ in }
    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    @State private var name = ""
    @State private var category = DrinkCategory.other.rawValue
    @State private var notes = ""
    @State private var tasteVariant = ""
    @State private var bottleYear = ""
    @State private var collectionDate = Date.now
    @State private var original = false
    @State private var confirmingDelete = false
    @State private var error: String?
    @State private var isDeleting = false
    @State private var knowledge: DrinkKnowledge?
    @State private var suggestion: DrinkKnowledge?
    @State private var recognizing = false
    @State private var aiTask: Task<Void, Never>?
    @State private var showingSuggestion = false
    @State private var recipeSeed: CocktailSeed?

    init(drink: Drink, store: CollectionStore, initiallyEditing: Bool = false, enrichment: CocktailEnrichmentCoordinator? = nil, onCleanupWarning: @escaping (String) -> Void = { _ in }) {
        self.drink = drink; self.store = store; self.enrichment = enrichment; self.onCleanupWarning = onCleanupWarning
        _editing = State(initialValue: initiallyEditing)
        _name = State(initialValue: drink.name)
        _category = State(initialValue: drink.category)
        _notes = State(initialValue: drink.notes)
        _tasteVariant = State(initialValue: drink.tasteVariant ?? "")
        _bottleYear = State(initialValue: drink.bottleYear ?? "")
        _collectionDate = State(initialValue: drink.collectionDate)
    }

    var body: some View {
        Group {
            if isDeleting {
                ProgressView("正在删除收藏…").frame(width: 700, height: 640)
            } else {
                detailContents
            }
        }
    }

    private var detailContents: some View {
        VStack(spacing: 0) {
            HStack {
                Text(editing ? "编辑收藏" : "COLLECTED MEMORIES")
                    .font(.pixel(size: 10, weight: .semibold, design: .monospaced)).tracking(1.5).foregroundStyle(Palette.muted)
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark").padding(8).background(.black.opacity(0.04), in: PixelFrame(cornerRadius: 4)) }
                    .buttonStyle(.plain).accessibilityLabel("关闭详情")
            }.padding(24)
            HStack(alignment: .top, spacing: 30) {
                VStack(spacing: 14) {
                    ZStack {
                        PixelFrame(cornerRadius: 18).fill(Palette.color(for: drink.category).opacity(0.4))
                        StoredPhoto(url: store.images.imageURL(for: drink.id, original: original))
                            .padding(30).shadow(color: .black.opacity(0.12), radius: 10, y: 8)
                    }.frame(width: 294, height: 358)
                    Picker("查看照片", selection: $original) { Text("收藏贴纸").tag(false); Text("原始照片").tag(true) }
                        .pickerStyle(.segmented).labelsHidden().frame(width: 208)
                    Button { exportSticker() } label: { Label("导出贴纸 PNG", systemImage: "square.and.arrow.up") }
                        .buttonStyle(.borderless).font(.pixel(size: 11)).tint(Palette.purple)
                }
                VStack(alignment: .leading, spacing: 18) {
                    if editing {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                TextField("酒名", text: $name).textFieldStyle(PixelTextFieldStyle()).accessibilityLabel("编辑酒名")
                        VStack(alignment: .leading, spacing: 8) {
                            Text("类别").font(.pixel(size: 11, weight: .medium))
                            CategoryInput(selection: $category, history: (try? store.allDrinks().map(\.category)) ?? [])
                        }
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("口味").font(.pixel(size: 11, weight: .medium))
                                TextField("如经典、佛手柑", text: $tasteVariant).textFieldStyle(PixelTextFieldStyle()).accessibilityLabel("编辑口味")
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                Text("年份").font(.pixel(size: 11, weight: .medium))
                                TextField("如 2020", text: $bottleYear).textFieldStyle(PixelTextFieldStyle()).accessibilityLabel("编辑年份")
                            }
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            DatePicker("收藏日期", selection: $collectionDate, displayedComponents: .date)
                                .datePickerStyle(.field).font(.pixel(size: 11)).environment(\.locale, Locale(identifier: "zh_CN"))
                            Text("可改为购买或收到这瓶酒的日期。")
                                .font(.pixel(size: 9)).foregroundStyle(Palette.muted)
                        }
                        Text("备注").font(.pixel(size: 11, weight: .semibold))
                        TextEditor(text: $notes).frame(height: 130).padding(5).background(.white, in: PixelFrame(cornerRadius: 8)).accessibilityLabel("编辑备注")
                            }
                        }.frame(height: 355)
                        HStack {
                            Button("取消编辑") { editing = false }
                            Spacer()
                            Button("保存修改") { update() }.buttonStyle(PrimaryButton())
                                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    } else {
                        CategoryBadge(category: drink.category)
                        Text(drink.name).font(.pixel(size: 26, weight: .bold)).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                        if !drink.variantDescription.isEmpty {
                            Text(drink.variantDescription).font(.pixel(size: 12, weight: .medium)).foregroundStyle(Palette.muted)
                        }
                        Label("收藏于 \(drink.collectionDate.formatted(.dateTime.year().month().day().locale(Locale(identifier: "zh_CN"))))", systemImage: "calendar")
                            .font(.pixel(size: 10)).foregroundStyle(Palette.muted)
                        Rectangle().fill(Palette.line).frame(height: 1).padding(.vertical, 5)
                        Text("这一瓶的记忆").font(.pixel(size: 12, weight: .semibold))
                        ScrollView {
                            VStack(alignment: .leading, spacing: 18) {
                                Text(drink.notes.isEmpty ? "还没有留下备注。下次翻到这里时，为它补上一点记忆吧。" : drink.notes)
                                .font(.pixel(size: 12)).foregroundStyle(drink.notes.isEmpty ? Palette.muted : Palette.ink.opacity(0.8))
                                .lineSpacing(6).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
                                if let knowledge {
                                    Divider()
                                    KnowledgeSections(knowledge: knowledge) { recommendation in
                                        recipeSeed = CocktailSeed(name: recommendation, sourceDrinkID: drink.id, sourceDrinkName: [drink.name, drink.variantDescription].filter { !$0.isEmpty }.joined(separator: " · "), category: drink.category)
                                    }
                                }
                            }
                        }.frame(maxHeight: 224)
                        Spacer(minLength: 0)
                        Button { beginEditing() } label: { Label("编辑这款酒", systemImage: "pencil") }
                            .buttonStyle(.borderless).font(.pixel(size: 11)).tint(Palette.purple).disabled(recognizing)
                    }
                }.frame(width: 295, alignment: .leading)
            }.padding(.horizontal, 26).padding(.bottom, 26)
            Spacer(minLength: 0)
            Rectangle().fill(Palette.line).frame(height: 1)
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(drink.usesOriginalPhoto ? "这款收藏使用原图" : "你的照片，你的专属贴纸")
                        .font(.pixel(size: 10)).foregroundStyle(Palette.muted)
                    Text("AI 识别会将酒瓶图发送至 DeepSeek，并按 API 账户计费。")
                        .font(.pixel(size: 9)).foregroundStyle(Palette.muted)
                }
                Spacer()
                Button { recognize() } label: {
                    if recognizing { ProgressView().controlSize(.small) }
                    else { Label("AI 补充资料", systemImage: "sparkles") }
                }.buttonStyle(.borderless).font(.pixel(size: 11)).tint(Palette.purple).disabled(recognizing || editing)
                Button("删除收藏", role: .destructive) { confirmingDelete = true }.buttonStyle(.borderless).font(.pixel(size: 10))
                    .disabled(recognizing)
            }.padding(24)
        }.frame(width: 700, height: 640).background(Palette.paper).foregroundStyle(Palette.ink).font(.pixel(size: 12)).buttonStyle(PixelSecondaryButton()).preferredColorScheme(.light)
            .task {
                let images = store.images
                let id = drink.id
                do { knowledge = try await Task.detached { try images.loadKnowledge(for: id) }.value }
                catch { self.error = "无法读取酒款资料：\(error.localizedDescription)" }
            }
            .onDisappear { aiTask?.cancel() }
            .sheet(isPresented: $showingSuggestion) {
                if let suggestion {
                    AISuggestionView(knowledge: suggestion, currentName: drink.name, currentCategory: drink.category, categoryHistory: (try? store.allDrinks().map(\.category)) ?? []) { accepted in
                        do { try store.applyKnowledge(accepted, to: drink); knowledge = accepted; enrichment?.startPending() }
                        catch { self.error = error.localizedDescription }
                    }
                }
            }
            .sheet(item: $recipeSeed) { seed in CocktailEditorView(store: store, seed: seed) }
            .alert("删除这款收藏？", isPresented: $confirmingDelete) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    // Stop rendering model properties before SwiftData invalidates the deleted record.
                    isDeleting = true
                    do {
                        let warning = try store.delete(drink)
                        dismiss()
                        if let warning {
                            Task { @MainActor in
                                try? await Task.sleep(for: .milliseconds(350))
                                onCleanupWarning(warning)
                            }
                        }
                    }
                    catch { isDeleting = false; self.error = error.localizedDescription }
                }
            } message: { Text("这款酒的记录和照片都会从收藏册中删除。") }
            .alert("操作未完成", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("好", role: .cancel) { error = nil }
            } message: { Text(error ?? "请重试。") }
    }

    private func beginEditing() {
        name = drink.name; category = drink.category; notes = drink.notes
        tasteVariant = drink.tasteVariant ?? ""; bottleYear = drink.bottleYear ?? ""; collectionDate = drink.collectionDate
        editing = true
    }
    private func recognize() {
        recognizing = true
        let imageURL = store.images.imageURL(for: drink.id)
        let hint = drink.name
        aiTask = Task { @MainActor in
            defer { recognizing = false }
            do {
                guard let key = try await Task.detached(operation: { try DeepSeekKeychain.load() }).value else { throw DeepSeekError.missingKey }
                let data = try await Task.detached { try Data(contentsOf: imageURL) }.value
                let jpeg = try await BottleCutoutService().jpegForRecognition(from: data)
                let result = try await DeepSeekService(apiKey: key).identify(jpeg: jpeg, nameHint: hint)
                try Task.checkCancellation()
                suggestion = result; showingSuggestion = true
            } catch {
                if !Task.isCancelled { self.error = error.localizedDescription }
            }
        }
    }
    private func update() {
        do { try store.update(drink, name: name, category: category, notes: notes, tasteVariant: tasteVariant, bottleYear: bottleYear, collectionDate: collectionDate); editing = false }
        catch { self.error = error.localizedDescription }
    }
    private func exportSticker() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        let safeName = drink.name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        panel.nameFieldStringValue = "\(safeName).png"
        panel.begin { response in
            guard response == .OK, let destination = panel.url else { return }
            do {
                let data = try Data(contentsOf: store.images.imageURL(for: drink.id))
                try data.write(to: destination, options: .atomic)
            } catch { self.error = error.localizedDescription }
        }
    }
}
