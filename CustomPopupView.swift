import UIKit
import Foundation

class CustomPopupView: UIView {
    
    /// The point (in the popup view’s coordinate system) where the arrow should point.
    var arrowPoint: CGPoint = .zero {
        didSet { setNeedsDisplay() }
    }
    
    /// The text to display on the popup (if desired). You can expand this later.
    var message: String?
    
    /// Optionally, you can have completion handlers for the actions.
    var cutAction: (() -> Void)?
    var copyAction: (() -> Void)?
    var pasteAction: (() -> Void)?
    
    /// Configure any default appearance.
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear  // We draw our own background.
        setupButtons()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .clear
        setupButtons()
    }
    
    // MARK: - Setup buttons
    private func setupButtons() {
        // Create three buttons and add them as subviews.
        let buttonTitles = ["Cut", "Copy", "Paste"]
        let buttonCount = buttonTitles.count
        let buttonWidth = self.bounds.width / CGFloat(buttonCount)
        let buttonHeight = self.bounds.height - 15  // leave room for the arrow
        
        for (index, title) in buttonTitles.enumerated() {
            let buttonFrame = CGRect(x: CGFloat(index) * buttonWidth,
                                     y: 0,
                                     width: buttonWidth,
                                     height: buttonHeight)
            let button = UIButton(frame: buttonFrame)
            button.setTitle(title, for: .normal)
            button.setTitleColor(.systemBlue, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 14)
            button.tag = index  // use tag to identify the button later
            button.addTarget(self, action: #selector(handleButtonTap(_:)), for: .touchUpInside)
            addSubview(button)
        }
    }
    
    @objc private func handleButtonTap(_ sender: UIButton) {
        // Remove the popup when a button is tapped.
        self.removeFromSuperview()
        switch sender.tag {
        case 0: // Cut
            print("Cut selected")
            cutAction?()
        case 1: // Copy
            print("Copy selected")
            copyAction?()
        case 2: // Paste
            print("Paste selected")
            pasteAction?()
        default:
            break
        }
    }
    
    // MARK: - Drawing the Bubble with an Arrow
    override func draw(_ rect: CGRect) {
        // Define some constants.
        let cornerRadius: CGFloat = 10.0
        let arrowWidth: CGFloat = 20.0
        let arrowHeight: CGFloat = 15.0
        
        // We want the bubble to be drawn in most of the view, with an arrow at the bottom.
        // Calculate the bubble rect (the main rounded rectangle) by subtracting the arrow height.
        let bubbleRect = CGRect(x: 0, y: 0, width: rect.width, height: rect.height - arrowHeight)
        
        // Create the path.
        let path = CGMutablePath()
        
        // Calculate where the arrow should appear horizontally.
        // Clamp the arrow x-position so it doesn't intrude into the rounded corners.
        var arrowX = arrowPoint.x
        arrowX = max(cornerRadius + arrowWidth/2, arrowX)
        arrowX = min(bubbleRect.maxX - cornerRadius - arrowWidth/2, arrowX)
        
        // Start at the top-left corner.
        path.move(to: CGPoint(x: bubbleRect.minX + cornerRadius, y: bubbleRect.minY))
        
        // Top edge.
        path.addLine(to: CGPoint(x: bubbleRect.maxX - cornerRadius, y: bubbleRect.minY))
        // Top-right corner.
        path.addArc(center: CGPoint(x: bubbleRect.maxX - cornerRadius, y: bubbleRect.minY + cornerRadius),
                    radius: cornerRadius,
                    startAngle: CGFloat(3 * Double.pi/2),
                    endAngle: 0,
                    clockwise: false)
        
        // Right edge.
        path.addLine(to: CGPoint(x: bubbleRect.maxX, y: bubbleRect.maxY - cornerRadius))
        // Bottom-right corner.
        path.addArc(center: CGPoint(x: bubbleRect.maxX - cornerRadius, y: bubbleRect.maxY - cornerRadius),
                    radius: cornerRadius,
                    startAngle: 0,
                    endAngle: CGFloat(Double.pi/2),
                    clockwise: false)
        
        // Bottom edge before the arrow.
        path.addLine(to: CGPoint(x: arrowX + arrowWidth/2, y: bubbleRect.maxY))
        // Draw arrow.
        path.addLine(to: CGPoint(x: arrowX, y: bubbleRect.maxY + arrowHeight))
        path.addLine(to: CGPoint(x: arrowX - arrowWidth/2, y: bubbleRect.maxY))
        
        // Continue along the bottom edge.
        path.addLine(to: CGPoint(x: bubbleRect.minX + cornerRadius, y: bubbleRect.maxY))
        // Bottom-left corner.
        path.addArc(center: CGPoint(x: bubbleRect.minX + cornerRadius, y: bubbleRect.maxY - cornerRadius),
                    radius: cornerRadius,
                    startAngle: CGFloat(Double.pi/2),
                    endAngle: CGFloat(Double.pi),
                    clockwise: false)
        // Left edge.
        path.addLine(to: CGPoint(x: bubbleRect.minX, y: bubbleRect.minY + cornerRadius))
        // Top-left corner.
        path.addArc(center: CGPoint(x: bubbleRect.minX + cornerRadius, y: bubbleRect.minY + cornerRadius),
                    radius: cornerRadius,
                    startAngle: CGFloat(Double.pi),
                    endAngle: CGFloat(3 * Double.pi/2),
                    clockwise: false)
        
        path.closeSubpath()
        
        // Create a shape layer and fill it.
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path
        shapeLayer.fillColor = UIColor(white: 0.95, alpha: 1.0).cgColor
        shapeLayer.strokeColor = UIColor.gray.cgColor
        shapeLayer.lineWidth = 1.0
        
        // Remove any previous shape layers.
        self.layer.sublayers?.filter { $0 is CAShapeLayer }.forEach { $0.removeFromSuperlayer() }
        self.layer.insertSublayer(shapeLayer, at: 0)
    }
}
