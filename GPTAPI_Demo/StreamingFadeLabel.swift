//
//  StreamingFadeLabel.swift
//  GPTAPI_Demo
//
//  Created by aa on 2026/7/1.
//

import UIKit

class StreamingFadeLabel: UILabel {
    
    var fadeDuration: TimeInterval = 0.3
    
    private(set) var targetAttributedText = NSAttributedString()
    
    private struct FadeRun {
        let range: NSRange
        let startTime: CFTimeInterval
        let duration: TimeInterval
    }
    private var fadeRuns: [FadeRun] = []
    
    private var displayLink: CADisplayLink?
    private let animationFramesPerSecond = 30 // 帧率
    
    override var text: String? {
        get { super.text }
        set {
            setImmediately(newValue.map(NSAttributedString.init(string:)))
        }
    }
    
    override var attributedText: NSAttributedString? {
        get { super.attributedText }
        set {
            setImmediately(newValue)
        }
    }
    
    deinit {
        displayLink?.invalidate()
    }
    
    func setStreamingAttributedText(_ newValue: NSAttributedString?) {
        let newText = (newValue?.copy() as? NSAttributedString) ?? NSAttributedString()
        let oldString = targetAttributedText.string
        let newString = newText.string
        let fadeStart = oldString.commonPrefixUTF16Length(with: newString)
        setStreamingAttributedText(newText, fadeStart: fadeStart)
    }
    
    func setStreamingAttributedText(_ newText: NSAttributedString, fadeStart: Int) {
        targetAttributedText = newText
        
        guard !UIAccessibility.isReduceMotionEnabled else {
            finishAnimation()
            return
        }
        
        if fadeStart < newText.length {
            fadeRuns.append(
                FadeRun(
                    range: NSRange(location: fadeStart, length: newText.length - fadeStart),
                    startTime: CACurrentMediaTime(),
                    duration: fadeDuration
                )
            )
        }
        
        renderAnimationFrame()
        if !fadeRuns.isEmpty {
            startDisplayLinkIfNeeded()
        }
    }
    
    private func setImmediately(_ newValue: NSAttributedString?) {
        displayLink?.invalidate()
        displayLink = nil
        fadeRuns.removeAll()
        targetAttributedText = (newValue?.copy() as? NSAttributedString) ?? NSAttributedString()
        super.attributedText = targetAttributedText
    }
    
    private func startDisplayLinkIfNeeded() {
        guard displayLink == nil else { return }
        
        let link = CADisplayLink(target: self, selector: #selector(handleDisplayLink))
        if #available(iOS 15.0, *) {
            let frameRate = Float(animationFramesPerSecond)
            link.preferredFrameRateRange = CAFrameRateRange(
                minimum: frameRate,
                maximum: frameRate,
                preferred: frameRate
            )
        } else {
            link.preferredFramesPerSecond = animationFramesPerSecond
        }
        link.add(to: .main, forMode: .common)
        displayLink = link
    }
    
    @objc private func handleDisplayLink() {
        renderAnimationFrame()
    }
    
    private func renderAnimationFrame() {
        guard !fadeRuns.isEmpty else {
            finishAnimation()
            return
        }
        
        let now = CACurrentMediaTime()
        let renderedText = NSMutableAttributedString(attributedString: targetAttributedText)
        var activeRuns: [FadeRun] = []

        for run in fadeRuns {
            let progress = min(max((now - run.startTime) / run.duration, 0), 1)
            if progress < 1 {
                activeRuns.append(run)
                renderedText.applyForegroundAlpha(
                    CGFloat(progress),
                    range: run.range,
                    fallbackColor: textColor ?? .label
                )
            }
        }
        
        fadeRuns = activeRuns
        super.attributedText = renderedText
        
        if fadeRuns.isEmpty {
            finishAnimation()
        }
    }
    
    private func finishAnimation() {
        displayLink?.invalidate()
        displayLink = nil
        fadeRuns.removeAll()
        super.attributedText = targetAttributedText
    }
}

private extension NSMutableAttributedString {
    func applyForegroundAlpha(_ alpha: CGFloat, range: NSRange, fallbackColor: UIColor) {
        let fullRange = NSRange(location: 0, length: length)
        let clampedRange = NSIntersectionRange(range, fullRange)
        guard clampedRange.length > 0 else { return }
        
        var updates: [(UIColor, NSRange)] = []
        enumerateAttribute(.foregroundColor, in: clampedRange) { value, range, _ in
            let color = (value as? UIColor) ?? fallbackColor
            updates.append((color.withAlphaComponent(color.cgColor.alpha * alpha), range))
        }
        
        for (color, range) in updates {
            addAttribute(.foregroundColor, value: color, range: range)
        }
    }
}

extension String {
    func commonPrefixUTF16Length(with other: String) -> Int {
        let lhs = Array(utf16)
        let rhs = Array(other.utf16)
        var index = 0
        
        while index < lhs.count, index < rhs.count, lhs[index] == rhs[index] {
            index += 1
        }
        
        return index
    }
}
