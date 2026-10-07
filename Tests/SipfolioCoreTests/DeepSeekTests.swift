import Testing
import Foundation
@testable import SipfolioCore

private func envelope(name: String? = "Hendrick’s Gin", category: String = "金酒", finish: String = "stop") throws -> Data {
    let fields: [String: Any] = ["name": name as Any? ?? NSNull(), "category": category, "confidence": "high", "introduction": "一款具有黄瓜和玫瑰风味的金酒。", "flavors": ["黄瓜", "玫瑰"], "cocktails": ["Gin & Tonic"], "uncertainty": "请核对版本。"]
    let content = String(data: try JSONSerialization.data(withJSONObject: fields), encoding: .utf8)!
    return try JSONSerialization.data(withJSONObject: ["choices": [["message": ["content": content], "finish_reason": finish]]])
}

private actor RecordingTransport: AIHTTPTransport {
    let response: Data
    let status: Int
    var requests: [URLRequest] = []
    init(response: Data, status: Int = 200) { self.response = response; self.status = status }
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        return (response, HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }
    func firstRequest() -> URLRequest? { requests.first }
}

@Test
func visionRequestUsesOfficialHostAndStructuredImageInput() async throws {
    let transport = RecordingTransport(response: try envelope())
    let service = DeepSeekService(apiKey: "test-only-credential", transport: transport)
    let result = try await service.identify(jpeg: Data([1, 2, 3]), nameHint: "已有酒名")
    #expect(result.name == "Hendrick’s Gin")
    #expect(result.flavors == ["黄瓜", "玫瑰"])
    let request = try #require(await transport.firstRequest())
    #expect(request.url?.scheme == "https")
    #expect(request.url?.host == "api.deepseek.com")
    #expect(request.url?.path == "/chat/completions")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-only-credential")
    let body = try #require(request.httpBody)
    #expect(!String(decoding: body, as: UTF8.self).contains("test-only-credential"))
    let object = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
    #expect(object["model"] as? String == "deepseek-flash")
    #expect((object["response_format"] as? [String: String])?["type"] == "json_object")
    let messages = try #require(object["messages"] as? [[String: Any]])
    let parts = try #require(messages.last?["content"] as? [[String: Any]])
    #expect((parts.last?["image_url"] as? [String: String])?["url"] == "data:image/jpeg;base64,AQID")
}

@Test
func rejectedCredentialsHaveActionableError() async throws {
    let service = DeepSeekService(apiKey: "test-only-credential", transport: RecordingTransport(response: Data(), status: 401))
    await #expect(throws: DeepSeekError.http(401)) { try await service.identify(jpeg: Data()) }
}

@Test
func truncatedOrMalformedModelOutputIsNeverAccepted() throws {
    #expect(throws: DeepSeekError.badResponse) { try DeepSeekService.decodeKnowledge(from: envelope(finish: "length")) }
    #expect(throws: DeepSeekError.badResponse) { try DeepSeekService.decodeKnowledge(from: Data("bad JSON".utf8)) }
}

@Test
func unknownWineDoesNotReceiveInventedKnowledge() throws {
    let result = try DeepSeekService.decodeKnowledge(from: envelope(name: nil, category: "任意新类别"))
    #expect(result.name == nil)
    #expect(result.category == nil)
    #expect(result.confidence == "low")
    #expect(result.introduction.isEmpty && result.flavors.isEmpty && result.cocktails.isEmpty)
}

@Test
func recognizedCustomCategoriesArePreserved() throws {
    let result = try DeepSeekService.decodeKnowledge(from: envelope(name: "测试蜂蜜酒", category: " 蜂蜜酒 "))
    #expect(result.category == "蜂蜜酒")
}

private func cocktailEnvelope(finish: String = "stop", ingredients: [[String: String]] = [["name": "金酒", "amount": "45 ml"], ["name": "汤力水", "amount": "120 ml"]]) throws -> Data {
    let fields: [String: Any] = ["name": "Gin & Tonic", "ingredients": ingredients, "steps": ["杯中加入冰块。", "倒入金酒和汤力水，轻轻搅拌。"], "glass": "高球杯", "garnish": "青柠", "notes": "参考比例，可调整。"]
    let content = String(data: try JSONSerialization.data(withJSONObject: fields), encoding: .utf8)!
    return try JSONSerialization.data(withJSONObject: ["choices": [["message": ["content": content], "finish_reason": finish]]])
}

