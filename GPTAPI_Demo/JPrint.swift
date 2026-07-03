//
//  JPrint.swift
//  GPTAPI_Demo
//
//  Created by aa on 2026/7/1.
//

import Foundation
#if DEBUG
import os

private let logger_subsystem = "com.zhoujianping.logger"
private let logger_category = "JPDebug"
private let logger = OSLog(subsystem: logger_subsystem, category: logger_category)

//private let hhmmssSSFormatter: DateFormatter = {
//    let formatter = DateFormatter()
//    formatter.locale = Locale(identifier: "zh_CN")
//    formatter.dateFormat = "hh:mm:ss.SS"
//    return formatter
//}()

private let JPrintQueue = DispatchQueue(label: "com.zhoujianping.JPrintQueue")
#endif

/// 自定义日志
func JPrint(_ msg: Any..., file: NSString = #file, line: Int = #line, fn: String = #function) {
    JPrint(msg, file: file, line: line, fn: fn)
}

func JPrint(_ msg: [Any], file: NSString = #file, line: Int = #line, fn: String = #function) {
#if DEBUG
    guard msg.count > 0 else { return }
    
    // 时间+文件位置+行数
//    let date = hhmmssSSFormatter.string(from: Date()).utf8
//    let fileName = (file.lastPathComponent as NSString).deletingPathExtension
//    let prefix = "[\(date)] [\(fileName) \(fn)] [第\(line)行]:"
//    let prefix = "jpjpjp [\(date)]:"
    // os_log自带时间，不用自己拼接了
    let prefix = "jpjpjp:"
    
    JPrintQueue.sync {
        let fullMsg = ([prefix] + msg).map { "\($0)" }.joined(separator: " ")
        os_log(.debug, log: logger, "%{public}@", fullMsg)
    }
#endif
}
