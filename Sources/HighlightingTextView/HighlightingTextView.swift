//
//  HighlightTextView.swift
//  HighlightTextView
//
//  Created by Ryan Holden on 9/6/21.
//

import Foundation
import UIKit

public protocol HighlightingTextView : AnyObject {
    
    var highlightPanGesture: HighlightingTextViewPanGesture { get }
    
    var highlightTapGesture: UITapGestureRecognizer { get }
    
    var startingPoint: UITextPosition? { get set }
    var currentPoint: UITextPosition? { get set }
    
    var colorForNewHighlight: UIColor { get set }
    
    func menuActionsFor(menu: FanOutCircleMenu, highlight: TextHighlight) -> [UIView]
    
    var highlights: [TextHighlight] { get set }
    
    var currentHighlight: TextHighlight? { get set }
    
    var editingHighlight: TextHighlight? { get set }
}

public struct TextHighlight: Equatable {
    
    public init(nsRange: NSRange, rects: [CGRect], color: UIColor, cornerRadius: CGFloat) {
        self.nsRange = nsRange
        self.rects = rects
        self.color = color
        self.cornerRadius = cornerRadius
    }
    
    public var nsRange: NSRange
    
    public var rects: [CGRect]
    
    public var color: UIColor
    
    public var cornerRadius: CGFloat
    
    public func draw() {
        let firstLine = rects.first
        let lastLine = rects.last
        
        color.set()
        
        for rect in rects {
            let path = UIBezierPath(
                roundedRect: rect,
                byRoundingCorners: UIRectCorner(rect, firstLine!, lastLine!),
                cornerRadii: CGSize(width: cornerRadius, height: cornerRadius))
            
            //c.setShadow(offset: CGSize(width: 0, height: 1), blur: 1, color: UIColor.black.withAlphaComponent(0.05).cgColor)
            path.fill()
        }
        
    }
}

public class HighlightingTextViewPanGesture : UIPanGestureRecognizer {}

open class HighlightTextView : UITextView, UIGestureRecognizerDelegate, HighlightingTextView {
    public lazy var highlightPanGesture = HighlightingTextViewPanGesture(target: self, action: #selector(delegateHighlightPan(_:)))
    public lazy var highlightTapGesture = UITapGestureRecognizer(target: self, action: #selector(delegateHighlightTap(_:)))
    
    public var startingPoint: UITextPosition?
    public var currentPoint: UITextPosition?
    
    open var colorForNewHighlight: UIColor = UIColor.highlightTextViewYellow
    
    open func menuActionsFor(menu: FanOutCircleMenu, highlight: TextHighlight) -> [UIView] {
        [
            createHighlightUpdateFanOutMenuAction(menu, highlight.nsRange, newColor: .highlightTextViewYellow),
            createHighlightUpdateFanOutMenuAction(menu, highlight.nsRange, newColor: .random),
            createHighlightUpdateFanOutMenuAction(menu, highlight.nsRange, newColor: .random),
            createHighlightUpdateFanOutMenuAction(menu, highlight.nsRange, newColor: .random),
            createHighlightDeleteFanOutMenuAction(menu, highlight.nsRange)
        ]
    }
    
    open var highlights: [TextHighlight] = [] {
        didSet {
            setNeedsDisplay()
        }
    }
    
    open var currentHighlight: TextHighlight? {
        didSet {
            setNeedsDisplay()
        }
    }
    
    open var editingHighlight: TextHighlight? {
        didSet {
            setNeedsDisplay()
        }
    }
    
    public override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        
        attachHighlightGestures()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        attachHighlightGestures()
    }
    
    open override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        //print("SHOULD BEGIN: \(String(describing: type(of: gestureRecognizer)).prefix(15)): \(gestureRecognizerShouldBeginWithHighlightGesture(gestureRecognizer)) \(super.gestureRecognizerShouldBegin(gestureRecognizer))")
        return gestureRecognizerShouldBeginWithHighlightGesture(gestureRecognizer) ?? super.gestureRecognizerShouldBegin(gestureRecognizer)
    }
    
    open func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        //print("SHOULD SIMU: \(String(describing: type(of: gestureRecognizer)).prefix(15)) \(String(describing: type(of: otherGestureRecognizer)).prefix(15))")
        // do not allow scrolling while we highlight
        // We detect on type and instead of instance because we have nested HighlighingTextViews
        if otherGestureRecognizer is HighlightingTextViewPanGesture { return false }
        
