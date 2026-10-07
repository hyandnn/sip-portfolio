import SwiftUI
import SipfolioCore

struct CocktailSeed: Identifiable {
    let id = UUID()
    var name = ""
    var sourceDrinkID: UUID?
    var sourceDrinkName: String?
    var category = ""
}

struct CocktailEditorView: View {
    let store: CollectionStore
    let recipe: CocktailRecipe?
    let seed: CocktailSeed
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var ingredients: String
    @State private var steps: String
    @State private var glass: String
    @State private var garnish: String
    @State private var notes: String
    @State private var generatedByAI: Bool
    @State private var generating = false
    @State private var error: String?
    @State private var aiTask: Task<Void, Never>?
    @State private var confirmingReplace = false

    init(store: CollectionStore, recipe: CocktailRecipe? = nil, seed: CocktailSeed = CocktailSeed()) {
        self.store = store; self.recipe = recipe; self.seed = seed
        _name = State(initialValue: recipe?.name ?? seed.name)
        _ingredients = State(initialValue: recipe?.ingredients ?? "")
        _steps = State(initialValue: recipe?.steps ?? "")
        _glass = State(initialValue: recipe?.glass ?? "")
        _garnish = State(initialValue: recipe?.garnish ?? "")
        _notes = State(initialValue: recipe?.notes ?? "")
        _generatedByAI = State(initialValue: recipe?.generatedByAI ?? false)
    }

