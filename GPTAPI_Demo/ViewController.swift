//
//  ViewController.swift
//  GPTAPI_Demo
//
//  Created by 周健平 on 2023/5/2.
//

import UIKit
import FunnyButton

class ViewController: UIViewController {
    @IBOutlet weak var textLabel: UILabel!
    
    var text: String = "" {
        didSet {
            textLabel.text = text
        }
    }
    
    let problem1 = "帮我用Swift写一个斐波那契数算法"
    let problem2 = "帮我用Python写一个斐波那契数算法"
    let problem3 = "帮我用Dart写一个斐波那契数算法"
    
    var isAsking = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        FunnyButton.normalEmoji = "🤖"
        FunnyButton.touchingEmoji = "👽"
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        replaceFunnyActions([
            FunnyAction(name: "\(self.problem1) - 流", work: { [weak self] in
                guard let self = self else { return }
                guard !self.isAsking else {
                    print("正在请求着，别急")
                    return
                }
                self.isAsking = true
                
                self.text = "正在请求..."
                print("开始请求")
                
                Task.detached {
                    do {
                        let stream: AsyncThrowingStream = try await GPTAPI.ask(self.problem1)
                        await MainActor.run { self.text = "" }
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
                    
                    // 请求结束
                    await MainActor.run {
                        self.isAsking = false
                    }
                }
            }),
            
            FunnyAction(name: "\(self.problem2) - await", work: { [weak self] in
                guard let self = self else { return }
                guard !self.isAsking else {
                    print("正在请求着，别急")
                    return
                }
                self.isAsking = true
                
                self.text = "正在请求..."
                print("开始请求")
                
                Task.detached {
                    do {
                        let text: String = try await GPTAPI.ask(self.problem2)
                        await MainActor.run {
                            self.text = text
                        }
                    } catch {
                        await MainActor.run {
                            self.text = "请求失败 - \(error.localizedDescription)"
                        }
                    }
                    
                    // 请求结束
                    await MainActor.run {
                        self.isAsking = false
                    }
                }
            }),
            
            FunnyAction(name: "\(self.problem3) - 闭包", work: {[weak self] in
                guard let self = self else { return }
                guard !self.isAsking else {
                    print("正在请求着，别急")
                    return
                }
                self.isAsking = true
                
                self.text = "正在请求..."
                print("开始请求")
                
                GPTAPI.ask(self.problem3) { result in
                    switch result {
                    case let .success(text):
                        self.text = text
                    case let .failure(error):
                        self.text = "请求失败 - \(error.localizedDescription)"
                    }
                    // 请求结束
                    self.isAsking = false
                }
            }),
        ])
        
    }


}

