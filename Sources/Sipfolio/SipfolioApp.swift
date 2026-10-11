import SwiftUI
import SwiftData
import ImageIO
import SipfolioCore

@main
struct SipfolioApp: App {
    @NSApplicationDelegateAdaptor(SipfolioApplicationDelegate.self) private var appDelegate
    @State private var store: CollectionStore?
    @State private var enrichment: CocktailEnrichmentCoordinator?
    @State private var isAdding = false
    @State private var startupError: String?

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "--verify-bundle-resources") {
            guard arguments.indices.contains(index + 1) else {
                print("Bundle resource verification requires an output file.")
                exit(2)
            }
            do {
                let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns")
                let iconSource = iconURL.flatMap { CGImageSourceCreateWithURL($0 as CFURL, nil) }
                let icon = iconSource.flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) }
                let font = PixelTypography.fontName
                let diagnostics: [String: Any] = [
                    "bundleIdentifier": Bundle.main.bundleIdentifier ?? "",
                    "hasBundledIcon": iconURL != nil,
                    "hasDecodedIcon": icon != nil,
                    "hasPixelFont": NSFont(name: font, size: 12) != nil && font != "Menlo"
                ]
                let output = URL(fileURLWithPath: arguments[index + 1])
                try JSONSerialization.data(withJSONObject: diagnostics, options: [.prettyPrinted, .sortedKeys]).write(to: output, options: .atomic)
                exit(0)
            } catch { print("Bundle resource verification failed: \(error.localizedDescription)"); exit(1) }
        }
        #if DEBUG
        if arguments.contains("--configure-deepseek") {
            do {
                guard let key = readLine() else { throw DeepSeekError.invalidKey }
                try DeepSeekKeychain.save(key)
                print("DeepSeek credential saved to macOS Keychain.")
                exit(0)
            } catch { print(error.localizedDescription); exit(1) }
        }
        if let index = arguments.firstIndex(of: "--verify-deepseek"), arguments.indices.contains(index + 2) {
            let photo = URL(fileURLWithPath: arguments[index + 1])
            let output = URL(fileURLWithPath: arguments[index + 2])
            Task.detached {
                do {
                    guard let key = try DeepSeekKeychain.load() else { throw DeepSeekError.missingKey }
                    let imageService = BottleCutoutService()
                    let source = try await imageService.loadPhoto(at: photo)
                    let jpeg = try await imageService.jpegForRecognition(from: source)
                    let client = DeepSeekService(apiKey: key)
                    _ = try await client.checkConnection()
                    let result = try await client.identify(jpeg: jpeg)
                    try JSONEncoder().encode(result).write(to: output, options: .atomic)
                    print("DeepSeek live verification succeeded; result saved.")
                    exit(0)
                } catch { print(error.localizedDescription); exit(1) }
            }
            RunLoop.main.run()
            exit(1)
        }
        if let index = arguments.firstIndex(of: "--verify-cocktail"), arguments.indices.contains(index + 1) {
            let output = URL(fileURLWithPath: arguments[index + 1])
            Task.detached {
                do {
                    guard let key = try DeepSeekKeychain.load() else { throw DeepSeekError.missingKey }
                    let result = try await DeepSeekService(apiKey: key).cocktailRecipe(name: "Gin & Tonic", bottleName: "Hendrick’s Gin", category: "金酒")
                    try JSONEncoder().encode(result).write(to: output, options: .atomic)
                    print("DeepSeek cocktail verification succeeded; result saved.")
                    exit(0)
                } catch { print(error.localizedDescription); exit(1) }
            }
            RunLoop.main.run()
            exit(1)
        }
        #else
        if arguments.contains(where: { ["--configure-deepseek", "--verify-deepseek", "--verify-cocktail"].contains($0) }) {
            print("Live AI diagnostics require a Debug build; configure AI in the app settings.")
            exit(2)
        }
        #endif
        if let index = arguments.firstIndex(of: "--verify-cocktail-media"), arguments.indices.contains(index + 1) {
            let output = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
            let cocktailName: String
            if let nameIndex = arguments.firstIndex(of: "--cocktail-name"), arguments.indices.contains(nameIndex + 1) { cocktailName = arguments[nameIndex + 1] }
            else { cocktailName = "Gin & Tonic" }
            Task.detached {
                do {
                    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
                    let referenceService = CocktailReferenceService()
                    let reference = try await referenceService.lookup(name: cocktailName)
                    guard let url = reference.photoURL else { throw CocktailReferenceError.notFound }
                    let source = try await referenceService.downloadPhoto(url)
                    let service = BottleCutoutService()
                    let original = try await service.normalizedPNG(from: source, maxPixelSize: 1600)
                    try original.write(to: output.appendingPathComponent("original.png"), options: .atomic)
                    let thumbnail = try await service.normalizedPNG(from: original, maxPixelSize: 420)
                    try thumbnail.write(to: output.appendingPathComponent("thumbnail.png"), options: .atomic)
                    try JSONEncoder().encode(reference.suggestion).write(to: output.appendingPathComponent("recipe.json"), options: .atomic)
                    print("Public cocktail recipe, original photograph and thumbnail verified.")
                    exit(0)
                } catch { print(error.localizedDescription); exit(1) }
            }
            RunLoop.main.run()
            exit(1)
        }
        if let index = arguments.firstIndex(of: "--verify-cocktail-photos"), arguments.indices.contains(index + 1) {
            let output = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
            let nameIndex = arguments.firstIndex(of: "--cocktail-name")
            let name = nameIndex.flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil } ?? "Paper Plane"
            Task.detached {
                do {
                    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
                    let service = CocktailPhotoService()
                    let result = try await service.search(name: name)
                    try JSONEncoder().encode(result.candidates).write(to: output.appendingPathComponent("candidates.json"), options: .atomic)
                    guard !result.candidates.isEmpty else { throw CocktailPhotoError.unavailable }
                    // Verify both a direct Commons source and an Openverse Flickr source when returned.
                    let choices = [result.candidates.first, result.candidates.first { $0.origin == .openverseFlickr }].compactMap { $0 }
                    for (index, candidate) in choices.enumerated() {
                        let (data, metadata) = try await service.download(candidate, searchTerm: name)
                        let original = try await BottleCutoutService().normalizedPNG(from: data, maxPixelSize: 1600)
                        try original.write(to: output.appendingPathComponent("photo-\(index).png"), options: .atomic)
                        try JSONEncoder().encode(metadata).write(to: output.appendingPathComponent("source-\(index).json"), options: .atomic)
                    }
                    print("Public image fallback search and source-verified photo download succeeded: \(result.candidates.count) candidates, \(choices.count) downloads.")
                    for notice in result.notices { print(notice) }
                    exit(0)
                } catch { print(error.localizedDescription); exit(1) }
            }
            RunLoop.main.run()
            exit(1)
        }
        let root: URL
        if let index = arguments.firstIndex(of: "--data-directory"), arguments.indices.contains(index + 1) {
            root = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        } else {
            root = CollectionStore.defaultRoot
        }
        if arguments.contains("--verify-app-shell"), root.standardizedFileURL.resolvingSymlinksInPath() == CollectionStore.defaultRoot.standardizedFileURL.resolvingSymlinksInPath() {
            print("App-shell verification requires an isolated --data-directory.")
            exit(2)
        }
        do {
            let collection = try CollectionStore(root: root)
            _store = State(initialValue: collection)
            _enrichment = State(initialValue: CocktailEnrichmentCoordinator(store: collection))
        }
        catch { _startupError = State(initialValue: error.localizedDescription) }
    }

    var body: some Scene {
        WindowGroup("Sipfolio") {
            if let store {
                CollectionView(store: store, isAdding: $isAdding, enrichment: enrichment)
                    .modelContainer(store.container)
                    .frame(minWidth: 960, minHeight: 680)
                    .preferredColorScheme(.light)
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "externaldrive.badge.exclamationmark").font(.pixel(size: 44))
                    Text("暂时无法打开收藏册").font(.title2.bold())
                    Text(startupError ?? "请检查本地存储空间后重新打开。").foregroundStyle(.secondary)
                    Button("退出 Sipfolio") { NSApplication.shared.terminate(nil) }
                }.padding(60).frame(minWidth: 650, minHeight: 400)
            }
        }
        .defaultSize(width: 1180, height: 800)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("新收藏") { isAdding = true }
                    .keyboardShortcut("n", modifiers: .command)
                    .disabled(store == nil)
            }
            CommandGroup(replacing: .appInfo) {
                Button("关于 Sipfolio") {
                    NSApplication.shared.orderFrontStandardAboutPanel(options: [
                        .applicationName: "Sipfolio",
                        .applicationVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "开发版",
                        .credits: NSAttributedString(string: "每一瓶，都是一段值得收藏的记忆。\n你的私人酒瓶图鉴与鸡尾酒配方册。")
                    ])
                }
            }
        }
        Settings { AISettingsView() }
    }
}