        // Not sure if this is needed.. maybe cuts down on unwanted fan out menu popups?
        //if otherGestureRecognizer == highlightTapGesture {return false}
        
        // HighlighTapGesture and the default iOS long tap for select, lookup, copy, etc should work together
        return true
    }
    
    
    @IBAction func delegateHighlightPan(_ gestureRecognizer: UIPanGestureRecognizer) {
        handleHighlightPan(gestureRecognizer)
    }
    
    @IBAction func delegateHighlightTap(_ gestureRecognizer: UITapGestureRecognizer) {
        handleHighlightTap(gestureRecognizer)
    }
    
    open override var bounds: CGRect {
        didSet {
            // Did the view change? Is the view valid? Do we have highlights to draw?
            guard oldValue != bounds && !bounds.isEmpty && !highlights.isEmpty else {return}
            
            highlights.modifyForEach { _, highlight in
                highlight.rects = lineRectsFor(range: highlight.nsRange)
            }
            
            setNeedsDisplay()
        }
    }
    
    open override func draw(_ frame: CGRect) {
        super.draw(frame)
        
        for highlight in highlights {
            highlight.draw()
        }
        
        if let current = currentHighlight {
            current.draw()
        }
        
        if let editing = editingHighlight {
            editing.draw()
        }
    }
}

extension HighlightingTextView where Self : UITextView, Self : UIGestureRecognizerDelegate {
    
    func gestureRecognizerShouldBeginWithHighlightGesture(_ gestureRecognizer: UIGestureRecognizer) -> Bool? {
        guard gestureRecognizer == highlightPanGesture else {
            // We may have nested HighlightingTextViews
            // So if we are competing - we want to NOT began the parent highlighting gesture
            // otherwsie this may disable scrolling on parent views
            if gestureRecognizer is HighlightingTextViewPanGesture {
                return false
            }
            return nil
        }
        
        // If user is panning at all the menu should auto hide
        FanOutCircleMenu.currentInstance?.dismiss{}
        
        let velocity = highlightPanGesture.velocity(in: self)
        
        //print("TEST: \(velocity)")
        
        // Do not began the highlight gesture if our vertical velocity is larger than our horizontal velocity
        let isPanningMoreToSidewaysThanVertical = abs(velocity.y) < abs(velocity.x)
        
        // This is the part easy, we know the user is not scrolling up/down - so we can highlight
        if isPanningMoreToSidewaysThanVertical {
            return true
        }
        
        // Now for the harder part, there is an edge case where the user wants
        // to edit a highlight and pans directly down or up.
        // It's a bit fuzzy but if we know they are touching the start/end of highlight
        // and there velocity is not much, then we can edit the highlight instead of scroll/
        let location = gestureRecognizer.location(in: self)
        
        // User did not select an area with text.. return false to stop highlight process
        guard let charNsRange = characterNSRange(at: location, adjustToNearestNonWhiteSpace: true) else {return false}
        
        // User did not select a highlight, return false to allow scrolling to happen
        guard let editingHighlight = highlights.first(where: {$0.nsRange.overlaps(charNsRange)}) else {return false}
        
        let distanceFromStart = charNsRange.lowerBound - editingHighlight.nsRange.lowerBound
        let distanceFromEnd = editingHighlight.nsRange.upperBound - charNsRange.upperBound
        
        // We want to require more specific finger placement here than when we know it's from a sideways pan
        let isTouchingEditingPartsOfHighlight = distanceFromStart < 6 || distanceFromEnd < 6
        let isScrollingFast = abs(velocity.y) > 195 // This is the fuzzy part and is someone dependent on how the user chooses to scrolls
        
        print("Determined user might be trying to edit highlight. distanceFromStart: \(round(Double(distanceFromStart))) distanceFromEnd: \(round(Double(distanceFromEnd))) isScrollingFast: \(isScrollingFast) velocity: \(abs(round(Double(velocity.y))))")
        
        let allowEditHighlight = isTouchingEditingPartsOfHighlight && !isScrollingFast
        
        return allowEditHighlight
        
    }
    
    
    /// Creates highlightGesture and attaches to the view with itself as the delegate. Usually set in AwakeFromNib or other init.
    func attachHighlightGestures() {
        // Note handlePan(_:) is used internally and setting an IBAction with that name will disable scrolling
        highlightPanGesture.maximumNumberOfTouches = 1
        highlightPanGesture.minimumNumberOfTouches = 1
        highlightPanGesture.delaysTouchesBegan = true
        addGestureRecognizer(highlightPanGesture)
        
        highlightTapGesture.numberOfTapsRequired = 1
        // https://stackoverflow.com/a/28859225/2191796
        highlightTapGesture.delegate = self
        addGestureRecognizer(highlightTapGesture)
        
        // Allow scroll to cancel highlight gesture
        //gesture.require(toFail: panGestureRecognizer)
        //panGestureRecognizer.requiresExclusiveTouchType = false
        panGestureRecognizer.delegate = self
    }
    
