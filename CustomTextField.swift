import UIKit

protocol CustomTextFieldProtocol : AnyObject{
    func changeFocus()
}

class CustomInputView: UIView {
    // MARK: - Properties
    private var text: String = "" {
        didSet {
            setNeedsDisplay()
            _ = updateCursor()
        }
    }
    private var cursorPosition: Int = 0 {
        didSet {
            _ = updateCursor()
        }
    }
    private var cursorLayer: CALayer!
    private var cursorTimer: Timer?
    private var isCursorVisible: Bool = false
    private var contentOffset: CGFloat = 0 {
        didSet {
            setNeedsDisplay()
        }
    }
    
    var selectedRange: NSRange? {
        didSet {
            setNeedsDisplay()
        }
    }
    
    private var singleTapRecognizer: UITapGestureRecognizer!
    private var doubleTapRecognizer: UITapGestureRecognizer!
    private var tripleTapRecognizer: UITapGestureRecognizer!
    private var panRecognizer: UIPanGestureRecognizer!
    private var longPressRecognizer: UILongPressGestureRecognizer!
    var fontSize: CGFloat = 20
    weak var delegate: CustomTextFieldProtocol?
    private var pasteSuggestionPopup: CustomPopupView?
    private var isAnimatingPopup = false
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
        setupGestureRecognizers()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
        setupGestureRecognizers()
    }
    
    // MARK: - Setup
    private func setup() {
        isUserInteractionEnabled = true
        backgroundColor = .white
        
        // Setup cursor
        cursorLayer = CALayer()
        cursorLayer.backgroundColor = UIColor(named: "Cursor")?.cgColor
        layer.addSublayer(cursorLayer)
    }
    
    // MARK: - Layout
    override func layoutSubviews() {
        super.layoutSubviews()
        _ = updateCursor()
    }
}
    
// MARK: - Cursor Management
extension CustomInputView{
    private func updateCursor() -> Int {
        guard Thread.isMainThread else {
            return DispatchQueue.main.sync { self.updateCursor() }
        }
        let font = UIFont.systemFont(ofSize: fontSize)
        let textBeforeCursor = String(text.prefix(cursorPosition))
        let textSize = textBeforeCursor.size(withAttributes: [.font: font])
        let cursorX = textSize.width
        let totalTextWidth = text.size(withAttributes: [.font: font]).width
        let viewWidth = bounds.width
        var newOffset = contentOffset
        
        // Calculate desired offset to keep cursor visible.
        let cursorInViewX = cursorX - newOffset
        if cursorInViewX < 0 {
            newOffset = cursorX
        } else if cursorInViewX > viewWidth {
            newOffset = cursorX - viewWidth + 2 // +2 for padding.
        }
        
        // Clamp the offset.
        newOffset = max(0, min(newOffset, max(totalTextWidth - viewWidth, 0)))
        if newOffset != contentOffset {
            contentOffset = newOffset
        }
        
        // Update the cursor frame without animation.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let cursorLayerX = cursorX - contentOffset
        cursorLayer.frame = CGRect(
            x: cursorLayerX,
            y: (bounds.height - font.lineHeight) / 2,
            width: 2,
            height: font.lineHeight
        )
        CATransaction.commit()
        
        // Only start blinking if no selection is active.
        if selectedRange == nil {
            startCursorBlink()
        } else {
            // Hide cursor if selection exists.
            cursorLayer.isHidden = true
        }
        
        return 1
    }
    
