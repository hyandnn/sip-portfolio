import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import SipfolioCore

struct CollectionView: View {
    let store: CollectionStore
    let enrichment: CocktailEnrichmentCoordinator?
    @Binding var isAdding: Bool
    @Query(sort: \Drink.createdAt, order: .reverse) private var drinks: [Drink]
    @Query(sort: \CocktailRecipe.createdAt, order: .reverse) private var cocktails: [CocktailRecipe]
    @State private var showingCocktails = false
    @State private var category: String?
    @State private var search = ""
    @State private var selectedDrink: Drink?
    @State private var selectedCocktail: CocktailRecipe?
    @State private var droppedURL: URL?
    @State private var sortOrder = SortOrder.newest
    @State private var dropTargeted = false
    @State private var cleanupWarning: String?
    @State private var collectingRecommendations = false
    @State private var recommendationMessage: String?

    enum SortOrder: String, CaseIterable { case newest = "最近收藏", oldest = "最早收藏", name = "名称排序" }
    init(store: CollectionStore, isAdding: Binding<Bool>, initiallyShowingCocktails: Bool = false, enrichment: CocktailEnrichmentCoordinator? = nil) {
        self.store = store; self.enrichment = enrichment; _isAdding = isAdding; _showingCocktails = State(initialValue: initiallyShowingCocktails)
    }
    private var usedCategories: [String] { CategoryHistory.suggestions(from: drinks.map(\.category)) }
    private var filteredCocktails: [CocktailRecipe] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let result = cocktails.filter {
            query.isEmpty || [$0.name, $0.ingredients, $0.steps, $0.notes, $0.sourceDescription].contains { $0.localizedStandardContains(query) }
        }
        switch sortOrder {
        case .newest: return result.sorted { $0.createdAt > $1.createdAt }
        case .oldest: return result.sorted { $0.createdAt < $1.createdAt }
        case .name: return result.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
    }
    private var filtered: [Drink] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let result = drinks.filter { drink in
            (category == nil || drink.category.compare(category ?? "", options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame) &&
            (query.isEmpty || drink.name.localizedStandardContains(query) || drink.notes.localizedStandardContains(query) || drink.category.localizedStandardContains(query) || (drink.tasteVariant ?? "").localizedStandardContains(query) || (drink.bottleYear ?? "").localizedStandardContains(query))
        }
        switch sortOrder {
        case .newest: return result.sorted { $0.collectionDate > $1.collectionDate }
        case .oldest: return result.sorted { $0.collectionDate < $1.collectionDate }
        case .name: return result.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
    }

    var body: some View {
        collectionShell
        .foregroundStyle(Palette.ink).font(.pixel(size: 12)).buttonStyle(PixelSecondaryButton())
        .overlay { dropOverlay }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first, !isAdding, selectedDrink == nil, selectedCocktail == nil else { return false }
            showingCocktails = false
            droppedURL = url
            isAdding = true
            return true
        } isTargeted: { dropTargeted = $0 }
        .sheet(isPresented: $isAdding, onDismiss: { droppedURL = nil }) {
            if showingCocktails { CocktailEditorView(store: store) }
            else { AddDrinkView(store: store, initialURL: droppedURL) }
        }
        .sheet(item: $selectedDrink) { drink in
            DrinkDetailView(drink: drink, store: store, enrichment: enrichment) { cleanupWarning = $0 }
        }
        .sheet(item: $selectedCocktail) { recipe in CocktailDetailView(recipe: recipe, store: store, enrichment: enrichment) }
        .onChange(of: cocktails.map(\.id), initial: true) { _, _ in enrichment?.startPending() }
        .onChange(of: showingCocktails) { _, _ in search = ""; category = nil }
        .onChange(of: usedCategories) { _, values in
            if let category, !values.contains(category) { self.category = nil }
        }
        .alert("图片清理未完成", isPresented: Binding(get: { cleanupWarning != nil }, set: { if !$0 { cleanupWarning = nil } })) {
            Button("好", role: .cancel) { cleanupWarning = nil }
        } message: { Text(cleanupWarning ?? "") }
    }