    func handleNewHighlightStart(_ gestureRecognizer: UIPanGestureRecognizer, _ location: CGPoint) {
        //print("Start NEW highlight")
        startingPoint = closestPosition(to: location)
        currentPoint = startingPoint
        
        if let start = startingPoint,
           let current = currentPoint,
           let newNSRange = nsRangeFor(start: start, end: current) {
            let color = colorForNewHighlight
            currentHighlight = TextHighlight(
                nsRange: newNSRange,
                rects: lineRectsFor(range: newNSRange),
                color: color,
                cornerRadius: 6)
        }
    }
    
    func handleNewHighlightChanged(_ gestureRecognizer: UIPanGestureRecognizer, _ location: CGPoint) {
        currentPoint = closestPosition(to: location)
        
        if let start = startingPoint,
           let current = currentPoint,
           let newNSRange = nsRangeFor(start: start, end: current),
           var currentHighlight = currentHighlight {
            currentHighlight.nsRange = newNSRange
            currentHighlight.rects = lineRectsFor(range: currentHighlight.nsRange)
            
            self.currentHighlight = currentHighlight
        }
    }
    
    func handleNewHighlightEnd(_ gestureRecognizer: UIPanGestureRecognizer, _ location: CGPoint) {
        startingPoint = nil
        currentPoint = nil
        
        if let currentHighlight = currentHighlight {
            highlights.append(currentHighlight)
            self.currentHighlight = nil
        }
    }
    
    func handleEditHighlightStart(_ gestureRecognizer: UIPanGestureRecognizer, _ location: CGPoint, _ editingHighlight: TextHighlight) {
        //print("Start EDIT highlight")
        //startingPoint = closestPosition(to: location)
        self.editingHighlight = editingHighlight
        
        highlights.removeAll{$0 == editingHighlight}
    }
    
    func handleEditHighlightChanged(_ gestureRecognizer: UIPanGestureRecognizer, _ location: CGPoint) {
        guard let editingHighlight = editingHighlight else {
            return print("EditingHighlight is nil while attempting to edit")
        }

        currentPoint = closestPosition(to: location)
        
        if let start = startingPoint,
           let current = currentPoint,
           let newNSRange = nsRangeFor(start: start, end: current) {
            var editingHighlight = editingHighlight
            editingHighlight.nsRange = newNSRange
            editingHighlight.rects = lineRectsFor(range: editingHighlight.nsRange)
            
            self.editingHighlight = editingHighlight
        }
    }
    
    func handleEditHighlightEnd(_ gestureRecognizer: UIPanGestureRecognizer, _ location: CGPoint) {
        currentPoint = nil
        startingPoint = nil
        if let editingHighlight = editingHighlight {
            if editingHighlight.nsRange.length > 0 {
                highlights.append(editingHighlight)
            } else {
                print("Removing highlight. It was empty after finishing edit.")
            }
            self.editingHighlight = nil
        }
    }
}

extension UITextView {
    
    func characterNSRange(at location: CGPoint, adjustToNearestNonWhiteSpace: Bool) -> NSRange? {
        guard let charRange = characterRange(at: location) else {return nil}
        
        var charNsRange = toNSRange(charRange)
        
        // If whitespace, widen the range otherwise a new highlight is started unexpectedly
        let charString = attributedText.attributedSubstring(from: charNsRange).string.trimmingCharacters(in: .whitespaces)
        
        if charString.isEmpty {
            let charRect = firstRect(for: charRange)
            // Note: ranges might be null because it's whitespace before a new line or something
            let charRangeLeft = characterRange(at: CGPoint(x: location.x - charRect.width, y: location.y))
            let charRangeRight = characterRange(at: CGPoint(x: location.x + charRect.width, y: location.y))
            let charRangeLeftNsRange = charRangeLeft != nil ? toNSRange(charRangeLeft!) : charNsRange
            let charRangeRightNsRange = charRangeRight != nil ? toNSRange(charRangeRight!) : charNsRange
            
            charNsRange = charRangeLeftNsRange.union(charRangeRightNsRange)
            
            let newCharString = attributedText.attributedSubstring(from: charNsRange).string
            
            print("Whitespace selected on gesture start, adjusting range `\(newCharString)`")
        }
        
        return charNsRange
    }
    
}

