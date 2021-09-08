//
//  HighlightTextView.swift
//  HightlightTextView
//
//  Created by Ryan Holden on 9/6/21.
//

import Foundation
import UIKit

class HighlightTextView : UITextView {
 
    private var gesture: UIPanGestureRecognizer!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        // Note handlePan(_:) is used internally and setting an IBAction with that name will disable scrolling
        gesture = UIPanGestureRecognizer(target: self, action: #selector(handleHighlightPan(_:)))
        gesture.maximumNumberOfTouches = 1
        gesture.minimumNumberOfTouches = 1
        gesture.delaysTouchesBegan = true
        // Allow scroll to cancel highlight gesture
        //gesture.require(toFail: panGestureRecognizer)
        //panGestureRecognizer.requiresExclusiveTouchType = false
        
        addGestureRecognizer(gesture)
        
        let interlineStyle = NSMutableParagraphStyle()
        //interlineStyle.lineSpacing = 20
        let interlineAttributedString = NSMutableAttributedString(string: text, attributes: [NSAttributedString.Key.paragraphStyle: interlineStyle])
        
        //textContainerInset = .zero
        
        //attributedText = interlineAttributedString
        
        layer.borderWidth = 1
        layer.borderColor = UIColor.green.cgColor
    }
    
    private var startingPoint: UITextPosition?
    private var currentPoint: UITextPosition?
    
    private var highlights: [Highlight] = []
    
    private var currentHighlight: Highlight? {
        didSet {
            setNeedsDisplay()
        }
    }
    
    class Highlight {
        internal init(startPosition: UITextPosition, endPosition: UITextPosition, textRange: UITextRange, rects: [CGRect], color: UIColor, cornerRadius: CGFloat) {
            self.startPosition = startPosition
            self.endPosition = endPosition
            self.textRange = textRange
            self.rects = rects
            self.color = color
            self.cornerRadius = cornerRadius
        }
        
        
        let startPosition: UITextPosition
        let endPosition: UITextPosition
        
        let textRange: UITextRange
        
        var rects: [CGRect]
        
        let color: UIColor
        
        let cornerRadius: CGFloat
    }
    
    @IBAction func handleHighlightPan(_ gestureRecognizer: UIPanGestureRecognizer) {
        let location = gesture.location(in: self)
        
        if gestureRecognizer.state == .began {

            startingPoint = closestPosition(to: location)
            currentPoint = startingPoint
        } else if gestureRecognizer.state == .changed {
            currentPoint = closestPosition(to: location)
        } else if gesture.state == .ended || gesture.state == .cancelled {
            startingPoint = nil
            currentPoint = nil
            
            if let currentHighlight = currentHighlight {
                highlights.append(currentHighlight)
                self.currentHighlight = nil
            }
        }
        
        if let start = startingPoint, let current = currentPoint {
            if let range = textRange(from: start, to: current) {
                
                
                currentHighlight = Highlight(
                    startPosition: start,
                    endPosition: current,
                    textRange: range,
                    rects: lineRectsFor(range: range),
                    color: UIColor.yellow.withAlphaComponent(0.9),
                    cornerRadius: 8)
            } else {
                print("range failed")
            }
        }
    }
    
    override var bounds: CGRect {
        didSet {
            if oldValue != bounds && !bounds.isEmpty {
                for highlight in highlights {
                    highlight.rects = lineRectsFor(range: highlight.textRange)
                }
                setNeedsDisplay()
            }
        }
    }
    
    public override func draw(_ frame: CGRect) {
        super.draw(frame)
        
        for highlight in highlights {
            HighlightTextView.draw(highlight)
        }
        
        if let current = currentHighlight {
            HighlightTextView.draw(current)
        }
    }
    
    private static func draw(_ highlight: Highlight) {
        let firstLine = highlight.rects.first
        let lastLine = highlight.rects.last
        
        highlight.color.set()
        
        for rect in highlight.rects {
            let path = UIBezierPath(
                roundedRect: rect,
                byRoundingCorners: cornerFor(rect, firstLine!, lastLine!),
                cornerRadii: CGSize(width: highlight.cornerRadius, height: highlight.cornerRadius))
            
            //c.setShadow(offset: CGSize(width: 0, height: 1), blur: 1, color: UIColor.black.withAlphaComponent(0.05).cgColor)
            path.fill()
        }
        
    }
    
    private static func cornerFor(_ lineRect: CGRect, _ firstLineRect: CGRect, _ lastLineRect: CGRect) -> UIRectCorner {
        switch (lineRect, lineRect) {
        case (firstLineRect, lastLineRect): return .allCorners
        case (firstLineRect, _): return [.topLeft, .bottomLeft]
        case (_, lastLineRect): return [.topRight, .bottomRight]
        default: return []
        }
    }
}

extension UITextView {
    
    func lineRectsFor(range: UITextRange) -> [CGRect] {
        
        var rects: [CGRect] = []
        
        // enumerateEnclosingRects returns rects that do not take into consideration this inset
        // https://stackoverflow.com/a/28332722
        let containerInsets = textContainerInset
        
        let heightChange: CGFloat = -4
        let lineHorizontalPadding:CGFloat = 4
        
        let fullRange = toNSRange(range)
        
        layoutManager.enumerateLineFragments(
            forGlyphRange: fullRange,
            using: { (rect, usedRect, textContainer, glyphRange, Bool) in
                // Each line needs to get a fresh rect again on the line's glyphs range
                // This is due to enumerateEnclosingRects returning combined line rects and thus we can not render line spacing for background color
                let refinedLineRect = self.layoutManager.boundingRect(
                    // Intersect so the last rect is to the range we passed in and not the full line rect
                    forGlyphRange: glyphRange.intersection(fullRange) ?? glyphRange,
                    in: self.textContainer)
                
                let finalRect = CGRect(
                    x: refinedLineRect.minX + containerInsets.left - (lineHorizontalPadding/2),
                    y: refinedLineRect.minY + containerInsets.top - (heightChange/2),
                    width: refinedLineRect.width - containerInsets.right + lineHorizontalPadding,
                    height: refinedLineRect.height + heightChange)
                
                rects.append(finalRect)
            })
        
        return rects
    }
    
}

extension UITextInput {
    
    func toNSRange(_ range: UITextRange) -> NSRange {
        let location = offset(from: beginningOfDocument, to: range.start)
        let length = offset(from: range.start, to: range.end)
        return NSRange(location: location, length: length)
    }
    
    func toTextRange(_ range: NSRange) -> UITextRange? {
        if let rangeStart = position(from: beginningOfDocument, offset: range.location),
           let rangeEnd = position(from: rangeStart, offset: range.length) {
            return textRange(from: rangeStart, to: rangeEnd)
        }
        return nil
    }
}