    private func startCursorBlink() {
        cursorTimer?.invalidate()
        cursorLayer.isHidden = false
        isCursorVisible = true
        cursorTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.isCursorVisible.toggle()
            self.cursorLayer.isHidden = !self.isCursorVisible
        }
    }
    
    private func stopCursorBlink() {
        cursorTimer?.invalidate()
        cursorTimer = nil
    }
    
    private func hideCursor() {
        stopCursorBlink()
        cursorLayer.isHidden = true
    }
    
    private func showCursor() {
        cursorLayer.isHidden = false
        isCursorVisible = true
        startCursorBlink()
    }
    
    /// Shift the cursor to the specified point.
    /// If the tap is beyond the drawn text, the cursor is placed at the end (or 0 if empty).
    private func shiftCursor(to point: CGPoint) {
        // Adjust the x-coordinate to account for any horizontal scrolling.
        let adjustedX = point.x + contentOffset
        let font = UIFont.systemFont(ofSize: fontSize)
        
        // Calculate the total width of the drawn text.
        let textSize = text.size(withAttributes: [.font: font])
        
        // If the tap is beyond the drawn text width, place the cursor at the end.
        if adjustedX > textSize.width {
            cursorPosition = text.count
            print("Cursor moved to position: \(cursorPosition) (end of text)")
            return
        }
        
        // Create an attributed string with our current text.
        let attributedString = NSAttributedString(string: text, attributes: [.font: font])
        let textStorage = NSTextStorage(attributedString: attributedString)
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        
        // Create a text container with an effectively infinite width.
        let textContainer = NSTextContainer(size: CGSize(width: CGFloat.greatestFiniteMagnitude, height: font.lineHeight))
        layoutManager.addTextContainer(textContainer)
        
        // Ask the layout manager for the character index closest to our tap.
        var index = layoutManager.characterIndex(
            for: CGPoint(x: adjustedX, y: font.lineHeight / 2),
            in: textContainer,
            fractionOfDistanceBetweenInsertionPoints: nil
        )
        
        // Clamp the index: if our tap was beyond our text,
        // we want the cursor to go to the end.
        if index > text.count {
            index = text.count
        }
        
        cursorPosition = index
        //        pasteSuggestion(at: point)
        print("Cursor moved to position: \(cursorPosition)")
    }
}

// MARK: - Inputs
extension CustomInputView: UIKeyInput {
    var hasText: Bool {
        return !text.isEmpty
    }
    
    func insertText(_ textToInsert: String) {
        removePasteSuggestionPopup()
        
        if let range = selectedRange {
            // Replace the selected text with the new text.
            let startIndex = text.index(text.startIndex, offsetBy: range.location)
            let endIndex = text.index(startIndex, offsetBy: range.length)
            text.replaceSubrange(startIndex..<endIndex, with: textToInsert)
            
            // Move the cursor to the end of the inserted text.
            cursorPosition = range.location + textToInsert.count
            
            // Clear the selection.
            selectedRange = nil
        } else {
            // No selection: insert at the cursor.
            let insertPosition = text.index(text.startIndex, offsetBy: cursorPosition)
            text.insert(contentsOf: textToInsert, at: insertPosition)
            cursorPosition += textToInsert.count
        }
        
        // Update cursor instantly.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        _ = updateCursor()
        CATransaction.commit()
        
        setNeedsDisplay()
        
        // If there's no selection, restart the blinking cursor.
        if selectedRange == nil {
            showCursor()
        }
    }
    
    func deleteBackward() {
        removePasteSuggestionPopup()
        
        if let range = selectedRange {
            // Remove the entire selected range.
            let startIndex = text.index(text.startIndex, offsetBy: range.location)
            let endIndex = text.index(startIndex, offsetBy: range.length)
            text.removeSubrange(startIndex..<endIndex)
            
            // Place the cursor at the beginning of the selection.
            cursorPosition = range.location
            
            // Clear the selection.
            selectedRange = nil
        } else {
            // No active selection, so delete a single character.
            guard cursorPosition > 0, !text.isEmpty else { return }
            let deleteIndex = text.index(text.startIndex, offsetBy: cursorPosition - 1)
            text.remove(at: deleteIndex)
            cursorPosition -= 1
        }
        
        // Update the cursor instantly.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        _ = updateCursor()
        CATransaction.commit()
        
        setNeedsDisplay()
        layoutIfNeeded()
        
        // Restart the cursor blinking when there is no active selection.
        if selectedRange == nil {
            showCursor()
        }
    }
}