extension HighlightingTextView where Self : UITextView, Self : UIGestureRecognizerDelegate {
    
    func handleHighlightPan(_ gestureRecognizer: UIPanGestureRecognizer) {
        let location = highlightPanGesture.location(in: self)
        
        switch (gestureRecognizer.state) {
        case .began:
            // Are there characters at this range?
            guard let charNsRange = characterNSRange(at: location, adjustToNearestNonWhiteSpace: true) else {
                print("No characters found at gesture pan beginning. Aborting highlight.")
                return gestureRecognizer.state = .cancelled
            }
            
            let touchLocation = gestureRecognizer.location(in: self)
            
            let isTouchInAnExclusionPath = textContainer.exclusionPaths.contains{$0.bounds.contains(touchLocation)}
            
            if isTouchInAnExclusionPath {
                print("ExclusionPath detected at start of highlight. Aborting highlight.")
                return gestureRecognizer.state = .cancelled
            }
            
            // Start a new highlight only when we are not editing an existing one
            guard let editingHighlight = highlights.first(where: {$0.nsRange.overlaps(charNsRange)}) else {
                return handleNewHighlightStart(gestureRecognizer, location)
            }
            
            // Never expected
            guard let range = toTextRange(editingHighlight.nsRange) else {
                print("Failed to get textRange for editingHighlight: \(editingHighlight)")
                return gestureRecognizer.state = .cancelled
            }
            
            let distanceFromStart = charNsRange.lowerBound - editingHighlight.nsRange.lowerBound
            let distanceFromEnd = editingHighlight.nsRange.upperBound - charNsRange.upperBound
            
            let closeDistanceToEnds = 12
            
            if closeDistanceToEnds > editingHighlight.nsRange.length {
                // User is editing small highlight
                startingPoint = gestureRecognizer.velocity(in: self).x > 0
                    ? closestPosition(to: CGPoint.zero, within: range)
                    : closestPosition(to: CGPoint.init(x: CGFloat.greatestFiniteMagnitude, y: CGFloat.greatestFiniteMagnitude), within: range)
            } else if distanceFromStart < closeDistanceToEnds {
                // User is editing the beginning of the highlight
                startingPoint = closestPosition(to: CGPoint.init(x: CGFloat.greatestFiniteMagnitude, y: CGFloat.greatestFiniteMagnitude), within: range)
            } else if distanceFromEnd < closeDistanceToEnds {
                // User is editing the end of the highlight
                startingPoint = closestPosition(to: CGPoint.zero, within: range)
            } else {
                print("Attempting to edit highlight by dragging over the middle. Aborting edit.")
                gestureRecognizer.state = .cancelled
            }
            
            //print("Distance: Start: \(distanceFromStart) | End: \(distanceFromEnd)")
            
            if startingPoint != nil {
                handleEditHighlightStart(gestureRecognizer, location, editingHighlight)
            }
        case .changed:
            if currentHighlight != nil {
                handleNewHighlightChanged(gestureRecognizer, location)
            } else {
                handleEditHighlightChanged(gestureRecognizer, location)
            }
        case .ended, .cancelled, .failed:
            if currentHighlight != nil {
                handleNewHighlightEnd(gestureRecognizer, location)
            } else {
                handleEditHighlightEnd(gestureRecognizer, location)
            }
        default:break
        }
    }
    
