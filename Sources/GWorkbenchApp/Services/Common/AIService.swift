import Foundation

public struct AIProviderPreset: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let displayName: String
    public let defaultBaseURL: String
    public let defaultModel: String
    public let description: String

    public static let deepseek = AIProviderPreset(
        id: "deepseek",
        name: "DeepSeek",
        displayName: "DeepSeek (推荐 · 极高性价比)",
        defaultBaseURL: "https://api.deepseek.com",
        defaultModel: "deepseek-chat",
        description: "高智能中文理解与代码分析能力，响应极速，性价比极高"
    )

    public static let openai = AIProviderPreset(
        id: "openai",
        name: "OpenAI",
        displayName: "OpenAI",
        defaultBaseURL: "https://api.openai.com/v1",
        defaultModel: "gpt-4o-mini",
        description: "官方 OpenAI 接口，支持 gpt-4o-mini / gpt-4o 等"
    )

    public static let kimi = AIProviderPreset(
        id: "kimi",
        name: "Kimi",
        displayName: "Kimi (Moonshot)",
        defaultBaseURL: "https://api.moonshot.cn/v1",
        defaultModel: "moonshot-v1-8k",
        description: "Moonshot Kimi 中文长文本大模型"
    )

    public static let qwen = AIProviderPreset(
        id: "qwen",
        name: "Qwen",
        displayName: "通义千问 (Qwen)",
        defaultBaseURL: "https://dashscope.aliyuncs.com/compatible-mode/v1",
        defaultModel: "qwen-turbo",
        description: "阿里云百炼 OpenAI 兼容端点"
    )

    public static let ollama = AIProviderPreset(
        id: "ollama",
        name: "Ollama",
        displayName: "Ollama (本地私有模型)",
        defaultBaseURL: "http://localhost:11434/v1",
        defaultModel: "llama3",
        description: "本地私有大模型，无需外部网络，完全离线安全"
    )

    public static let custom = AIProviderPreset(
        id: "custom",
        name: "Custom",
        displayName: "自定义 (OpenAI 兼容端点)",
        defaultBaseURL: "",
        defaultModel: "",
        description: "支持任意自建代理、聚合 API 或企业私有网关"
    )

    public static let allPresets: [AIProviderPreset] = [
        .deepseek,
        .openai,
        .kimi,
        .qwen,
        .ollama,
        .custom
    ]
}

public struct AIGeneratedBranches: Codable, Sendable {
    public let recommended: String
    public let alternatives: [String]
}

public final class AIService: Sendable {
    public static let shared = AIService()

    public init() {}