@MainActor
final class SipfolioApplicationDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // SwiftPM executables need an explicit ordinary-app policy when bundled for macOS.
        NSApplication.shared.setActivationPolicy(.regular)
        if let path = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"), let icon = NSImage(contentsOf: path) {
            NSApplication.shared.applicationIconImage = icon
        }
        if let index = ProcessInfo.processInfo.arguments.firstIndex(of: "--verify-app-shell"), ProcessInfo.processInfo.arguments.indices.contains(index + 1) {
            let output = URL(fileURLWithPath: ProcessInfo.processInfo.arguments[index + 1])
            let result: [String: Any] = ["bundleIdentifier": Bundle.main.bundleIdentifier ?? "", "activationPolicy": NSApplication.shared.activationPolicy().rawValue, "hasApplicationIcon": NSApplication.shared.applicationIconImage != nil, "hasBundledIcon": Bundle.main.url(forResource: "AppIcon", withExtension: "icns") != nil]
            var diagnostics = result
            diagnostics["pixelFont"] = PixelTypography.fontName
            diagnostics["hasPixelFont"] = NSFont(name: PixelTypography.fontName, size: 12) != nil && PixelTypography.fontName != "Menlo"
            do { try JSONSerialization.data(withJSONObject: diagnostics, options: [.prettyPrinted, .sortedKeys]).write(to: output, options: .atomic) }
            catch { print("Application shell verification failed.") }
            NSApplication.shared.terminate(nil)
        }
    }
}