    func handleHighlightTap(_ gestureRecognizer: UITapGestureRecognizer) {
        var location = highlightTapGesture.location(in: self)
        
        switch (gestureRecognizer.state) {
        case .ended:
            guard let window = window else {return}
            // We never want to switch to another highlight menu if another is already showing
            guard FanOutCircleMenu.currentInstance == nil else {
                FanOutCircleMenu.currentInstance?.dismiss{}
                return
            }
            
            guard let charNsRange = characterNSRange(at: location, adjustToNearestNonWhiteSpace: true) else {return}
            
            guard let editingHighlight = highlights.first(where: {$0.nsRange.overlaps(charNsRange)}) else {return}
            
            let isSelectedRangeInsideUserTap = selectedRange.length > 0 && selectedRange.overlaps(charNsRange)
            
            guard !isSelectedRangeInsideUserTap else {
                return print("Tap detected while using iOS text selection. Aborting highlight menu.")
            }
            
            let menu = FanOutCircleMenu()
            
            let actions = menuActionsFor(menu: menu, highlight: editingHighlight)
            
            guard !actions.isEmpty else {
                return print("No actions provided for highlight at range: \(editingHighlight.nsRange). Aborting highlight menu.")
            }
            
            // To make it feel a little more center (since you usually move your finger a little downward aftering a tap)
            location.y += 10
            
            menu.showOnWindow(window, anchoredView: self, center: location)
            
            menu.show(actions)
        default:break
        }
    }
    
    public func createHighlightUpdateFanOutMenuAction(_ menu: FanOutCircleMenu, _ highlightAtRange: NSRange, newColor: UIColor) -> UIButton {
        return menu.createAction(systemName: "circle.fill", pointSize: 36, tintColor: newColor) {[weak self] _ in
            self?.changeHighlightColor(highlightAtRange, newColor: newColor)
            FanOutCircleMenu.currentInstance?.dismiss{}
        }
    }
    
    public func createHighlightDeleteFanOutMenuAction(_ menu: FanOutCircleMenu, _ highlightAtRange: NSRange) -> UIButton {
        return menu.createAction(systemName: "trash.circle.fill", pointSize: 36, tintColor: .white, backgroundColor: .black) {[weak self, weak menu] button in
            guard let menu = menu else {return}
            
            menu.confirm(
                actionView: button,
                confirmActionView: menu.createAction(
                    systemName: "checkmark.circle.fill",
                    pointSize: 36,
                    tintColor: .systemRed,
                    backgroundColor: .black) {[weak self] _ in
                        self?.removeHighlight(highlightAtRange)
                        FanOutCircleMenu.currentInstance?.dismiss{}
                })
        }
    }
    
    public func changeHighlightColor(_ highlightAtRange: NSRange, newColor: UIColor) {
        guard var updatedHighlight = highlights.first(where: {$0.nsRange == highlightAtRange}) else {return}
        
        updatedHighlight.color = newColor
        
        removeHighlight(highlightAtRange)
        highlights.append(updatedHighlight)
        
        // Seems reasonable this should be the new default
        colorForNewHighlight = newColor
    }
    
    public func removeHighlight(_ highlightAtRange: NSRange) {
        highlights.removeAll{$0.nsRange == highlightAtRange}
    }
}

public class FanOutCircleMenu : UIView {
    
    public static var currentInstance: FanOutCircleMenu?
    
    private var actionConstraints: [(UIView, NSLayoutConstraint, NSLayoutConstraint)] = []
    private var confirmActionConstraints: [(UIView, [NSLayoutConstraint])] = []
    