    private var collectionShell: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 214)
            Rectangle().fill(Palette.ink.opacity(0.4)).frame(width: 2)
            VStack(alignment: .leading, spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        if !showingCocktails && drinks.isEmpty { welcomeBanner }
                        collectionBar
                        if showingCocktails, let recommendationMessage {
                            Text(recommendationMessage).font(.pixel(size: 11)).foregroundStyle(Palette.purple)
                        }
                        if showingCocktails {
                            if filteredCocktails.isEmpty { cocktailEmptyState }
                            else {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220, maximum: 320), spacing: 20)], alignment: .leading, spacing: 22) {
                                    ForEach(filteredCocktails) { recipe in
                                        CocktailCard(recipe: recipe, store: store, enrichment: enrichment) { selectedCocktail = recipe }
                                    }
                                }
                            }
                        } else if filtered.isEmpty {
                            emptyState
                        } else {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 194, maximum: 280), spacing: 20)], spacing: 22) {
                                ForEach(filtered) { drink in
                                    BottleCard(drink: drink, store: store) { selectedDrink = drink }
                                }
                            }
                        }
                    }.padding(.horizontal, 34).padding(.top, 28).padding(.bottom, 36)
                }
            }.background(PixelPaper())
        }
    }

    @ViewBuilder private var dropOverlay: some View {
        if dropTargeted {
            PixelFrame(cornerRadius: 18).stroke(Palette.purple, style: StrokeStyle(lineWidth: 3, dash: [10]))
                .padding(10).allowsHitTesting(false)
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                PixelGlyph(kind: .bottle, size: 27).foregroundStyle(Palette.ink).font(.pixel(size: 12)).buttonStyle(PixelSecondaryButton())
                Text("Sipfolio").font(.pixel(size: 25, weight: .bold, design: .rounded)).tracking(-1)
            }.padding(.top, 29).padding(.bottom, 7)
            Text("收藏每一口的故事").font(.pixel(size: 10)).foregroundStyle(Palette.muted).padding(.leading, 33)
            Text("我的收藏册").font(.pixel(size: 10, weight: .semibold)).foregroundStyle(Palette.muted)
                .padding(.top, 44).padding(.bottom, 12)
            sidebarRow("藏酒屋", symbol: "square.grid.2x2.fill", count: drinks.count, selected: !showingCocktails && category == nil) { showingCocktails = false; category = nil }
            sidebarRow("蒙汗药", symbol: "wineglass", count: cocktails.count, selected: showingCocktails) { showingCocktails = true }
            Text(showingCocktails ? "配方与调配记忆" : "按酒类探索").font(.pixel(size: 10, weight: .semibold)).foregroundStyle(Palette.muted)
                .padding(.top, 31).padding(.bottom, 12)
            ScrollView {
                if showingCocktails {
                    Text("把酒瓶推荐的喝法收进这里，\n记录材料、比例与调配步骤。")
                        .font(.pixel(size: 11)).foregroundStyle(Palette.muted).lineSpacing(6).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 10)
                } else {
                    VStack(spacing: 5) {
                        ForEach(usedCategories, id: \.self) { item in
                            sidebarRow(item, symbol: DrinkCategory(rawValue: item)?.symbol ?? "tag", count: drinks.filter { $0.category.compare(item, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }.count, selected: category == item) { category = item }
                        }
                        if usedCategories.isEmpty {
                            Text("收藏后，类别会出现在这里。")
                                .font(.pixel(size: 10)).foregroundStyle(Palette.muted).padding(.top, 5)
                        }
                    }
                }
            }.scrollIndicators(.hidden)
            Spacer(minLength: 20)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Circle().fill(Color(red: 0.31, green: 0.59, blue: 0.42)).frame(width: 6, height: 6)
                    Text("保存在这台 Mac 上").font(.pixel(size: 10))
                }
                Text("属于你的私人收藏，随时翻阅。")
                    .font(.pixel(size: 9)).foregroundStyle(Palette.muted)
            }.padding(.top, 18).padding(.bottom, 24)
        }.padding(.horizontal, 20).background(Palette.sidebar)
    }

    private func sidebarRow(_ title: String, symbol: String, count: Int, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 11) {
                if symbol == "square.grid.2x2.fill" { PixelGlyph(kind: .bottle, size: 18) }
                else if symbol == "wineglass" { PixelGlyph(kind: .glass, size: 18) }
                else { Image(systemName: symbol).font(.pixel(size: 12)).frame(width: 18) }
                Text(title).font(.pixel(size: 12, weight: selected ? .semibold : .regular))
                Spacer()
                Text("\(count)").font(.pixel(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(selected ? Palette.purple : Palette.muted)
            }.padding(.horizontal, 11).padding(.vertical, 10)
                .foregroundStyle(selected ? Palette.purple : Palette.ink.opacity(0.7))
                .background(selected ? .white : .clear, in: PixelFrame(cornerRadius: 9))
                .overlay(PixelFrame(cornerRadius: 9).strokeBorder(selected ? Palette.ink.opacity(0.65) : .clear, lineWidth: 2))
                .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel("\(title)，\(count) 款")
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 7) {
                Text(showingCocktails ? "YOUR COCKTAIL COLLECTION" : "YOUR BOTTLE COLLECTION").font(.pixel(size: 9, weight: .semibold, design: .monospaced)).tracking(2).foregroundStyle(Palette.muted)
                Text(showingCocktails ? "把喜欢的喝法，变成自己的配方。" : "每一瓶，都是一段值得收藏的记忆。").font(.pixel(size: 11)).foregroundStyle(Palette.muted)
            }
            Spacer()
            SettingsLink { PixelGlyph(kind: .settings, size: 20).padding(10) }
                .buttonStyle(.plain).help("AI 设置").accessibilityLabel("AI 设置")
            Button { isAdding = true } label: {
                HStack(spacing: 8) { PixelGlyph(kind: .plus, size: 18); Text(showingCocktails ? "新配方" : "新收藏") }
            }
                .buttonStyle(PrimaryButton()).keyboardShortcut("n", modifiers: .command)
        }.padding(.horizontal, 34).padding(.vertical, 27)
            .background(.white.opacity(0.65))
            .overlay(alignment: .bottom) { Rectangle().fill(Palette.line).frame(height: 1) }
    }

    private var welcomeBanner: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                Text("A COLLECTION OF EVERY SIP").font(.pixel(size: 8, weight: .bold, design: .monospaced)).tracking(1.8).foregroundStyle(Palette.purple)
                Text("把回忆，装进收藏册。")
                    .font(.pixel(size: 23, weight: .bold)).tracking(-0.5)
                Text("一张照片，一枚贴纸。\n从你喜欢的那瓶酒开始，慢慢收集自己的品味。")
                    .font(.pixel(size: 11)).lineSpacing(5).foregroundStyle(Palette.ink.opacity(0.65))
            }.padding(.leading, 28)
            Spacer(minLength: 0)
            ZStack {
                PixelFrame(cornerRadius: 10).fill(.white.opacity(0.7)).frame(width: 109, height: 162).offset(x: -58, y: 7)
                BottleIllustration(color: Color(red: 0.35, green: 0.57, blue: 0.44), label: "GIN", squat: true)
                    .offset(x: -59, y: 0)
                PixelFrame(cornerRadius: 10).fill(.white).frame(width: 116, height: 180).offset(x: 53, y: 0)
                BottleIllustration(color: Color(red: 0.86, green: 0.50, blue: 0.22), label: "WHISKY")
                    .offset(x: 54, y: -4)
                PixelGlyph(kind: .sparkle, size: 27).foregroundStyle(Palette.purple).offset(x: 103, y: -72)
                PixelGlyph(kind: .sparkle, size: 18).foregroundStyle(Palette.purple).offset(x: -114, y: 58)
            }.frame(width: 250, height: 190).padding(.trailing, 12).accessibilityHidden(true)
        }.frame(maxWidth: .infinity).frame(height: 206)
            .background(Palette.mint.opacity(0.5), in: PixelFrame(cornerRadius: 17))
            .overlay(PixelFrame(cornerRadius: 17).strokeBorder(Palette.ink.opacity(0.4), lineWidth: 2))
    }

    private var collectionBar: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(showingCocktails ? "\(filteredCocktails.count) 份配方" : "\(filtered.count) 款收藏").font(.pixel(size: 15, weight: .semibold))
                Text(showingCocktails ? "材料、用量与步骤，都留在这里" : "\(Set(drinks.map(\.category)).count) 个酒类 · 每一瓶都独一无二")
                    .font(.pixel(size: 10)).foregroundStyle(Palette.muted)
            }
            Spacer()
            if showingCocktails, !drinks.isEmpty {
                Button(collectingRecommendations ? "正在收录…" : "收录酒瓶推荐") { collectExistingRecommendations() }
                    .buttonStyle(.borderless).font(.pixel(size: 11)).tint(Palette.purple).disabled(collectingRecommendations)
            }
            HStack(spacing: 8) {
                PixelGlyph(kind: .search, size: 18).foregroundStyle(Palette.muted)
                TextField(showingCocktails ? "搜索配方、材料或酒瓶" : "搜索酒名、口味、年份或备注", text: $search).textFieldStyle(.plain).font(.pixel(size: 11))
                if !search.isEmpty { Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain).foregroundStyle(Palette.muted) }
            }.padding(10).frame(width: 220).background(.white, in: PixelFrame(cornerRadius: 8))
                .overlay(PixelFrame(cornerRadius: 8).stroke(Palette.line))
            Menu {
                ForEach(SortOrder.allCases, id: \.self) { order in
                    Button(order.rawValue) { sortOrder = order }
                }
            } label: { Label(sortOrder.rawValue, systemImage: "arrow.up.arrow.down").font(.pixel(size: 10)) }
            .menuStyle(.borderlessButton).fixedSize()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 13) {
            Image(systemName: drinks.isEmpty ? "plus.viewfinder" : "magnifyingglass")
                .font(.pixel(size: 32, weight: .light)).foregroundStyle(Palette.purple.opacity(0.6)).padding(.bottom, 3)
            Text(drinks.isEmpty ? "第一瓶，值得被收藏。" : "这里还没有找到酒瓶")
                .font(.pixel(size: 18, weight: .semibold))
            Text(drinks.isEmpty ? "导入一张酒瓶照片，把它变成你的专属贴纸。\n也可以直接把照片拖进窗口。" : "试试其他关键词，或添加一款新的收藏。")
                .font(.pixel(size: 11)).foregroundStyle(Palette.muted).multilineTextAlignment(.center).lineSpacing(5)
            if drinks.isEmpty {
                Button { isAdding = true } label: { Label("收藏第一瓶", systemImage: "plus") }.buttonStyle(PrimaryButton()).padding(.top, 6)
            } else {
                Button("查看全部收藏") { search = ""; category = nil }.buttonStyle(.borderless).tint(Palette.purple)
            }
        }.frame(maxWidth: .infinity).frame(minHeight: drinks.isEmpty ? 236 : 350)
            .background(.white.opacity(0.55), in: PixelFrame(cornerRadius: 14))
            .overlay(PixelFrame(cornerRadius: 14).stroke(Palette.line, style: StrokeStyle(lineWidth: 1, dash: [5])))
    }

    private var cocktailEmptyState: some View {
        VStack(spacing: 16) {
            PixelGlyph(kind: cocktails.isEmpty ? .glass : .search, size: 45).foregroundStyle(Palette.purple)
            Text(cocktails.isEmpty ? "收藏第一份调配方法" : "没有找到这份配方").font(.pixel(size: 19, weight: .semibold))
            Text(cocktails.isEmpty ? "收藏酒瓶时，可以把推荐喝法一起收进来。\n也可以直接新建，记录自己的材料、比例和步骤。" : "试试鸡尾酒名称、材料或关联酒瓶名称。")
                .font(.pixel(size: 12)).foregroundStyle(Palette.muted).lineSpacing(6).multilineTextAlignment(.center)
            if cocktails.isEmpty {
                Button { isAdding = true } label: { Label("新建配方", systemImage: "plus") }.buttonStyle(PrimaryButton())
            } else { Button("查看全部配方") { search = "" }.buttonStyle(.borderless).tint(Palette.purple) }
        }.frame(maxWidth: .infinity).frame(minHeight: 350).background(.white.opacity(0.55), in: PixelFrame(cornerRadius: 15))
    }

    private func collectExistingRecommendations() {
        collectingRecommendations = true
        let snapshots = drinks.map { ($0.id, store.images) }
        Task { @MainActor in
            defer { collectingRecommendations = false }
            do {
                var count = 0
                for (id, images) in snapshots {
                    let knowledge = try await Task.detached { try images.loadKnowledge(for: id) }.value
                    if let knowledge, let drink = try store.allDrinks().first(where: { $0.id == id }) {
                        count += try store.collectRecommendations(knowledge, for: drink).count
                    }
                }
                recommendationMessage = count == 0 ? "现有酒瓶还没有推荐喝法，可以在详情中补充 AI 资料。" : "已收录酒瓶推荐；相同喝法已合并，配方与成品图会继续补充。"
                enrichment?.startPending()
            } catch { recommendationMessage = error.localizedDescription }
        }
    }
}

