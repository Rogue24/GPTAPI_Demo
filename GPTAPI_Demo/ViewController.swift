//
//  ViewController.swift
//  GPTAPI_Demo
//
//  Created by 周健平 on 2023/5/2.
//

import UIKit
import FunnyButton
import SnapKit
import Down

struct SendableAttributedText: @unchecked Sendable {
    let value: NSAttributedString?

    init(_ value: NSAttributedString?) {
        // 关键：强制拷贝成不可变 NSAttributedString
        // 避免外部传进来的是 NSMutableAttributedString，然后后台/主线程同时改，直接开并发盲盒。
        self.value = value?.copy() as? NSAttributedString
    }
}

class ViewController: UIViewController {
    let scrollView = UIScrollView()
    let thinkingLabel = StreamingFadeLabel()
    let answerLabel = StreamingFadeLabel()
    
    let problem1 = "帮我用Swift写一个斐波那契数算法"
//    let problem1 = "帮我介绍一下春节的由来"
    let problem2 = "帮我用Python写一个斐波那契数算法"
    let problem3 = "帮我用Dart写一个斐波那契数算法"
    
    var isAsking = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        FunnyButton.shared.normalEmoji = "🤖"
        FunnyButton.shared.touchingEmoji = "🤖"
        
        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide).inset(20)
        }
        
        thinkingLabel.numberOfLines = 0
        scrollView.addSubview(thinkingLabel)
        thinkingLabel.snp.makeConstraints { make in
            make.width.equalToSuperview()
            make.leading.top.trailing.equalToSuperview()
        }
        
        answerLabel.numberOfLines = 0
        scrollView.addSubview(answerLabel)
        answerLabel.snp.makeConstraints { make in
            make.top.equalTo(thinkingLabel.snp.bottom)
            make.width.equalTo(thinkingLabel)
            make.leading.bottom.trailing.equalToSuperview()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        replaceFunnyActions([
            FunnyAction(name: "\(self.problem1) - 流", work: { [weak self] in
                guard let self else { return }
                
                guard !self.isAsking else {
                    JPHUD.showInfo(withStatus: "正在请求着，别急")
                    return
                }
                
                self.isAsking = true
                
                print("开始请求")
                self.thinkingLabel.text = "正在请求..."
                self.answerLabel.text = nil
                
                Task.detached {
                    do {
                        let stream: AsyncThrowingStream = try await GPTAPI.ask(self.problem1)
//                        await MainActor.run { self.text = "" }
//                        for try await text in stream {
//                            await MainActor.run {
//                                self.text += text
//                            }
//                        }
                        
                        var thinkingText = ""
                        var answerText = ""
                        for try await delta in stream {
                            let snapshot: String
                            let css: String
                            let textLabel: StreamingFadeLabel
                            switch delta.type {
                            case .thinking:
                                thinkingText += delta.text
                                snapshot = thinkingText
                                css = thinkingCSS
                                textLabel = self.thinkingLabel
                            case .answer:
                                answerText += delta.text
                                snapshot = answerText
                                css = answerCSS
                                textLabel = self.answerLabel
                            }
                            
                            let down = Down(markdownString: snapshot)
                            
                            var attStr: NSAttributedString?
                            if let attText = try? down.toAttributedString(stylesheet: css) {
                                attStr = attText
                            } else {
                                attStr = NSAttributedString(string: snapshot)
                            }
                            
                            let attText = SendableAttributedText(attStr)
                            
                            await MainActor.run {
                                // UILabel做法，效果不明显
//                                textLabel.attributedText = attText.value
//                                let transition = CATransition()
//                                transition.type = .fade
//                                transition.duration = 1
//                                textLabel.layer.add(transition, forKey: nil)
                                
                                textLabel.setStreamingAttributedText(attText.value)
                                
//                                if self.scrollView.isDragging || self.scrollView.isTracking {
//                                    return
//                                }
//                                UIView.animate(withDuration: 0.3) {
//                                    self.scrollView.layoutIfNeeded()
//                                    if self.scrollView.contentSize.height > self.scrollView.bounds.height {
//                                        let offsetY = self.scrollView.contentSize.height - self.scrollView.bounds.height
//                                        self.scrollView.contentOffset = CGPoint(x: 0, y: offsetY)
//                                    }
//                                }
                            }
                        }
                    } catch {
                        await MainActor.run {
                            self.thinkingLabel.text = nil
                            self.answerLabel.text = "请求失败 - \(error.localizedDescription)"
                        }
                    }
                    
                    // 请求结束
                    await MainActor.run {
                        self.isAsking = false
                    }
                }
            }),
            
            FunnyAction(name: "\(self.problem2) - await", work: { [weak self] in
                guard let self else { return }
                
                guard !self.isAsking else {
                    JPHUD.showInfo(withStatus: "正在请求着，别急")
                    return
                }
                
                self.isAsking = true
                
                print("开始请求")
                self.thinkingLabel.text = "正在请求..."
                self.answerLabel.text = nil
                
                Task.detached {
                    do {
                        let text: String = try await GPTAPI.ask(self.problem2)
                        
                        let down = Down(markdownString: text)
                        
                        var attStr: NSAttributedString?
                        if let attText = try? down.toAttributedString(stylesheet: answerCSS) {
                            attStr = attText
                        } else {
                            attStr = NSAttributedString(string: text)
                        }
                        
                        let attText = SendableAttributedText(attStr)
                        
                        await MainActor.run {
                            self.thinkingLabel.text = nil
                            self.answerLabel.setStreamingAttributedText(attText.value)
                        }
                    } catch {
                        await MainActor.run {
                            self.thinkingLabel.text = nil
                            self.answerLabel.text = "请求失败 - \(error.localizedDescription)"
                        }
                    }
                    
                    // 请求结束
                    await MainActor.run {
                        self.isAsking = false
                    }
                }
            }),
            
            FunnyAction(name: "\(self.problem3) - 闭包", work: { [weak self] in
                guard let self else { return }
                
                guard !self.isAsking else {
                    JPHUD.showInfo(withStatus: "正在请求着，别急")
                    return
                }
                
                self.isAsking = true
                
                print("开始请求")
                self.thinkingLabel.text = "正在请求..."
                self.answerLabel.text = nil

                GPTAPI.ask(self.problem3) { result in
                    switch result {
                    case let .success(text):
                        var attStr: NSAttributedString?
                        Asyncs.async {
                            let down = Down(markdownString: text)
                            if let attText = try? down.toAttributedString(stylesheet: answerCSS) {
                                attStr = attText
                            } else {
                                attStr = NSAttributedString(string: text)
                            }
                        } mainTask: {
                            self.thinkingLabel.text = nil
                            self.answerLabel.setStreamingAttributedText(attStr)
                            // 请求结束
                            self.isAsking = false
                        }
                    case let .failure(error):
                        self.thinkingLabel.text = nil
                        self.answerLabel.text = "请求失败 - \(error.localizedDescription)"
                        // 请求结束
                        self.isAsking = false
                    }
                }
            }),
        ])
    }
}