// MARK: - Gesture Callbacks
extension CustomInputView {
    // MARK: - Gesture Recognizers Setup
    private func setupGestureRecognizers() {
        tripleTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTripleTap(_:)))
        tripleTapRecognizer.numberOfTapsRequired = 3
        addGestureRecognizer(tripleTapRecognizer)
        
        doubleTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTapRecognizer.numberOfTapsRequired = 2
        doubleTapRecognizer.require(toFail: tripleTapRecognizer)
        addGestureRecognizer(doubleTapRecognizer)
        
        longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        addGestureRecognizer(longPressRecognizer)
        
        singleTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap(_:)))
        singleTapRecognizer.numberOfTapsRequired = 1
        singleTapRecognizer.require(toFail: doubleTapRecognizer)
        singleTapRecognizer.require(toFail: tripleTapRecognizer)
        singleTapRecognizer.require(toFail: longPressRecognizer) // Add this line
        addGestureRecognizer(singleTapRecognizer)
        
        panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(panRecognizer)
    }
    
    /// Single Tap Handler – Moves the cursor to the tap location.
    @objc private func handleSingleTap(_ gesture: UITapGestureRecognizer) {
        print("Single tap recognized")
        let location = gesture.location(in: self)
        
        delegate?.changeFocus()
        removePasteSuggestionPopup()
        
        // 1. If tap is on the cursor, run paste suggestion.
        if cursorLayer.frame.insetBy(dx: -5, dy: -5).contains(location) {
            pasteSuggestion(at: location)
            return
        }
        
        // 2. Always shift the cursor to the tap location.
        shiftCursor(to: location)
        
        // 3. If text is not empty, decide whether to select a word.
        if !text.isEmpty {
            let font = UIFont.systemFont(ofSize: fontSize)
            let textSize = text.size(withAttributes: [.font: font])
            // If the tap is to the right of the drawn text, clear selection and show the cursor.
            if location.x + contentOffset > textSize.width {
                selectedRange = nil
                showCursor()
            } else if let index = characterIndex(at: location) {
                if index < text.count {
                    let tappedChar = text[text.index(text.startIndex, offsetBy: index)]
                    if tappedChar != " " {
                        // When tapping on a non-space character, select the word.
                        selectWord(at: location)
                        //                        pasteSuggestion(at: location)
                    } else {
                        // If a space is tapped, clear any previous selection and show the cursor.
                        pasteSuggestion(at: location)
                        selectedRange = nil
                        showCursor()
                    }
                } else {
                    // If the tap is beyond the text, clear any selection and show the cursor.
                    removePasteSuggestionPopup()
                    selectedRange = nil
                    showCursor()
                }
            }
        } else {
            // If there's no text, ensure the cursor is visible.
            pasteSuggestion(at: location)
            selectedRange = nil
            showCursor()
        }
    }
    
    /// Double Tap Handler – Moves the cursor to the tap location and then selects the word.
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: self)
        shiftCursor(to: location)
        selectWordDoubleTap(at: location)
    }
    
    /// Triple Tap Handler – Moves the cursor to the tap location and then selects all text.
    @objc private func handleTripleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: self)
        shiftCursor(to: location)
        pasteSuggestion(at: location)
        selectAll()
    }
    
    /// Pan Handler – Drag the cursor based on the pan gesture.
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        dragCursor(with: gesture)
    }
    
    /// Long Press Handler – Show the magnifying glass.
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        let location = gesture.location(in: self)
        if gesture.state == .began {
            showMagnifyingGlass(at: location)
        }
    }
}

// MARK: - Gesture Functionality Stubs
extension CustomInputView {
    private func selectWord(at point: CGPoint) {
        guard let tappedIndex = characterIndex(at: point), !text.isEmpty else { return }
        
        let nsText = text as NSString
        
        // Find the start of the word.
        pasteSuggestion(at: point)
        var wordStart = tappedIndex
        while wordStart > 0 {
            // Get the previous character.
            let previousChar = nsText.character(at: wordStart - 1)
            // If it's a whitespace or newline, stop.
            if Character(UnicodeScalar(previousChar)!).isWhitespace {
                break
            }
            wordStart -= 1
        }
        
        // Find the end of the word.
        var wordEnd = tappedIndex
        while wordEnd < nsText.length {
            let currentChar = nsText.character(at: wordEnd)
            if Character(UnicodeScalar(currentChar)!).isWhitespace {
                break
            }
            wordEnd += 1
        }
        
        // Create the range for the selected word.
        let wordRange = NSRange(location: wordStart, length: wordEnd - wordStart)
        selectedRange = wordRange
        
        print("Selected word range: \(wordRange)")
        isCursorVisible = false
    }
    
