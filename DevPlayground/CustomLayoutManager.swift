//
//  CustomLayoutManager.swift
//  HighlightTextView
//
//  Created by Ryan Holden on 9/10/21.
//

import Foundation
import UIKit

class CustomLayoutManager : NSLayoutManager {
    
    
    override func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
        super.drawBackground(forGlyphRange: glyphsToShow, at: origin)
        
        UIColor.purple.setFill()
        
        
        enumerateLineFragments(forGlyphRange: glyphsToShow) { (rect, usedRect, textContainer, glyphRange, Bool) in
            
            
            UIBezierPath(rect: usedRect).fill()
        }}
    
    override func fillBackgroundRectArray(_ rectArray: UnsafePointer<CGRect>, count rectCount: Int, forCharacterRange charRange: NSRange, color: UIColor) {
        super.fillBackgroundRectArray(rectArray, count: rectCount, forCharacterRange: charRange, color: UIColor.red)
    }
}
