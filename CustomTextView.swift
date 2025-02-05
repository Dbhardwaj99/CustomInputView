//
//  CustomTextView.swift
//  Label_Keyboard
//
//  Created by Divyansh Bhardwaj on 05/02/25.
//

import Foundation
import UIKit

protocol CustomTextViewProtocol: AnyObject {
    func changeFocus()
    func addToPasteBoard()
    func fetchFromPasteBoard()
}

class CustomTextView: UIView {
    private var textField: CustomInputView
    private var clearButton: UIButton
    
//    var BGColor: UIColor
//    var ForegroundColor: UIColor

    weak var delegate: CustomTextViewProtocol?

    override init(frame: CGRect) {
        self.textField = CustomInputView()
        self.clearButton = UIButton(type: .system)
        super.init(frame: frame)
        backgroundColor = .primary
        setupInputView()
        setupClearButton()
    }

    required init?(coder: NSCoder) {
        self.textField = CustomInputView()
        self.clearButton = UIButton(type: .system) // Initialize clear button
        super.init(coder: coder)
        self.backgroundColor = .primary
        setupInputView()
        setupClearButton()
    }

    private func setupInputView() {
        textField.backgroundColor = .clear
        textField.isUserInteractionEnabled = true
        textField.delegate = self
//        textField.addTarget(self, action: #selector(textDidChange), for: .editingChanged) // Observe text changes
        
        textField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textField)
        bringSubviewToFront(textField)

        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -40), // Adjusted for clear button space
            textField.topAnchor.constraint(equalTo: topAnchor, constant: 13),
            textField.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -13)
        ])
    }

    private func setupClearButton() {
        
        clearButton
            .setImage(
                UIImage(systemName: "xmark.circle.fill")?
                    .withTintColor(.secondary),
                for: .normal
            )
        clearButton.tintColor = .secondary
        clearButton.alpha = 0 // Initially hidden
        clearButton.addTarget(self, action: #selector(clearText), for: .touchUpInside)

        clearButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(clearButton)
        
        NSLayoutConstraint.activate([
            clearButton.centerYAnchor.constraint(equalTo: textField.centerYAnchor),
            clearButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            clearButton.widthAnchor.constraint(equalToConstant: 24),
            clearButton.heightAnchor.constraint(equalToConstant: 24)
        ])
    }

    private func textDidChange() {
        clearButton.alpha = textField.returnText() == "" ? 0 : 1
    }

    @objc func clearText() {
        textField.clearTextField()
        clearButton.alpha = 0
    }
}

// MARK: - Actions
extension CustomTextView {
    func insert(letter: String) {
        textField.insertText(letter)
        textDidChange() // Update clear button visibility
    }

    func delete() {
        textField.deleteBackward()
        textDidChange() // Update clear button visibility
    }

    func changeSize() {
        textField.changeTextSize()
    }

    func fetchText() -> String {
        return textField.returnText()
    }
}

// MARK: - CustomTextFieldProtocol
extension CustomTextView: CustomTextFieldProtocol {
    func changeFocus() {
        delegate?.changeFocus()
    }
}
