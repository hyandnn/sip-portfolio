import SwiftUI
import SipfolioCore

struct AISettingsView: View {
    @State private var key = ""
    @State private var configured = false
    @State private var checking = false
    @State private var status: String?
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("AI 酒款识别", systemImage: "sparkles").font(.pixel(size: 22, weight: .bold))
            Text("使用 DeepSeek Flash 识别酒瓶与补充资料，也可生成鸡尾酒调配建议。结果由你核对后保存。")
                .font(.pixel(size: 12)).foregroundStyle(Palette.muted).lineSpacing(4)
            VStack(alignment: .leading, spacing: 9) {
                Text("DeepSeek API 密钥").font(.pixel(size: 12, weight: .semibold))
                SecureField(configured ? "已配置，输入新密钥可替换" : "输入 DeepSeek API 密钥", text: $key)
                    .textFieldStyle(PixelTextFieldStyle()).accessibilityLabel("DeepSeek API 密钥")
                Text("密钥保存在 macOS 钥匙串中。").font(.pixel(size: 10)).foregroundStyle(Palette.muted)
            }
            HStack {
                Button("保存密钥") {
                    do { try DeepSeekKeychain.save(key); key = ""; configured = true; status = "密钥已保存。" }
                    catch { self.error = error.localizedDescription }
                }.disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || checking)
                Button(checking ? "正在检查…" : "检查连接") { checkConnection() }.disabled(!configured || checking)
                Spacer()
                Button("移除密钥", role: .destructive) {
                    do { try DeepSeekKeychain.remove(); configured = false; key = ""; status = "密钥已移除。" }
                    catch { self.error = error.localizedDescription }
                }.disabled(!configured || checking).buttonStyle(.borderless)
            }
            if checking { ProgressView().controlSize(.small) }
            if let status { Label(status, systemImage: "checkmark.circle").font(.pixel(size: 11)).foregroundStyle(Palette.purple) }
            Spacer(minLength: 0)
            Text("识别酒瓶会发送所选酒瓶图；生成配方会发送喝法名称及关联酒瓶的名称、类别。接口按你的 DeepSeek 账户计费，个人备注不发送。")
                .font(.pixel(size: 11)).foregroundStyle(Palette.muted).lineSpacing(4)
        }.padding(28).frame(width: 520, height: 410).background(Palette.paper).foregroundStyle(Palette.ink).font(.pixel(size: 12)).buttonStyle(PixelSecondaryButton())
            .preferredColorScheme(.light)
            .task {
                do { configured = try await Task.detached { try DeepSeekKeychain.load() != nil }.value }
                catch { self.error = error.localizedDescription }
            }
            .alert("AI 设置未完成", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("好", role: .cancel) { error = nil }
            } message: { Text(error ?? "请重试。") }
    }

    private func checkConnection() {
        checking = true; status = nil
        Task { @MainActor in
            defer { checking = false }
            do {
                guard let key = try await Task.detached(operation: { try DeepSeekKeychain.load() }).value else { throw DeepSeekError.missingKey }
                _ = try await DeepSeekService(apiKey: key).checkConnection()
                status = "连接成功，图片识别模型可用。"
            } catch { self.error = error.localizedDescription }
        }
    }
}

struct KnowledgeSections: View {
    let knowledge: DrinkKnowledge
    var onSaveCocktail: ((String) -> Void)? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !knowledge.introduction.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    Text("关于这瓶酒").font(.pixel(size: 12, weight: .semibold))
                    Text(knowledge.introduction).font(.pixel(size: 12)).lineSpacing(5).textSelection(.enabled)
                }
            }
            if !knowledge.flavors.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("风味印象").font(.pixel(size: 12, weight: .semibold))
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80, maximum: 140), spacing: 7)], alignment: .leading, spacing: 7) {
                        ForEach(Array(knowledge.flavors.enumerated()), id: \.offset) { _, flavor in
                            Text(flavor).font(.pixel(size: 10)).lineLimit(2).padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Palette.purple.opacity(0.09), in: PixelFrame(cornerRadius: 4))
                        }
                    }
                }
            }
            if !knowledge.cocktails.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("可以试试").font(.pixel(size: 12, weight: .semibold))
                    ForEach(Array(knowledge.cocktails.enumerated()), id: \.offset) { _, cocktail in
                        HStack(alignment: .top, spacing: 8) {
                            Label(cocktail, systemImage: "wineglass").font(.pixel(size: 11))
                            Spacer(minLength: 0)
                            if let onSaveCocktail {
                                Button { onSaveCocktail(cocktail) } label: { Image(systemName: "plus.circle") }
                                    .buttonStyle(.plain).foregroundStyle(Palette.purple)
                                    .help("记录调配方法，加入鸡尾酒集").accessibilityLabel("为 \(cocktail) 记录配方")
                            }
                        }
                    }
                }
            }
            if !knowledge.uncertainty.isEmpty {
                Label(knowledge.uncertainty, systemImage: "info.circle")
                    .font(.pixel(size: 10)).foregroundStyle(Palette.muted).lineSpacing(4)
            }
            Text("DeepSeek 生成建议 · 请核对酒款与版本")
                .font(.pixel(size: 9)).foregroundStyle(Palette.muted)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AISuggestionView: View {
    let knowledge: DrinkKnowledge
    var categoryHistory: [String]
    var onAccept: (DrinkKnowledge) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var category: String

    init(knowledge: DrinkKnowledge, currentName: String = "", currentCategory: String = "", categoryHistory: [String] = [], onAccept: @escaping (DrinkKnowledge) -> Void) {
        self.knowledge = knowledge; self.onAccept = onAccept; self.categoryHistory = categoryHistory
        _name = State(initialValue: currentName.isEmpty ? knowledge.name ?? "" : currentName)
        _category = State(initialValue: currentCategory.isEmpty || ["其他", "未分类"].contains(currentCategory) ? knowledge.category ?? currentCategory : currentCategory)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Label("这瓶酒的 AI 建议", systemImage: "sparkles").font(.pixel(size: 21, weight: .bold))
                    Text(knowledge.confidenceLabel).font(.pixel(size: 11)).foregroundStyle(Palette.muted)
                }
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark").padding(8) }.buttonStyle(.plain).accessibilityLabel("关闭 AI 建议")
            }.padding(25)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 19) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("确认酒名").font(.pixel(size: 12, weight: .semibold))
                        TextField("图片不清晰时请补充酒名", text: $name).textFieldStyle(PixelTextFieldStyle())
                        if let candidate = knowledge.name, !name.isEmpty, candidate != name {
                            Text("识别建议：\(candidate)").font(.pixel(size: 10)).foregroundStyle(Palette.muted)
                            Button("采用建议酒名") { name = candidate }.buttonStyle(.borderless).font(.pixel(size: 10))
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("确认类别").font(.pixel(size: 12, weight: .semibold))
                        CategoryInput(selection: $category, history: categoryHistory)
                        if let candidate = knowledge.category, candidate != category {
                            Button("采用识别类别：\(candidate)") { category = candidate }.buttonStyle(.borderless).font(.pixel(size: 10))
                        }
                    }
                    KnowledgeSections(knowledge: knowledge)
                }.padding(25)
            }
            Divider()
            HStack {
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("采用并继续") {
                    var accepted = knowledge
                    accepted.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    accepted.category = category
                    onAccept(accepted); dismiss()
                }.buttonStyle(PrimaryButton()).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }.padding(22)
        }.frame(width: 580, height: 640).background(Palette.paper).foregroundStyle(Palette.ink).font(.pixel(size: 12)).buttonStyle(PixelSecondaryButton()).preferredColorScheme(.light)
    }
}