@Test
func cocktailRequestIsTextOnlyAndReturnsEditableRecipe() async throws {
    let transport = RecordingTransport(response: try cocktailEnvelope())
    let service = DeepSeekService(apiKey: "test-only-credential", transport: transport)
    let result = try await service.cocktailRecipe(name: "Gin & Tonic", bottleName: "Hendrick’s Gin", category: "金酒")
    #expect(result.ingredientsText.contains("金酒 — 45 ml"))
    #expect(result.stepsText.hasPrefix("1. "))
    let request = try #require(await transport.firstRequest())
    #expect(request.url?.absoluteString == "https://api.deepseek.com/chat/completions")
    let body = try #require(request.httpBody)
    let object = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
    let messages = try #require(object["messages"] as? [[String: Any]])
    let userContent = try #require(messages.last?["content"] as? String)
    #expect(userContent.contains("Hendrick’s Gin") && userContent.contains("Gin & Tonic"))
    #expect(!String(decoding: body, as: UTF8.self).contains("image_url"))
}

@Test
func incompleteCocktailRecipesCannotBeApplied() throws {
    #expect(throws: DeepSeekError.badResponse) { try DeepSeekService.decodeCocktail(from: cocktailEnvelope(finish: "length")) }
    #expect(throws: DeepSeekError.badResponse) { try DeepSeekService.decodeCocktail(from: cocktailEnvelope(ingredients: [])) }
    #expect(throws: DeepSeekError.badResponse) { try DeepSeekService.decodeCocktail(from: Data("bad JSON".utf8)) }
}

@Test
func connectivityRequiresAvailableVisionModel() async throws {
    let available = DeepSeekService(apiKey: "test-only-credential", transport: RecordingTransport(response: Data("{\"data\":[{\"id\":\"deepseek-flash\"}]}".utf8)))
    #expect(try await available.checkConnection() == ["deepseek-flash"])
    let absent = DeepSeekService(apiKey: "test-only-credential", transport: RecordingTransport(response: Data("{\"data\":[{\"id\":\"other-model\"}]}".utf8)))
    await #expect(throws: DeepSeekError.noVisionModel) { try await absent.checkConnection() }
}

@Test @MainActor
func aiKnowledgeSurvivesReopenAndLegacyRecordsStayReadable() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("SipfolioAITest-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try CollectionStore(root: root)
    let image = try testPNG()
    let legacy = try store.add(name: "旧收藏", category: "其他", notes: "自己的备注", original: image, sticker: image, thumbnail: image, usesOriginalPhoto: true)
    #expect(try store.images.loadKnowledge(for: legacy.id) == nil)
    let knowledge = try DeepSeekService.decodeKnowledge(from: envelope())
    let drink = try store.add(name: knowledge.name!, category: "金酒", notes: "保留个人品鉴", original: image, sticker: image, thumbnail: image, usesOriginalPhoto: false, knowledge: knowledge)
    let reopened = try CollectionStore(root: root)
    #expect(try reopened.allDrinks().count == 2)
    #expect(try reopened.images.loadKnowledge(for: drink.id) == knowledge)
    #expect(try reopened.images.loadKnowledge(for: legacy.id) == nil)
    var conflict = knowledge
    conflict.name = "旧收藏"
    #expect(throws: SipfolioError.self) { try store.applyKnowledge(conflict, to: drink) }
    #expect(try store.images.loadKnowledge(for: drink.id) == knowledge)
    var accepted = knowledge
    accepted.name = "Hendrick’s Gin 新版"
    try store.applyKnowledge(accepted, to: drink)
    #expect(drink.name == "Hendrick’s Gin 新版")
    #expect(drink.notes == "保留个人品鉴")
    #expect(try store.images.loadKnowledge(for: drink.id) == accepted)
}