    private var bottleName: String { recipe?.sourceDescription ?? seed.sourceDrinkName ?? "" }
    private var hasDetails: Bool { !ingredients.isEmpty || !steps.isEmpty || !glass.isEmpty || !garnish.isEmpty || !notes.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("YOUR COCKTAIL RECIPE").font(.pixel(size: 9, weight: .semibold, design: .monospaced)).tracking(1.8).foregroundStyle(Palette.purple)
                    Text(recipe == nil ? "收藏一种新喝法" : "编辑鸡尾酒配方").font(.pixel(size: 23, weight: .bold))
                }
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark").padding(8) }.buttonStyle(.plain).accessibilityLabel("关闭配方编辑")
            }.padding(26)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if !bottleName.isEmpty {
                        Label("来自酒瓶：\(bottleName)", systemImage: "link").font(.pixel(size: 11)).foregroundStyle(Palette.purple)
                    }
                    labeledField("鸡尾酒／喝法名称 *", placeholder: "如 Gin & Tonic、加冰饮用", text: $name)
                    VStack(alignment: .leading, spacing: 8) {
                        Button {
                            if hasDetails { confirmingReplace = true } else { generate() }
                        } label: {
                            HStack(spacing: 7) {
                                if generating { ProgressView().controlSize(.small) }
                                else { Image(systemName: "sparkles") }
                                Text(generating ? "正在生成配方…" : "AI 生成调配建议")
                            }.font(.pixel(size: 12, weight: .semibold))
                        }.buttonStyle(.borderless).tint(Palette.purple)
                            .disabled(generating || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Text("发送喝法名称和关联酒瓶名称、类别至 DeepSeek，按 API 账户计费。生成后请检查用量与步骤，再保存。")
                            .font(.pixel(size: 10)).foregroundStyle(Palette.muted).lineSpacing(3)
                        if generatedByAI { Label("已填入 AI 建议，所有内容均可修改", systemImage: "checkmark.circle").font(.pixel(size: 10)).foregroundStyle(Palette.purple) }
                    }
                    HStack(alignment: .top, spacing: 18) {
                        textArea("材料与用量", placeholder: "每行一种材料，如：\n金酒 — 45 ml\n汤力水 — 120 ml\n冰块 — 适量", text: $ingredients, height: 166)
                        textArea("调配步骤", placeholder: "记录操作顺序，如：\n1. 杯中加入冰块。\n2. 倒入金酒和汤力水。\n3. 轻轻搅拌。", text: $steps, height: 166)
                    }
                    HStack(alignment: .top, spacing: 18) {
                        labeledField("杯型", placeholder: "如高球杯（可留空）", text: $glass)
                        labeledField("装饰", placeholder: "如柠檬片（可留空）", text: $garnish)
                    }
                    textArea("备注与调整", placeholder: "口味调整、替代材料或实际调配心得…", text: $notes, height: 85)
                }.padding(26).disabled(generating)
            }
            Divider()
            HStack {
                Text("配方保存在这台 Mac 上").font(.pixel(size: 10)).foregroundStyle(Palette.muted)
                Spacer()
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction)
                Button(recipe == nil ? "收进蒙汗药" : "保存修改") { save() }.buttonStyle(PrimaryButton())
                    .disabled(generating || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }.padding(22)
        }.frame(width: 700, height: 730).background(Palette.paper).foregroundStyle(Palette.ink).font(.pixel(size: 12)).buttonStyle(PixelSecondaryButton()).preferredColorScheme(.light)
            .onDisappear { aiTask?.cancel() }
            .confirmationDialog("用新生成的建议替换当前配方内容？", isPresented: $confirmingReplace, titleVisibility: .visible) {
                Button("生成并替换") { generate() }
                Button("取消", role: .cancel) {}
            } message: { Text("材料、步骤、杯型、装饰和备注会替换为新建议。关闭编辑时仍可放弃修改。") }
            .alert("配方操作未完成", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("好", role: .cancel) { error = nil }
            } message: { Text(error ?? "请重试。") }
    }

    private func labeledField(_ label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.pixel(size: 11, weight: .semibold))
            TextField(placeholder, text: text).textFieldStyle(.plain).padding(11)
                .background(.white, in: PixelFrame(cornerRadius: 8))
                .overlay(PixelFrame(cornerRadius: 8).stroke(Palette.line)).accessibilityLabel(label)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func textArea(_ label: String, placeholder: String, text: Binding<String>, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.pixel(size: 11, weight: .semibold))
            ZStack(alignment: .topLeading) {
                TextEditor(text: text).font(.pixel(size: 12)).scrollContentBackground(.hidden).padding(6)
                    .frame(height: height).background(.white, in: PixelFrame(cornerRadius: 8))
                    .overlay(PixelFrame(cornerRadius: 8).stroke(Palette.line)).accessibilityLabel(label)
                if text.wrappedValue.isEmpty {
                    Text(placeholder).font(.pixel(size: 11)).foregroundStyle(Palette.muted.opacity(0.7))
                        .padding(12).allowsHitTesting(false)
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func generate() {
        let requestName = name
        let bottle = bottleName
        let category = seed.category
        generating = true
        aiTask = Task { @MainActor in
            defer { generating = false }
            do {
                guard let key = try await Task.detached(operation: { try DeepSeekKeychain.load() }).value else { throw DeepSeekError.missingKey }
                let result = try await DeepSeekService(apiKey: key).cocktailRecipe(name: requestName, bottleName: bottle, category: category)
                try Task.checkCancellation()
                name = result.name; ingredients = result.ingredientsText; steps = result.stepsText
                glass = result.glass; garnish = result.garnish; notes = result.notes; generatedByAI = true
            } catch { if !Task.isCancelled { self.error = error.localizedDescription } }
        }
    }

    private func save() {
        do {
            if let recipe {
                try store.updateCocktail(recipe, name: name, ingredients: ingredients, steps: steps, glass: glass, garnish: garnish, notes: notes, generatedByAI: generatedByAI)
            } else {
                try store.addCocktail(name: name, ingredients: ingredients, steps: steps, glass: glass, garnish: garnish, notes: notes, sourceDrinkID: seed.sourceDrinkID, sourceDrinkName: seed.sourceDrinkName, generatedByAI: generatedByAI)
            }
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

struct CocktailCard: View {
    let recipe: CocktailRecipe
    let store: CollectionStore
    var enrichment: CocktailEnrichmentCoordinator? = nil
    let action: () -> Void
    @State private var hasPhoto = false
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    PixelFrame(cornerRadius: 10).fill(Palette.purple.opacity(0.08))
                    if hasPhoto {
                        StoredPhoto(url: store.cocktailImages.imageURL(for: recipe.id, original: true), contentMode: .fill)
                            .id(store.cocktailImageRevision)
                    } else {
                        VStack(spacing: 12) {
                            PixelGlyph(kind: .glass, size: 45).foregroundStyle(Palette.purple)
                            if enrichment?.activeIDs.contains(recipe.id) == true { ProgressView().controlSize(.small) }
                            Text(enrichment?.activeIDs.contains(recipe.id) == true ? "正在查找配方与成品图…" : "成品图待补充").font(.pixel(size: 10)).foregroundStyle(Palette.muted)
                        }
                    }
                }.frame(height: 205).clipShape(PixelFrame(cornerRadius: 10))
                Text(recipe.name).font(.pixel(size: 15, weight: .semibold)).lineLimit(1).frame(height: 20, alignment: .leading)
                if !recipe.sourceDescription.isEmpty {
                    Label(recipe.sourceDescription, systemImage: "link").font(.pixel(size: 10)).foregroundStyle(Palette.purple).lineLimit(1).frame(height: 14, alignment: .leading)
                } else { Text(" ").font(.pixel(size: 10)).frame(height: 14).accessibilityHidden(true) }
                Text(recipe.ingredients.isEmpty ? "材料待补充" : recipe.ingredients)
                    .font(.pixel(size: 11)).foregroundStyle(Palette.muted).lineLimit(3).frame(maxWidth: .infinity, alignment: .leading).frame(height: 58, alignment: .topLeading)
                HStack {
                    Text(recipe.glass.isEmpty ? "私人配方" : recipe.glass).font(.pixel(size: 9)).foregroundStyle(Palette.muted)
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.pixel(size: 10)).foregroundStyle(Palette.purple)
                }.frame(height: 14)
            }.padding(15).frame(maxWidth: .infinity, alignment: .leading).background(.white, in: PixelFrame(cornerRadius: 15))
                .overlay(PixelFrame(cornerRadius: 15).strokeBorder(Palette.ink.opacity(0.5), lineWidth: 2))
                .shadow(color: Palette.ink.opacity(0.13), radius: 0, x: 4, y: 4)
        }.buttonStyle(.plain).accessibilityLabel("\(recipe.name)，查看配方")
            .task(id: store.cocktailImageRevision) { hasPhoto = FileManager.default.fileExists(atPath: store.cocktailImages.imageURL(for: recipe.id, original: true).path) }
    }
}

