# GPTAPI_Demo

使用`AsyncThrowingStream`实现类似ChatGPT官网那种一个接一个字地展示的效果。

## AsyncThrowingStream

`AsyncThrowingStream`是可以导致抛出错误的元素流（具体介绍和用法可以看这篇文章：[Swift AsyncThrowingStream 和 AsyncStream 代码实例详解](https://juejin.cn/post/7210216031536185402)）。

结合`URLSession`，不用等全部数据都拼接好才拿到最终结果，可以实时获取服务器传过来的数据，给多少就展示多少，跟水流一样。

## Talk is cheap. Show me the code.

1. 首先封装一个请求工具类
```swift
enum GPTAPI {
    /// ChatGPT API URL
    static let apiURL = "https://api.openai.com/v1/chat/completions"
    /// ChatGPT API Model
    static let apiModel = "gpt-3.5-turbo"
    /// ChatGPT API Key
    static let apiKey = Your OpenAI API Key
}

// MARK: - 流式获取一个回答
@available(iOS 15.0, *)
extension GPTAPI {
    static func ask(_ problem: String) async throws -> AsyncThrowingStream<String, Swift.Error> {
        let messages: [[String: Any]] = [
            [
                // 如果需要联系上下文，拼接时GPT方就使用"assistant"
                "role": "user", // 我发起的问题，所以角色就是我 --- "user"
                "content": problem
            ],
        ]

        let json: [String: Any] = [
            "model": apiModel,
            "messages": messages,
            "temperature" = 0.5,
            "stream" = true,
        }
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: json) else {
            throw Self.Error.parameterWrong
        }
        
        let url = URL(string: apiURL)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        let (result, rsp) = try await URLSession.shared.bytes(for: request)
        
        guard let response = rsp as? HTTPURLResponse else {
            throw Self.Error.networkFailed
        }
        
        guard 200...299 ~= response.statusCode else {
            throw Self.Error.invalidResponse
        }
        
        return AsyncThrowingStream<String, Swift.Error> { continuation in
            Task(priority: .userInitiated) {
                do {
                    for try await line in result.lines {
                        /*
                         data: {"id":"chatcmpl-7BfPTGeZOaiHlReEcIhKaiOCNDwiH","object":"chat.completion.chunk","created":1683015143,"model":"gpt-3.5-turbo-0301","choices":[{"delta":{"content":"xxxxx"},"index":0,"finish_reason":null}]}
                         */
                        
                        guard line.hasPrefix("data: "),
                              let data = line.dropFirst(6).data(using: .utf8) // 丢掉前6个字符 --- "data: "
                        else {
                            print("有一帧解析失败了")
                            continue

                        }
                        
                        // 解析某一帧数据
                        let json = JSON(data)
                        
                        if let content = json["choices"][0]["delta"]["content"].string {
                            continuation.yield(content)
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
                
                // 终止回调（全部拿完了）
                continuation.onTermination = { @Sendable status in
                    print("Stream terminated with status: \(status)")
                }
            }
        }
    }
}
```

2. OK，开始询问
```swift
Task.detached {
    do {
        let stream: AsyncThrowingStream = try await GPTAPI.ask("帮我用Swift写一个斐波那契数算法")
        
        // 先清空上次回答
        await MainActor.run { 
            self.text = ""
        }
        
        // 拼接数据流
        for try await text in stream {
            await MainActor.run {
                self.text += text
            }
        }
    } catch {
        await MainActor.run {
            self.text = "请求失败 - \(error.localizedDescription)"
        }
    }
    
    // 来到这里，说明请求已结束
}
```

3. 实现效果

![example](https://github.com/Rogue24/JPCover/raw/master/GPTAPI_Demo/example.gif)

OK，完成。

## 最后

剩下的无非就是UI、Markdown解析、数据存储和请求上下文的拼接，弄好就是一个ChatGPT的App了，本菜鸡搞不了，还有很多不懂的地方要学习。

`AsyncThrowingStream`还有很多用法，再次安利这篇文章：[Swift AsyncThrowingStream 和 AsyncStream 代码实例详解](https://juejin.cn/post/7210216031536185402)），另外大神写好的ChatGPT客户端[Sensei](https://github.com/nixzhu/Sensei)，本文代码都是参考他的。