    private func pasteSuggestion(at point: CGPoint) {
        print("Paste suggestion at point: \(point)")
        
        // Don't create new popups if we're in the middle of animating
        guard !isAnimatingPopup else { return }
        
        // If there's already a popup being shown, remove it
        if pasteSuggestionPopup != nil {
            // Simply remove the existing popup without creating a new one
            removePasteSuggestionPopup()
            return
        }
        
        // Create and show the new popup
        createAndShowPopup(at: point)
    }
    
    private func createAndShowPopup(at point: CGPoint) {
        // Define the popup's desired size.
        let baseWidth: CGFloat = bounds.width * 0.8
        let popupWidth: CGFloat = baseWidth * 0.7
        let popupHeight: CGFloat = 60
        
        // Compute the text rectangle as used in your draw(_:) method.
        let font = UIFont.systemFont(ofSize: fontSize)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let textSize = text.size(withAttributes: attributes)
        let textRect = CGRect(
            x: -contentOffset,
            y: (bounds.height - font.lineHeight) / 2,
            width: max(bounds.width + contentOffset, textSize.width),
            height: font.lineHeight
        )
        
        // Position calculations
        var popupX: CGFloat = point.x - popupWidth / 2.0
        let margin: CGFloat = 8.0
        let screenWidth = UIScreen.main.bounds.width
        if popupX < margin {
            popupX = margin
        } else if popupX + popupWidth > screenWidth - margin {
            popupX = screenWidth - popupWidth - margin
        }
        
        let popupY: CGFloat = textRect.minY - popupHeight - 5
        let popupFrame = CGRect(x: popupX, y: popupY, width: popupWidth, height: popupHeight)
        let popup = CustomPopupView(frame: popupFrame)
        
        // Convert the touch point's x-coordinate to popup's coordinate space
        let arrowX = point.x - popupFrame.origin.x
        let arrowBasePoint = CGPoint(x: arrowX, y: popupFrame.height)
        popup.arrowPoint = arrowBasePoint
        
        // Set actions
        popup.cutAction = {
            print("Cut action triggered")
            // TODO: Add your cut functionality here.
        }
        popup.copyAction = {
            print("Copy action triggered")
            // TODO: Add your copy functionality here.
        }
        popup.pasteAction = {
            print("Paste action triggered")
            // TODO: Add your paste functionality here.
        }
        
        // Add the popup
        addSubview(popup)
        bringSubviewToFront(popup)
        pasteSuggestionPopup = popup
        
        // Animate the popup appearance
        popup.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        popup.alpha = 0
        
        UIView.animate(
            withDuration: 0.3,
            delay: 0,
            usingSpringWithDamping: 0.7,
            initialSpringVelocity: 0.5,
            options: .curveEaseOut,
            animations: {
                popup.transform = .identity
                popup.alpha = 1
            },
            completion: nil
        )
    }
    
    private func removePasteSuggestionPopup() {
        guard let popup = pasteSuggestionPopup else { return }
        
        // Set animating flag when starting removal
        isAnimatingPopup = true
        
        UIView.animate(
            withDuration: 0.2,
            delay: 0,
            options: .curveEaseIn,
            animations: {
                popup.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
                popup.alpha = 0
            },
            completion: { _ in
                popup.removeFromSuperview()
                self.pasteSuggestionPopup = nil
                // Reset animating flag after removal is complete
                self.isAnimatingPopup = false
            }
        )
    }
    
    @objc private func handleCut(_ sender: UIButton) {
        print("Cut selected")
        removePasteSuggestionPopup()
        // TODO: Implement actual cut logic using your text and UIPasteboard.
    }
    
    @objc private func handleCopy(_ sender: UIButton) {
        print("Copy selected")
        removePasteSuggestionPopup()
        // TODO: Implement actual copy logic using your text and UIPasteboard.
    }
    