struct CocktailDetailView: View {
    let recipe: CocktailRecipe
    let store: CollectionStore
    var enrichment: CocktailEnrichmentCoordinator? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    @State private var confirmingDelete = false
    @State private var deleting = false
    @State private var error: String?
    @State private var photoMetadata: CocktailPhotoMetadata?
    @State private var photoEditing = false

    var body: some View {
        Group {
            if deleting { ProgressView("正在删除配方…").frame(width: 620, height: 660) }
            else {
                VStack(spacing: 0) {
                    HStack {
                        Label("蒙汗药 · 鸡尾酒配方", systemImage: "wineglass").font(.pixel(size: 11, weight: .semibold)).foregroundStyle(Palette.purple)
                        Spacer()
                        Button { dismiss() } label: { Image(systemName: "xmark").padding(8) }.buttonStyle(.plain).accessibilityLabel("关闭配方详情")
                    }.padding(25)
                    Divider()
                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            if photoMetadata != nil {
                                StoredPhoto(url: store.cocktailImages.imageURL(for: recipe.id, original: true)).id(store.cocktailImageRevision)
                                    .frame(maxWidth: .infinity).frame(height: 260)
                                    .background(Palette.purple.opacity(0.06), in: PixelFrame(cornerRadius: 14))
                                    .clipShape(PixelFrame(cornerRadius: 14))
                                Text("成品示意图")
                                    .font(.pixel(size: 10)).foregroundStyle(Palette.muted)
                            }
                            Text(recipe.name).font(.pixel(size: 28, weight: .bold))
                            if !recipe.sourceDescription.isEmpty {
                                Label("关联酒瓶：\(recipe.sourceDescription)", systemImage: "link").font(.pixel(size: 11)).foregroundStyle(Palette.purple)
                            }
                            HStack {
                                Button(photoMetadata == nil ? "导入成品照片" : "更换成品照片") { photoEditing = true }.buttonStyle(.borderless).tint(Palette.purple)
                                Spacer()
                                if let enrichment {
                                    Button(enrichment.activeIDs.contains(recipe.id) ? "正在联网补充…" : "联网补充配方与成品图") { enrichment.retry(recipe.id) }
                                        .buttonStyle(.borderless).tint(Palette.purple).disabled(enrichment.activeIDs.contains(recipe.id))
                                }
                            }.font(.pixel(size: 11))
                            if let message = enrichment?.errors[recipe.id] { Text(message).font(.pixel(size: 11)).foregroundStyle(Palette.muted) }
                            section("材料与用量", text: recipe.ingredients.isEmpty ? "还没有填写材料。" : recipe.ingredients)
                            section("调配步骤", text: recipe.steps.isEmpty ? "还没有填写调配步骤。" : recipe.steps)
                            if !recipe.glass.isEmpty || !recipe.garnish.isEmpty {
                                HStack(alignment: .top, spacing: 35) {
                                    if !recipe.glass.isEmpty { section("杯型", text: recipe.glass) }
                                    if !recipe.garnish.isEmpty { section("装饰", text: recipe.garnish) }
                                }
                            }
                            if !recipe.notes.isEmpty { section("备注与调整", text: recipe.notes) }
                            if recipe.generatedByAI {
                                Text("含 AI 生成的参考配方 · 可按实际调配结果修改")
                                    .font(.pixel(size: 10)).foregroundStyle(Palette.muted)
                            }
                            if let url = recipe.referenceURL.flatMap(URL.init(string:)) {
                                Link("参考配方：\(recipe.referenceProvider ?? "公开配方")", destination: url).font(.pixel(size: 11))
                            }
                            if let metadata = photoMetadata {
                                VStack(alignment: .leading, spacing: 7) {
                                    Text("图片来源：\(metadata.provider)\(metadata.credit.isEmpty ? "" : " · \(metadata.credit)")").font(.pixel(size: 10)).foregroundStyle(Palette.muted)
                                    if let page = metadata.pageURL.flatMap(URL.init(string:)) { Link("查看成品图所在页面", destination: page).font(.pixel(size: 10)) }
                                    if let source = metadata.photoSourceURL.flatMap(URL.init(string:)) { Link("查看原始图片来源", destination: source).font(.pixel(size: 10)) }
                                    if metadata.provider == "TheCocktailDB" {
                                        Text("图片为该喝法的示意，配方版本可能不同。")
                                            .font(.pixel(size: 10)).foregroundStyle(Palette.muted)
                                    }
                                }
                            }
                        }.padding(28).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
                    }
                    Divider()
                    HStack {
                        Button("删除配方", role: .destructive) { confirmingDelete = true }.buttonStyle(.borderless)
                        Spacer()
                        Button("编辑配方") { editing = true }.buttonStyle(PrimaryButton())
                    }.padding(22)
                }.frame(width: 620, height: 660).background(Palette.paper).foregroundStyle(Palette.ink).font(.pixel(size: 12)).buttonStyle(PixelSecondaryButton()).preferredColorScheme(.light)
            }
        }
        .sheet(isPresented: $editing) { CocktailEditorView(store: store, recipe: recipe) }
        .sheet(isPresented: $photoEditing) { CocktailPhotoEditorView(recipeID: recipe.id, store: store) }
        .task(id: store.cocktailImageRevision) { photoMetadata = try? store.cocktailPhotoMetadata(for: recipe.id) }
        .alert("删除这份配方？", isPresented: $confirmingDelete) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                deleting = true
                do { try store.deleteCocktail(recipe); dismiss() }
                catch { deleting = false; self.error = error.localizedDescription }
            }
        } message: { Text("这份配方会从鸡尾酒集中删除，酒瓶收藏会保留。") }
        .alert("操作未完成", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("好", role: .cancel) { error = nil }
        } message: { Text(error ?? "请重试。") }
    }

    private func section(_ title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title).font(.pixel(size: 12, weight: .semibold))
            Text(text).font(.pixel(size: 13)).lineSpacing(6).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
