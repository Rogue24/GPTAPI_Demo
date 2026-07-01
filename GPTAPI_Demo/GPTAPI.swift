//
//  GPTAPI.swift
//  GPTAPI_Demo
//
//  Created by 周健平 on 2023/5/2.
//
//  获取APIKey：https://platform.openai.com/account/api-keys
//
//  📢 注意：没做上下文联系，每次提问都是新的问题。

import SwiftyJSON

enum GPTAPI {
    /// ChatGPT API URL
    static let apiURL = "https://api.openai.com/v1/chat/completions"
    /// ChatGPT API Model
    static let apiModel = "gpt-3.5-turbo"
    /// ChatGPT API Key
    static let apiKey = "<#Your OpenAI API Key#>"
    
    /// AI 对话生成耗时可能比较长，统一在这里调整请求可等待时长。
    private static let requestTimeout: TimeInterval = 10 * 60 // 单次请求等待 10 分钟
    private static let resourceTimeout: TimeInterval = 20 * 60 // 整个资源加载最多 20 分钟
    
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = requestTimeout
        configuration.timeoutIntervalForResource = resourceTimeout
        return URLSession(configuration: configuration)
    }()
    
    enum Error: Swift.Error, LocalizedError {
        /// 参数错误
        case parameterWrong
        /// 请求失败
        case networkFailed
        /// 无效响应
        case invalidResponse
        
        var errorDescription: String? {
            switch self {
            case .parameterWrong:
                return "参数错误，请检查。"
            case .networkFailed:
                return "请求失败，检查网络。"
            case .invalidResponse:
                return "无效响应。"
            }
        }
    }
    
    private static func createRequest(_ problem: String, isStream: Bool = true) throws -> URLRequest {
        guard apiURL.count > 0, apiModel.count > 0 else {
            throw Self.Error.parameterWrong
        }
        
        let messages: [[String: Any]] = [
            [
                // 如果需要联系上下文，拼接时GPT方就使用"assistant"
                "role": "user", // 我发起的问题，所以角色就是我 --- "user"
                "content": problem
            ],
        ]

        var json: [String: Any] = [
            "model": apiModel,
            "messages": messages,
        ]
        
        // 关闭深度思考？
//        json["think"] = false
        
        // 想一个请求拿到完整的一个回答就不用写这两个参数
        if isStream {
            json["temperature"] = 0.5
            json["stream"] = true
        }
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: json) else {
            throw Self.Error.parameterWrong
        }
        
        let url = URL(string: apiURL)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = requestTimeout
        request.httpBody = jsonData
        
        return request
    }
    
    private static func checkResponse(_ rsp: URLResponse?) throws {
        guard let response = rsp as? HTTPURLResponse else {
            throw Self.Error.networkFailed
        }
        
        guard 200...299 ~= response.statusCode else {
            print("statusCode: \(response.statusCode)")
            print("description: \(response.description)")
            throw Self.Error.invalidResponse
        }
    }
}

// MARK: - 流式获取一个回答
@available(iOS 15.0, *)
extension GPTAPI {
    enum ContentType {
        case thinking
        case answer
    }
    
    struct Delta {
        let type: ContentType
        let text: String
    }
    
    static func ask(_ problem: String) async throws -> AsyncThrowingStream<Delta, Swift.Error> {
        let request = try createRequest(problem)
        
        let (result, rsp) = try await session.bytes(for: request)
        
        try checkResponse(rsp)
        
        return AsyncThrowingStream<Delta, Swift.Error> { continuation in
            Task(priority: .userInitiated) {
                do {
                    for try await line in result.lines {
                        /*
                         data: {"id":"chatcmpl-7BfPTGeZOaiHlReEcIhKaiOCNDwiH","object":"chat.completion.chunk","created":1683015143,"model":"gpt-3.5-turbo-0301","choices":[{"delta":{"content":"xxxxx"},"index":0,"finish_reason":null}]}
                         */
                        
                        guard line.hasPrefix("data: "),
                              let data = line.dropFirst(6).data(using: .utf8) // 丢掉前6个字符 --- "data: "
                        else {
                            // 某一帧解析失败了
                            print("有一帧解析失败了")
                            continue
                        }
                        
                        // 解析某一帧数据
                        let json = JSON(data)
                        
//                        let dict = json.dictionaryObject ?? [:]
//                        print("jjjjjjp~~~ \(dict)")
                        
                        let delta = json["choices"][0]["delta"]
                        
                        // 不一定是"reasoning"，可能是"reasoning_content"、"thinking"，或者直接混在"content"里。
                        if let content = delta["reasoning"].string {
                            continuation.yield(.init(type: .thinking, text: content))
                        }
                        
                        if let content = delta["content"].string {
                            continuation.yield(.init(type: .answer, text: content))
                        }
                        
                        if let finishReason = json["choices"][0]["finish_reason"].string, finishReason == "stop" {
                            // 全部拿完了
                            break
                        }
                    }
                    
                    // 全部解析完成，结束
                    continuation.finish()
                } catch {
                    // 发生错误，结束
                    continuation.finish(throwing: error)
                }
                
                // 流终止后的回调
                continuation.onTermination = { @Sendable status in
                    print("Stream terminated with status: \(status)")
                }
            }
        }
    }
}

// MARK: - 一次性获取完整的一个回答
extension GPTAPI {
    @discardableResult
    static func ask(_ problem: String, complete: @escaping (_ result: Result<String, Swift.Error>) -> Void) -> URLSessionDataTask? {
        
        let request: URLRequest
        do {
            request = try createRequest(problem, isStream: false)
        } catch {
            complete(.failure(error))
            return nil
        }
        
        let task = session.dataTask(with: request) { data, rsp, error in
            if let error = error {
                DispatchQueue.main.async { complete(.failure(error)) }
                return
            }
            
            do {
                try checkResponse(rsp)
            } catch {
                DispatchQueue.main.async { complete(.failure(error)) }
                return
            }
            
            /*
             ["usage": ["prompt_tokens": 26, "total_tokens": 346, "completion_tokens": 320], "model": gpt-3.5-turbo-0301, "choices": [["finish_reason": stop, "message": ["content": xxxxx, "role": assistant], "index": 0]], "id": chatcmpl-7Bh6lQew9W6uTzUCrqimcwDr0uF4G, "created": 1683021671, "object": chat.completion]
             */
            
            if let data = data, let content = JSON(data)["choices"][0]["message"]["content"].string {
                DispatchQueue.main.async { complete(.success(content)) }
            } else {
                DispatchQueue.main.async { complete(.success("")) }
            }
        }
        
        task.resume()
        return task
    }
    
    static func ask(_ problem: String) async throws -> String {
        let request = try createRequest(problem, isStream: false)
        
        let (data, rsp) = try await session.data(for: request)
        
        try checkResponse(rsp)
        
        /*
         ["usage": ["prompt_tokens": 26, "total_tokens": 346, "completion_tokens": 320], "model": gpt-3.5-turbo-0301, "choices": [["finish_reason": stop, "message": ["content": xxxxx, "role": assistant], "index": 0]], "id": chatcmpl-7Bh6lQew9W6uTzUCrqimcwDr0uF4G, "created": 1683021671, "object": chat.completion]
         */
        
        if let content = JSON(data)["choices"][0]["message"]["content"].string {
            return content
        } else {
            return ""
        }
    }
}