    @objc private func handlePaste(_ sender: UIButton) {
        print("Paste selected")
        removePasteSuggestionPopup()
        // TODO: Implement actual paste logic using UIPasteboard and update your text.
    }
    
    private func selectAll() {
        selectedRange = NSRange(location: 0, length: text.count)
        
        setNeedsDisplay()
        
        print("Select All: Entire text is selected")
    }
    
    private func selectWordDoubleTap(at point: CGPoint) {
        guard let tappedIndex = characterIndex(at: point), !text.isEmpty else { return }
        
        let nsText = text as NSString
        let whitespace = CharacterSet.whitespacesAndNewlines
        
        // Find the start of the word.
        var start = tappedIndex
        while start > 0 {
            let prevChar = nsText.character(at: start - 1)
            if let scalar = UnicodeScalar(prevChar), whitespace.contains(scalar) {
                break
            }
            start -= 1
        }
        
        // Find the end of the word.
        var end = tappedIndex
        while end < nsText.length {
            let currentChar = nsText.character(at: end)
            if let scalar = UnicodeScalar(currentChar), whitespace.contains(scalar) {
                break
            }
            end += 1
        }
        
        selectedRange = NSRange(location: start, length: end - start)
        isCursorVisible = false  // Hide the cursor when text is selected.
        pasteSuggestion(at: point)
    }
    
    private func dragCursor(with gesture: UIPanGestureRecognizer) {
        if selectedRange != nil {
            return
        }
        
        removePasteSuggestionPopup()
        
        let location = gesture.location(in: self)
        
        switch gesture.state {
        case .began:
            hideCursor()
            //            showMagnifyingGlass(at: location)
        case .changed:
            shiftCursor(to: location)
            //            showMagnifyingGlass(at: location)
            gesture.setTranslation(.zero, in: self)
        case .ended, .cancelled:
            shiftCursor(to: location)
            showCursor()
            
        default:
            break
        }
    }
    
    private func showMagnifyingGlass(at point: CGPoint) {
        //        pasteSuggestion(at: point)
    }
}

// MARK: - Required Helper
extension CustomInputView {
    private func characterIndex(at point: CGPoint) -> Int? {
        let adjustedX = point.x + contentOffset
        let font = UIFont.systemFont(ofSize: fontSize)
        let attributedString = NSAttributedString(string: text, attributes: [.font: font])
        let textStorage = NSTextStorage(attributedString: attributedString)
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer(size: CGSize(width: CGFloat.greatestFiniteMagnitude, height: font.lineHeight))
        layoutManager.addTextContainer(textContainer)
        
        let index = layoutManager.characterIndex(
            for: CGPoint(x: adjustedX, y: font.lineHeight / 2),
            in: textContainer,
            fractionOfDistanceBetweenInsertionPoints: nil
        )
        return index
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        let font = UIFont.systemFont(ofSize: fontSize)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white
        ]
        
        // Calculate the text rectangle with contentOffset taken into account.
        let textSize = text.size(withAttributes: attributes)
        let textRect = CGRect(
            x: -contentOffset,
            y: (bounds.height - font.lineHeight) / 2,
            width: max(bounds.width + contentOffset, textSize.width),
            height: font.lineHeight
        )
        
        let attributedText = NSMutableAttributedString(string: text, attributes: attributes)
        
        if let range = selectedRange, range.location != NSNotFound, range.length > 0 {
            attributedText
                .addAttribute(
                    .backgroundColor,
                    value: UIColor(resource: .accent),
                    range: range
                )
            hideCursor()
        }
        
        attributedText.draw(in: textRect)
    }
}

// MARK: - UITextInputTraits
extension CustomInputView {
    override var textInputContextIdentifier: String? { "" } // For keyboard interaction
    var keyboardType: UIKeyboardType {
        get { .default }
        set { }
    }
}

// MARK: - Customisable Traits
extension CustomInputView {
    func changeTextSize(){
        
    }
    
    func returnText() -> String {
        if text.isEmpty{
            return  ""
        }else{
            return text
        }
    }
    
    func clearTextField(){
        selectedRange = NSRange(location: 0, length: text.count)
        deleteBackward()
    }
}