struct BottleCard: View {
    let drink: Drink
    let store: CollectionStore
    let action: () -> Void
    @State private var hovered = false
    @State private var flavors: [String] = []
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    PixelFrame(cornerRadius: 10).fill(Palette.color(for: drink.category).opacity(0.42))
                    StoredPhoto(url: store.images.thumbnailURL(for: drink.id))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .padding(25).shadow(color: .black.opacity(0.12), radius: 8, y: 7)
                }.frame(height: 205)
                .overlay(alignment: .topLeading) {
                    Text(drink.collectionDate.formatted(.dateTime.year().month().day().locale(Locale(identifier: "zh_CN"))))
                        .font(.pixel(size: 8, weight: .medium, design: .monospaced)).foregroundStyle(Palette.ink.opacity(0.45)).padding(12)
                }
                Text(drink.name).font(.pixel(size: 14, weight: .semibold)).lineLimit(1)
                    .frame(height: 20, alignment: .leading).padding(.top, 15)
                Text(drink.variantDescription.isEmpty ? " " : drink.variantDescription)
                    .font(.pixel(size: 10)).foregroundStyle(Palette.muted).lineLimit(1)
                    .frame(height: 14, alignment: .leading).padding(.top, 5)
                    .accessibilityHidden(drink.variantDescription.isEmpty)
                HStack(spacing: 7) {
                    CategoryBadge(category: drink.category)
                    if !flavors.isEmpty {
                        Text(flavors.prefix(2).joined(separator: " · "))
                            .font(.pixel(size: 10)).foregroundStyle(Palette.purple).lineLimit(1)
                            .help("风味：\(flavors.joined(separator: "、"))")
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.pixel(size: 10)).foregroundStyle(Palette.muted)
                }.frame(height: 25).padding(.top, 9).padding(.bottom, 4)
            }.padding(11).background(.white, in: PixelFrame(cornerRadius: 15))
                .overlay(PixelFrame(cornerRadius: 15).strokeBorder(hovered ? Palette.purple : Palette.ink.opacity(0.5), lineWidth: 2))
                .shadow(color: Palette.ink.opacity(hovered ? 0.28 : 0.13), radius: 0, x: 4, y: 4)
                .offset(y: hovered ? -3 : 0)
                .contentShape(PixelFrame(cornerRadius: 15))
        }.buttonStyle(.plain).onHover { hovered = $0 }.animation(.easeOut(duration: 0.16), value: hovered)
            .accessibilityLabel("\(drink.name)，\(drink.variantDescription)，\(drink.category)，风味\(flavors.joined(separator: "、"))，查看详情")
            .task(id: store.knowledgeRevision) {
                let images = store.images
                let id = drink.id
                flavors = await Task.detached { (try? images.loadKnowledge(for: id))?.flavors ?? [] }.value
            }
    }
}
