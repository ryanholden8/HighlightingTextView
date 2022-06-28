//
//  ViewController.swift
//  HighlightTextView
//
//  Created by Ryan Holden on 9/6/21.
//

import UIKit
import HighlightingTextView

class ViewController: UIViewController {

    @IBOutlet var textView: HighlightTextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let frame = CGRect(x: 0, y: 200, width: 400, height: 300)
        
        textView.textContainer.exclusionPaths = [
            UIBezierPath(rect: frame)
        ]
        textView.tag = 11
        
        let highlightTextView = HighlightTextView(frame: frame)
        
        highlightTextView.text = "Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo. Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit aut fugit"
        
        highlightTextView.backgroundColor = .red
        highlightTextView.font = UIFont.systemFont(ofSize: 16)
        highlightTextView.tag = 33
        highlightTextView.isScrollEnabled = false
        highlightTextView.isEditable = false
        
        let highlightTextViewExcludeFrame = CGRect(x: 0, y: 100, width: 400, height: 200)
        
        highlightTextView.textContainer.exclusionPaths = [
            UIBezierPath(rect: highlightTextViewExcludeFrame)
        ]
        
        
        let highlightTextView2 = HighlightTextView(frame: frame)
        
        highlightTextView2.text = "Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo."
        
        highlightTextView2.backgroundColor = .gray
        highlightTextView2.font = UIFont.systemFont(ofSize: 16)
        highlightTextView2.tag = 55
        highlightTextView2.isScrollEnabled = false
        highlightTextView2.isEditable = false
        
        highlightTextView2.frame = highlightTextViewExcludeFrame
        
        highlightTextView.addSubview(highlightTextView2)
        
        
        textView.addSubview(highlightTextView)
    }


}