    /// 测试 API 连通性
    public func testConnection(baseURL: String, apiKey: String, model: String) async throws -> String {
        let normalizedURL = normalizeBaseURL(baseURL)
        guard let url = URL(string: "\(normalizedURL)/chat/completions") else {
            throw WorkbenchError.message("无效的 API 请求地址: \(baseURL)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            request.setValue("Bearer \(apiKey.trimmingCharacters(in: .whitespacesAndNewlines))", forHTTPHeaderField: "Authorization")
        }

        let payload: [String: Any] = [
            "model": model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "deepseek-chat" : model,
            "messages": [
                ["role": "user", "content": "ping"]
            ],
            "max_tokens": 5
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WorkbenchError.message("非 HTTP 响应")
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "未知响应"
            throw WorkbenchError.message("API 响应错误 (\(httpResponse.statusCode)): \(errorBody)")
        }

        return "API 握手成功 (HTTP 200 OK)"
    }

    /// 根据功能描述生成 Git 分支名
    public func generateBranchName(
        description: String,
        projectName: String,
        isEnterprise: Bool,
        middle: String,
        baseURL: String,
        apiKey: String,
        model: String
    ) async throws -> AIGeneratedBranches {
        let trimmedDesc = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDesc.isEmpty else {
            throw WorkbenchError.message("请先输入功能描述")
        }

        let normalizedURL = normalizeBaseURL(baseURL)
        guard let url = URL(string: "\(normalizedURL)/chat/completions") else {
            throw WorkbenchError.message("无效的 API 请求地址: \(baseURL)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            request.setValue("Bearer \(apiKey.trimmingCharacters(in: .whitespacesAndNewlines))", forHTTPHeaderField: "Authorization")
        }

        let middlePrefix = (!middle.isEmpty && isEnterprise) ? "\(middle)/" : ""
        let exampleRecommended = isEnterprise ? "feat/\(middlePrefix)order-timeout-retry" : "feat/order-timeout-retry"

        let systemPrompt = """
        你是一个精通 Git 规范的代码开发助手。
        你的任务是根据用户提供的【功能描述/需求背景】，生成规范、简练、地道的 Git 分支名。

        分支命名规范必须严格遵守：
        1. 必须以类型前缀开头：
           - 新需求/特性: `feat/`
           - 缺陷修复/Bug修复: `fix/`
           - 代码重构: `refactor/`
           - 性能优化: `perf/`
           - 文档/工程配置: `chore/`
        \(isEnterprise && !middle.isEmpty ? "2. 本仓库为企业业务模式，类型前缀后必须紧跟开发名前缀：`\(middlePrefix)`，例如 `feat/\(middlePrefix)xxx` 或 `fix/\(middlePrefix)xxx`。" : "2. 使用标准的 `feat/xxx` 或 `fix/xxx` 结构。")
        3. 描述主体单词：全小写、使用短横线 (kebab-case) 连接、精炼英文，2~4 个单词为宜，直击要点。
        4. 严格输出为 JSON 格式，包含 1 个最推荐的分支名和 2 个备选分支名：
        {
          "recommended": "\(exampleRecommended)",
          "alternatives": [
            "...",
            "..."
          ]
        }
        请直接输出纯 JSON 字符串，不要包含任何 markdown 标记（如 ```json）或多余解释。
        """

        let payload: [String: Any] = [
            "model": model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "deepseek-chat" : model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": "项目名称: \(projectName)\n功能描述: \(trimmedDesc)"]
            ],
            "temperature": 0.3,
            "max_tokens": 150
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WorkbenchError.message("非 HTTP 响应")
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "未知响应"
            throw WorkbenchError.message("AI 生成失败 (\(httpResponse.statusCode)): \(errorBody)")
        }

        guard let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = jsonObject["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw WorkbenchError.message("无法解析 AI 返回的数据结构")
        }

        // 解析模型返回的 JSON
        let cleanedContent = cleanJSONString(content)
        if let contentData = cleanedContent.data(using: .utf8),
           let result = try? JSONDecoder().decode(AIGeneratedBranches.self, from: contentData) {
            return result
        }

        // 如果模型输出略有偏差，做容错提取
        return parseFallbackBranches(rawText: content, fallbackPrefix: isEnterprise ? "feat/\(middlePrefix)" : "feat/")
    }

    private func normalizeBaseURL(_ url: String) -> String {
        var trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "https://api.deepseek.com"
        }
        while trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }
        return trimmed
    }

    private func cleanJSONString(_ text: String) -> String {
        var str = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if str.hasPrefix("```json") {
            str = String(str.dropFirst("```json".count))
        } else if str.hasPrefix("```") {
            str = String(str.dropFirst("```".count))
        }
        if str.hasSuffix("```") {
            str = String(str.dropLast("```".count))
        }
        return str.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseFallbackBranches(rawText: String, fallbackPrefix: String) -> AIGeneratedBranches {
        let lines = rawText
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.contains("feat/") || $0.contains("fix/") || $0.contains("refactor/") }

        if let first = lines.first {
            let alts = Array(lines.dropFirst().prefix(2))
            return AIGeneratedBranches(recommended: sanitizeBranchName(first), alternatives: alts.map(sanitizeBranchName))
        }

        let sanitized = sanitizeBranchName(rawText)
        return AIGeneratedBranches(
            recommended: sanitized.isEmpty ? "\(fallbackPrefix)new-feature" : sanitized,
            alternatives: []
        )
    }

    private func sanitizeBranchName(_ name: String) -> String {
        name
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
