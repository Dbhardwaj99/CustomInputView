



import UIKit
import AVFoundation

var lastRowPortraitRightSideRatio: CGFloat { return 0.25 }
var lastRowPortraitLeftSideRatio: CGFloat { return 0.26 }
let darkerKeyboardBackgroundColor = UIColor(red: 208/255.0, green: 211/255.0, blue: 217/255.0, alpha: 255/255.0)

enum KeyboardMode {
    case Default, Email, URL
}

var currentKeyboardMode: KeyboardMode = .Default
let screenScale = UIScreen.main.scale

private var dbTimer: Timer?

var returnType: Int = 0
var keyboardType: Int = 0
var hasChangedToLower = true

var keyboardView: CustomKeyboardView? = nil
class KeyboardViewController: UIInputViewController,UIInputViewAudioFeedback, KeyboardDelegate , UITextFieldDelegate , UIGestureRecognizerDelegate{
    
    var isCustomTextField: Bool = true
    
    func insertText(_ text: String) {
        if isCustomTextField{
            if(text == "⌫" ){
                customTextField.delete()
            }else{
                customTextField.insert(letter: text)
            }
        }else{
            if(text == "⌫" ){
                textDocumentProxy.deleteBackward()
            }else{
                textDocumentProxy.insertText(text)
            }
        }
    }
    
    func changeIt() {
        print("color changed")
    }
    
    func reverseIt() {
        print("color not changed")
    }
    
    
    func playKeyClickSound() {
        UIDevice.current.playInputClick()
    }
    
    let customTextField = CustomTextView(frame: CGRect(x: 50, y: 100, width: 50, height: 70))
    
    
    private var previousReturnType: Int?
    private var previousKeyboardType: Int?
    
    private var keyboardObserver: [NSObjectProtocol] = []
    
    func insertNewline() {
        if isCustomTextField{
            customTextField.insert(letter: "\n")
        }else{
            let proxy = self.textDocumentProxy as UITextDocumentProxy
            proxy.insertText("\n")
            hasChangedToLower = false
        }
    }
    
    func insertNumeric(_ text: String) {
        if isCustomTextField{
            customTextField.insert(letter: text)
        }else{
            textDocumentProxy.insertText(text)
        }
    }
    
    func insertSpace() {
        if isCustomTextField{
            customTextField.insert(letter: " ")
        }else{
            let proxy = self.textDocumentProxy as UITextDocumentProxy
            proxy.insertText(" ")
            hasChangedToLower = false
        }
    }
    
    func showEmojiScreen() {
        print("Show Emoji Screen Here")
    }
    
    
    
    var timer: Timer?
    var startTime: Date?
    var currentInterval: TimeInterval = 0.5
    var checktextfield : Bool = false
    override func updateViewConstraints() {
        super.updateViewConstraints()
    }
    var keyboardHeightConstraint: NSLayoutConstraint?
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.heightAnchor.constraint(equalToConstant: 350)
            
        ])
        customTextField.tag = 6969
    }
    var proxyId: String?  =  ""
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool{
        return true
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        timer?.invalidate()
        timer = nil
        hasChangedToLower = false
        
    }
    
    override func selectionDidChange(_ textInput: UITextInput?) {
        super.selectionDidChange(textInput)
        
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        keyboardView?.removeFromSuperview()
        keyboardView = nil
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
    }
    
    override func textWillChange(_ textInput: UITextInput?) {
    }
    
    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        
        isCustomTextField = false
        updateKeyboardIfNeeded()
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        isCustomTextField = true
    }
    
    
    
    // Declare extraSpacee as a property in your view controller
    var extraSpacee: UIView!
    
    func setupKeyboard() {
        // Existing keyboard setup code
//        customTextField.backgroundColor = .gray
        customTextField.isUserInteractionEnabled = true
        customTextField.delegate = self
        customTextField.layer.cornerRadius = 20
        
        keyboardView?.backgroundColor = darkerKeyboardBackgroundColor
        
        keyboardView = CustomKeyboardView()
        keyboardView?.setUpLayout(delegate: self, mode: previousReturnType!, keyboardType: previousKeyboardType!)
        
        if let keyboardView = keyboardView {
            view.addSubview(keyboardView)
            keyboardView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                keyboardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                keyboardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                keyboardView.heightAnchor.constraint(equalToConstant: 250),
                keyboardView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        }
        
        // Initialize extraSpacee only once
        if extraSpacee == nil {
            extraSpacee = UIView()
            extraSpacee.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(extraSpacee)
        }
        
        // Ensure customTextField is only added once
        if customTextField.superview == nil {
            customTextField.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(customTextField)
        }
        
        // Bring views to front
        view.bringSubviewToFront(customTextField)
        view.bringSubviewToFront(extraSpacee)
        
        if let keyboardView = keyboardView {
            NSLayoutConstraint.activate([
                // Extra space constraints (anchored to safe area)
                extraSpacee.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
                extraSpacee.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
                extraSpacee.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 5),
                extraSpacee.heightAnchor.constraint(equalToConstant: 45),
                
                // CustomTextField constraints
                customTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
                customTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
                customTextField.topAnchor.constraint(equalTo: extraSpacee.bottomAnchor),
                customTextField.bottomAnchor.constraint(equalTo: keyboardView.topAnchor)
            ])
        }
    }
    
    func updateKeyboardIfNeeded() {
        let newReturnType = self.textDocumentProxy.returnKeyType?.rawValue ?? 0
        let newKeyboardType = self.textDocumentProxy.keyboardType?.rawValue ?? 0
        
        if newReturnType != previousReturnType || newKeyboardType != previousKeyboardType {
            
            previousReturnType = newReturnType
            previousKeyboardType = newKeyboardType
            setupKeyboard()
        }
    }
    
    func longPress(gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            startTime = Date()
            currentInterval = 0.1 // Start with a slightly slower delete rate
            
            deleteCharacter()
            
            timer = Timer.scheduledTimer(timeInterval: currentInterval, target: self, selector: #selector(handleTimer), userInfo: nil, repeats: true)
            
        } else if gesture.state == .ended || gesture.state == .cancelled {
            timer?.invalidate()
            timer = nil
        }
    }
    
    @objc private func handleTimer() {
        deleteCharacter()
        
        if let startTime = startTime {
            let elapsedTime = Date().timeIntervalSince(startTime)
            if elapsedTime > 1.5 {
                currentInterval = 0.08 // Speed up after 1.5s
            } else if elapsedTime > 3 {
                currentInterval = 0.05 // Speed up further after 3s
            }
        }
        
        timer?.invalidate()
        timer = Timer.scheduledTimer(timeInterval: currentInterval, target: self, selector: #selector(handleTimer), userInfo: nil, repeats: true)
    }
    
    private func deleteCharacter() {
        if isCustomTextField {
            customTextField.delete()
        } else {
            textDocumentProxy.deleteBackward()
        }
    }
    
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        _ = touch.location(in: self.view)
        
        let location = touch.location(in: self.view)
        
        if !self.view.bounds.contains(location) {
            print("outside the view")
            checktextfield = false
        }
    }
    
    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        return true
    }
    
}


extension KeyboardViewController : CustomTextViewProtocol {
    func addToPasteBoard() {
    
    }

    func fetchFromPasteBoard() {
    
    }

    func changeFocus() {
        isCustomTextField = true
    }
}