extension ViewController {
//    func
}







let thinkingCSS = """
body {
    margin: 0;
    padding: 0;
    font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", Helvetica, Arial, sans-serif;
    font-size: 14px;
    line-height: 1.55;
    color: #8A8F98;
    background-color: transparent;
}

p {
    margin: 0 0 8px 0;
    color: #8A8F98;
}

strong,
b {
    font-weight: 600;
    color: #6E7681;
}

em,
i {
    font-style: italic;
    color: #8A8F98;
}

a {
    color: #6B8FD6;
    text-decoration: none;
}

ul,
ol {
    margin: 6px 0 8px 20px;
    padding: 0;
    color: #8A8F98;
}

li {
    margin: 3px 0;
    color: #8A8F98;
}

blockquote {
    margin: 8px 0;
    padding: 0 0 0 10px;
    color: #8A8F98;
}

code {
    font-family: Menlo, Monaco, Consolas, "Courier New", monospace;
    font-size: 13px;
    color: #7A828E;
    background-color: #F2F4F7;
}

pre {
    margin: 8px 0;
    padding: 8px;
    background-color: #F2F4F7;
}

pre code {
    font-size: 13px;
    line-height: 1.5;
    color: #7A828E;
    background-color: transparent;
}

h1 {
    font-size: 17px;
    font-weight: 600;
    color: #6E7681;
    margin: 10px 0 6px 0;
}

h2 {
    font-size: 16px;
    font-weight: 600;
    color: #6E7681;
    margin: 10px 0 6px 0;
}

h3,
h4,
h5,
h6 {
    font-size: 15px;
    font-weight: 600;
    color: #6E7681;
    margin: 8px 0 5px 0;
}
"""

let answerCSS = """
body {
    margin: 0;
    padding: 0;
    font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", Helvetica, Arial, sans-serif;
    font-size: 16px;
    line-height: 1.65;
    color: #1F2328;
    background-color: transparent;
}

p {
    margin: 0 0 12px 0;
    color: #1F2328;
}

strong,
b {
    font-weight: 700;
    color: #111827;
}

em,
i {
    font-style: italic;
    color: #374151;
}

a {
    color: #2563EB;
    text-decoration: none;
}

ul,
ol {
    margin: 8px 0 12px 22px;
    padding: 0;
    color: #1F2328;
}

li {
    margin: 4px 0;
    line-height: 1.6;
    color: #1F2328;
}

blockquote {
    margin: 12px 0;
    padding: 0 0 0 12px;
    color: #57606A;
}

blockquote p {
    color: #57606A;
}

code {
    font-family: Menlo, Monaco, Consolas, "Courier New", monospace;
    font-size: 14px;
    color: #B42318;
    background-color: #F6F8FA;
}

pre {
    margin: 12px 0;
    padding: 10px;
    background-color: #F6F8FA;
}

pre code {
    font-size: 14px;
    line-height: 1.55;
    color: #24292F;
    background-color: transparent;
}

h1 {
    font-size: 24px;
    line-height: 1.3;
    font-weight: 700;
    color: #111827;
    margin: 20px 0 12px 0;
}

h2 {
    font-size: 21px;
    line-height: 1.35;
    font-weight: 700;
    color: #111827;
    margin: 18px 0 10px 0;
}

h3 {
    font-size: 18px;
    line-height: 1.4;
    font-weight: 700;
    color: #111827;
    margin: 16px 0 8px 0;
}

h4 {
    font-size: 16px;
    line-height: 1.45;
    font-weight: 700;
    color: #111827;
    margin: 14px 0 8px 0;
}

h5,
h6 {
    font-size: 15px;
    line-height: 1.45;
    font-weight: 700;
    color: #111827;
    margin: 12px 0 6px 0;
}

hr {
    margin: 16px 0;
    color: #D0D7DE;
}
"""
