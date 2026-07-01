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
    
}
