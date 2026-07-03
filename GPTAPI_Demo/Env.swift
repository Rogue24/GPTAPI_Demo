//
//  Env.swift
//  GPTAPI_Demo
//
//  Created by aa on 2026/7/1.
//

import UIKit

enum Env {
    
    static var mainWindow: UIWindow? {
        (UIApplication.shared.delegate as? AppDelegate)?.window
    }
    
    static var safeAreaInsets: UIEdgeInsets {
        guard let window = mainWindow else { return .zero }
        return window.safeAreaInsets
    }
    
    /// 屏幕尺寸
    static var screenSize: CGSize { screenBounds.size }
    /// 屏幕宽度
    static var screenWidth: CGFloat { screenBounds.width }
    /// 屏幕高度
    static var screenHeight: CGFloat { screenBounds.height }
    /// 屏幕区域
    static var screenBounds: CGRect {
        guard let window = mainWindow else { return .zero }
        return window.bounds
    }
    
}