    private let radius: CGFloat = 60
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        
        // If the user does not tap any button but the back view (which is invisible) then we should dismiss the menu
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tappedOnMenuBackView)))
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    @IBAction func tappedOnMenuBackView() {
        FanOutCircleMenu.currentInstance?.dismiss {}
    }
    
    public func show(_ actions: [UIView]) {
        // Remove all old actions
        subviews.forEach{$0.removeFromSuperview()}
        
        let circlePath = UIBezierPath(arcCenter: center, radius: radius, startAngle: .pi, endAngle: 7, clockwise: true)
        
        // circleLayer is only used to locate the circle animation path
        let circleLayer = CAShapeLayer()
        circleLayer.path = circlePath.cgPath
        circleLayer.strokeColor = UIColor.black.cgColor
        circleLayer.fillColor = UIColor.clear.cgColor
        circleLayer.lineWidth = 40
        //layer.addSublayer(circleLayer)
        
        // Add all actions
        actions.enumerated().forEach { (index, actionView) in
            // Add action to view
            actionView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(actionView)
            
            // Center action to parent center
            let yAnchor = actionView.centerYAnchor.constraint(equalTo: centerYAnchor)
            let xAnchor = actionView.centerXAnchor.constraint(equalTo: centerXAnchor)
            // Save our constraints so we can revert them in our dismiss animation
            actionConstraints.append((actionView, xAnchor, yAnchor))
            addConstraints([xAnchor, yAnchor])
            
            // Calculate coordinates for action to land on cirlce path
            // https://stackoverflow.com/a/60281640/2191796
            let angle: CGFloat = 9.5 + CGFloat(index) * 0.9
            let x = cos(angle) * radius
            let y = sin(angle) * radius
            
            // Animate
            actionView.alpha = 0
            layoutIfNeeded()
            
            animateWithSpring(delay: Double(index) * 0.05) {
                actionView.alpha = 1
                xAnchor.constant = x
                yAnchor.constant = y
                
                // Animate contraint changes
                self.layoutIfNeeded()
            }
        }
    }
    
    public func showOnWindow(_ window: UIWindow, anchoredView: UIView, center: CGPoint) {
        let center = anchoredView.convert(center, to: window)
        translatesAutoresizingMaskIntoConstraints = false
        window.addSubview(self)
        
        
        let centerX = centerXAnchor.constraint(equalTo: window.leadingAnchor, constant: center.x)
        let centerY = centerYAnchor.constraint(equalTo: window.topAnchor, constant: center.y)
        
        centerX.priority = .required - 1
        centerY.priority = .required - 1
        
        window.addConstraints([
            centerX,
            centerY,
            widthAnchor.constraint(equalToConstant: radius * 2.6),
            heightAnchor.constraint(equalToConstant: radius * 2.6),
            leadingAnchor.constraint(greaterThanOrEqualTo: window.leadingAnchor, constant: 0),
            window.trailingAnchor.constraint(greaterThanOrEqualTo: trailingAnchor, constant: 0),
            topAnchor.constraint(greaterThanOrEqualTo: window.topAnchor, constant: 0),
            window.bottomAnchor.constraint(greaterThanOrEqualTo: bottomAnchor, constant: 0)
        ])
        
        FanOutCircleMenu.currentInstance?.removeFromSuperview()
        FanOutCircleMenu.currentInstance = self
    }
    
    public func dismiss(completion: @escaping () -> ()) {
        
        let completion = {
            FanOutCircleMenu.currentInstance = nil
            self.removeFromSuperview()
            completion()
        }
        
        guard confirmActionConstraints.isEmpty else {
            animateWithSpring(duration: 0.35) {
                // Fade out confirmation action view
                self.confirmActionConstraints.forEach { (confirmActionView, constraints) in
                    confirmActionView.alpha = 0
                }
                
                // Move original action upward (which will also push up confirmation action view)
                self.actionConstraints.forEach { actionInfo in
                    let (actionView, _, yConstraint) = actionInfo
                    
                    actionView.alpha = 0
                    yConstraint.constant -= 20
                }
                
                // Animate contraint changes
                self.layoutIfNeeded()
            } completion: { _ in
                completion()
            }
            return
        }
        
        guard !actionConstraints.isEmpty else {
            completion()
            return
        }
        
        actionConstraints.enumerated().reversed().forEach { (index, actionInfo) in
            let (actionView, xConstraint, yConstraint) = actionInfo
            
            animateWithSpring(delay: Double(actionConstraints.count - index) * 0.05) {
                actionView.alpha = 0
                xConstraint.constant = 0
                yConstraint.constant = 0
                
                // Animate contraint changes
                self.layoutIfNeeded()
            } completion: { _ in
                if (index == 0) {
                    completion()
                }
            }
        }
    }
    
    private static let shadowColor = UIColor(dynamicProvider: { trait in
        if trait.userInterfaceStyle == .light {
            return UIColor.systemGray
        } else {
            return UIColor.black
        }
    })
    
    public func createAction(
        systemName: String,
        pointSize: CGFloat,
        tintColor: UIColor,
        backgroundColor: UIColor? = nil,
        action: @escaping (UIButton) -> ()
    ) -> UIButton {
        let config = UIImage.SymbolConfiguration(pointSize: pointSize)
        let image = UIImage(systemName: systemName, withConfiguration: config)!.withTintColor(tintColor)
        
        let button = UIButton(type: .custom)
        button.setImage(image.withRenderingMode(.alwaysOriginal), for: .normal)
        button.addAction(UIAction(handler: {_ in action(button) }), for: .primaryActionTriggered)
        if let imageView = button.imageView, let backgroundColor = backgroundColor {
            imageView.backgroundColor = backgroundColor
            imageView.layer.cornerRadius = image.size.width/2
            imageView.layer.masksToBounds = true
        }
        button.layer.shadowColor = FanOutCircleMenu.shadowColor.cgColor
        button.layer.shadowOpacity = 1
        button.layer.shadowOffset = CGSize(width: 0.5, height: 1)
        button.layer.shadowRadius = 3
        button.sizeToFit()
        
        return button
    }
    
    public func confirm(
        actionView: UIView,
        confirmActionView: UIView
    ) {
        // Display the confirmation above the original action view that needs confirmation
        confirmActionView.translatesAutoresizingMaskIntoConstraints = false
        confirmActionView.alpha = 0
        addSubview(confirmActionView)
        confirmActionView.centerXAnchor.constraint(equalTo: actionView.centerXAnchor).isActive = true
        let bottomAnchor = confirmActionView.bottomAnchor.constraint(equalTo: actionView.topAnchor, constant: actionView.frame.height)
        bottomAnchor.isActive = true
        
        confirmActionConstraints.append((confirmActionView, [bottomAnchor]))
        
        layoutIfNeeded()
        
        // Remove all other views
        UIView.animate(withDuration: 0.2) {
            self.subviews.forEach { view in
                guard view != actionView else {return}
                view.alpha = 0
            }
        }
        
        // Show confirmation view
        animateWithSpring {
            confirmActionView.alpha = 1
            bottomAnchor.constant = -20
            
            // Animate contraint changes
            self.layoutIfNeeded()
        }
    }
    
    private func animateWithSpring(duration: TimeInterval = 0.25, delay: TimeInterval = 0, animations: @escaping () -> (), completion: ((Bool) -> ())? = nil) {
        UIView.animate(
            withDuration: duration,
            delay: delay,
            usingSpringWithDamping: 0.5,
            initialSpringVelocity: 5,
            options: [.curveEaseInOut, .allowUserInteraction],
            animations: animations,
            completion: completion)
    }
    
}

