//
//  NibView.swift
//  InteractechSport
//
//  Created by Interactech on 30/07/2020.
//  Copyright © 2020 Interactech. All rights reserved.
//

import UIKit

class NibView: UIView {
    
    @IBOutlet var view : UIView!
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        xibSetUp()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        xibSetUp()
    }
    
    func xibSetUp() {
        view = loadViewFromNib()
        view.frame = self.bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(view)
    }
    
    func loadViewFromNib() -> UIView {
        
        let bundle = Bundle(for: type(of: self))
        let nibName = type(of: self).description().components(separatedBy: ".").last!
        let nib = UINib(nibName: nibName, bundle: bundle)
        return nib.instantiate(withOwner: self, options: nil).first as! UIView
    }
}

extension UIView {
    @IBInspectable var circle: CGFloat {
        set {
            self.layer.cornerRadius = newValue
        }
        get {
            return self.layer.cornerRadius
        }
    }
}

extension UILabel {
    @IBInspectable var makeAtter: Bool {
        set {
            let atter = NSMutableAttributedString(string: self.text ?? "")
            
            var i = 0
            self.text?.forEach({ (char) in
                let color: UIColor = i % 4 == 0 ? .systemYellow : i % 3 == 0 ? .green : i % 2 == 0 ? .red : .blue
                atter.addAttributes([.foregroundColor : color], range: NSRange(location: i, length: 1))
                i += 1
            })
            
            self.attributedText = atter
        }
        get {
            return self.attributedText?.string.isEmpty ?? false
        }
    }
}
