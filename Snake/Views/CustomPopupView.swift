//
//  LoginPopupView.swift
//  InteractechSport
//
//  Created by Interactech on 15/11/2020.
//  Copyright © 2020 Interactech. All rights reserved.
//

import UIKit

typealias Compilation = () -> ()

class CustomPopupView: NibView {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var button: UIButton!
    @IBOutlet weak var image: UIImageView!
    @IBOutlet weak var imageWrapper: UIView!
    @IBOutlet weak var countLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var scoreLabel: UILabel!
    @IBOutlet weak var shadowView: UIView!
    
    private var loc: CGPoint?
    
    var closeAction: Compilation?
    
    var count: String = "0" {
        didSet {
            countLabel.text = "Eat: \(count) food"
        }
    }
    
    var time: String = "0" {
        didSet {
            timeLabel.text = "Survived: \(time) seconds"
        }
    }

    var score: (score: Int, isHighScore: Bool) = (0 , false) {
        didSet {
            let numberFormatter = NumberFormatter()
            numberFormatter.numberStyle = .decimal          // Set defaults to the formatter that are common for showing decimal numbers
            numberFormatter.usesGroupingSeparator = true    // Enabled separator
            numberFormatter.groupingSeparator = ","         // Set the separator to "," (e.g. 1000000 = 1,000,000)
            numberFormatter.groupingSize = 3                // Set the digits between each separator
            
            let scoreString = numberFormatter.string(from: NSNumber(value: score.score))!

            scoreLabel.text = "\(score.isHighScore ? "New High" : "") Score: \(scoreString)"
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
//        titleLabel.layer.masksToBounds = false
//        titleLabel.layer.shadowColor = UIColor.systemGray.cgColor
//        titleLabel.layer.shadowOpacity = 0.4
//        titleLabel.layer.shadowOffset = .init(width: 0, height: -titleLabel.frame.height / 2)
//        titleLabel.layer.shadowRadius = titleLabel.frame.height / 2
//
//        titleLabel.layer.shadowPath = UIBezierPath(rect: CGRect(origin: titleLabel.frame.origin, size: CGSize(width: titleLabel.frame.width - 40, height: titleLabel.frame.height / 2.4))).cgPath
//
        button.isEnabled = true
        layer.cornerRadius = 40
        button.layer.cornerRadius = 24
        
        shadowView.layer.shadowPath = UIBezierPath(rect: shadowView.bounds).cgPath
        shadowView.layer.shadowRadius = 8
        shadowView.layer.shadowColor = UIColor.black.cgColor
        shadowView.layer.shadowOffset = .zero
        shadowView.layer.shadowOpacity = 0.9

        imageWrapper.layer.cornerRadius = image.frame.height / 2
        
        let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(holdButton))
        
        recognizer.minimumPressDuration = 0
        
        button.addGestureRecognizer(recognizer)
    }
    
    @objc private func holdButton(_ sender: UILongPressGestureRecognizer) {
        switch sender.state {
        case .began:
            button.backgroundColor = button.backgroundColor?.withAlphaComponent(0.4)
            button.isSelected = true
            return
        case .ended:
            if button.isSelected {
                UIView.animate(withDuration: 0.3) {
                    self.button.isSelected = false
                    self.button.backgroundColor = self.button.backgroundColor?.withAlphaComponent(1)
                    self.closeView(nil)
                }
            }
        default:
            button.isSelected = button.frame.contains(sender.location(in: self))
            button.backgroundColor = button.isSelected ? button.backgroundColor?.withAlphaComponent(0.4) : button.backgroundColor?.withAlphaComponent(1)
            return
        }
    }
    
    @objc func closeView(_ sender: UITapGestureRecognizer?) {
        closeAction?()
    }
}