extension UIRectCorner {
    init(_ lineRect: CGRect, _ firstLineRect: CGRect, _ lastLineRect: CGRect) {
        switch (lineRect, lineRect) {
        case (firstLineRect, lastLineRect): self.init(arrayLiteral: .allCorners)
        case (firstLineRect, _): self.init([.topLeft, .bottomLeft])
        case (_, lastLineRect): self.init([.topRight, .bottomRight])
        default: self.init()
        }
    }
}

extension UITextView {
    
    /// Not sure why the code below breaks layoutManager.enumerateLineFragments in this extension method below
    /// textContainer.replaceLayoutManager(customLayoutManager)
    func lineRectsFor(range: NSRange) -> [CGRect] {
        
        var rects: [CGRect] = []
        
        // enumerateEnclosingRects returns rects that do not take into consideration this inset
        // https://stackoverflow.com/a/28332722
        let containerInsets = textContainerInset
        
        let heightChange: CGFloat = -4
        let lineHorizontalPadding:CGFloat = 5
        
        layoutManager.enumerateLineFragments(
            forGlyphRange: range,
            using: { (rect, usedRect, textContainer, glyphRange, Bool) in
                // Each line needs to get a fresh rect again on the line's glyphs range
                // This is due to enumerateEnclosingRects returning combined line rects and thus we can not render line spacing for background color
                let refinedLineRect = self.layoutManager.boundingRect(
                    // Intersect so the last rect is to the range we passed in and not the full line rect
                    forGlyphRange: glyphRange.intersection(range) ?? glyphRange,
                    in: self.textContainer)
                
                let finalRect = CGRect(
                    x: refinedLineRect.minX + containerInsets.left - (lineHorizontalPadding/2),
                    y: refinedLineRect.minY + containerInsets.top - (heightChange/2),
                    width: refinedLineRect.width + lineHorizontalPadding,
                    height: refinedLineRect.height + heightChange)
                
                rects.append(finalRect)
            })
        
        return rects
    }
    
    func nsRangeFor(start: UITextPosition, end: UITextPosition, snapToWords: Bool = true) -> NSRange? {
        guard var narrowUITextRange = textRange(from: start, to: end) else {
            print("Failed to get UITextRange from \(start) - \(end)")
            return nil
        }
        
        // are we flipped?
        if narrowUITextRange.isEmpty {
            //print("nsRangeFor: flipped")
            if let flippedTextRange = textRange(from: end, to: start), !flippedTextRange.isEmpty {
                narrowUITextRange = flippedTextRange
                //print("nsRangeFor: update: \(narrowUITextRange.isEmpty)")
            }
        }
        
        if snapToWords {
            let startingRange = tokenizer.rangeEnclosingPosition(narrowUITextRange.start, with: .word, inDirection: UITextDirection.storage(.backward))
            // NOTE: Direction should be .backward otherwise .forward will cause the first word on the NEXT line when highlighting the LAST word on the previous line
            let endingRange = tokenizer.rangeEnclosingPosition(narrowUITextRange.end, with: .word, inDirection: UITextDirection.storage(.backward))
            
            
            return toNSRange(startRange: startingRange ?? narrowUITextRange, endRange: endingRange ?? narrowUITextRange)
        }
        
        return toNSRange(narrowUITextRange)
    }
    
}

extension UITextInput {
    
    func toNSRange(_ range: UITextRange) -> NSRange {
        let location = offset(from: beginningOfDocument, to: range.start)
        let length = offset(from: range.start, to: range.end)
        return NSRange(location: location, length: length)
    }
    
    func toNSRange(startRange: UITextRange, endRange: UITextRange) -> NSRange {
        var location = offset(from: beginningOfDocument, to: startRange.start)
        var length = offset(from: startRange.start, to: endRange.end)
        
        // In case the endRange flips and becomes the start range.
        // This happens when dragging from right to left
        if length <= 0 {
            location = offset(from: beginningOfDocument, to: endRange.start)
            length = offset(from: endRange.start, to: startRange.end)
        }
        
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

public extension NSRange {
    init?(string: String, lowerBound: String.Index, upperBound: String.Index) {
        let utf16 = string.utf16

        guard let lowerBound = lowerBound.samePosition(in: utf16) else {return nil}
        let location = utf16.distance(from: utf16.startIndex, to: lowerBound)
        
        guard let to = upperBound.samePosition(in: utf16) else {return nil}
        
        let length = utf16.distance(from: lowerBound, to: to)

        self.init(location: location, length: length)
    }

    init?(range: Range<String.Index>, in string: String) {
        self.init(string: string, lowerBound: range.lowerBound, upperBound: range.upperBound)
    }

    init?(range: ClosedRange<String.Index>, in string: String) {
        self.init(string: string, lowerBound: range.lowerBound, upperBound: range.upperBound)
    }
    
    func overlaps(_ other: NSRange) -> Bool {
        let thisRange = lowerBound ... upperBound
        let otherRange = other.lowerBound ... other.upperBound
        
        return thisRange.overlaps(otherRange)
    }
}

extension UIColor {
    
    private static let highlightYellowLight = UIColor(rgb: 0xfff176)
    private static let highlightYellowDark = UIColor(rgb: 0xcabf45)
    
    static let highlightTextViewYellow = UIColor.dynamicColor(light: highlightYellowLight, dark: highlightYellowDark)
    
    class var random: UIColor {
        return UIColor(red: .random(in: 0...1), green: .random(in: 0...1), blue: .random(in: 0...1), alpha: 1.0)
    }
    
   convenience init(red: Int, green: Int, blue: Int) {
       assert(red >= 0 && red <= 255, "Invalid red component")
       assert(green >= 0 && green <= 255, "Invalid green component")
       assert(blue >= 0 && blue <= 255, "Invalid blue component")

       self.init(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: 1.0)
   }

   convenience init(rgb: Int) {
       self.init(
           red: (rgb >> 16) & 0xFF,
           green: (rgb >> 8) & 0xFF,
           blue: rgb & 0xFF
       )
   }
    
    public class func dynamicColor(light: UIColor, dark: UIColor) -> UIColor {
          if #available(iOS 13.0, *) {
             return UIColor {
                switch $0.userInterfaceStyle {
                case .dark:
                   return dark
                default:
                   return light
                }
             }
          } else {
             return light
          }
       }
}

extension Array {
    mutating func modifyForEach(_ body: (_ index: Index, _ element: inout Element) -> ()) {
        for index in indices {
            modifyElement(atIndex: index) { body(index, &$0) }
        }
    }

    mutating func modifyElement(atIndex index: Index, _ modifyElement: (_ element: inout Element) -> ()) {
        var element = self[index]
        modifyElement(&element)
        self[index] = element
    }
}
