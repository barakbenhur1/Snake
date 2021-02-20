//
//  LoginPopupViewController.swift
//  InteractechSport
//
//  Created by Interactech on 15/11/2020.
//  Copyright © 2020 Interactech. All rights reserved.
//

import UIKit

typealias FinishAnimation = () -> ()
typealias closeFinish = () -> ()

class SnakePopupViewController: UIViewController {
    
    @IBOutlet weak var customPopupView: CustomPopupView!
    @IBOutlet weak var backgroundView: UIView!
    @IBOutlet weak var popupAnimationConstraint: NSLayoutConstraint!
    
    var count: Int = 0
    var time: Int = 0
    var score: Int = 0
    
    var closeClousre: closeFinish?
    
    override func viewDidLoad() { 
        super.viewDidLoad()
        
        customPopupView.count = "\(count)"
        customPopupView.time = "\(time)"
        
        var isHighScore = false
        
        if let highScore = UserDefaults.standard.value(forKey: "highScore") as? Int {
            UserDefaults.standard.setValue(max(highScore, score), forKey: "highScore")
            isHighScore = score > highScore
        }
        else {
            UserDefaults.standard.setValue(score, forKey: "highScore")
            customPopupView.score = (score , false)
            isHighScore = false
        }
        
        customPopupView.score = (score , isHighScore)
        
        customPopupView.closeAction = {
            self.animateView(view: self.customPopupView ,from: .identity, to: CGAffineTransform(scaleX: 0.0001, y: 0.0001), daly: 0.2, finish: {
                UIView.animate(withDuration: 0.01) {
                    self.backgroundView.backgroundColor = .clear
                }

                self.dismiss(animated: true, completion: nil)
                self.closeClousre?()
            })
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let view = { () -> CustomPopupView in
            return customPopupView
        }()
        
        
        self.animateView(view: view, daly: 0.2, finish: {
            UIView.animate(withDuration: 0.2) {
                self.backgroundView.backgroundColor = UIColor.black.withAlphaComponent(0.54)
            }
        })
    }
    
    private func animateView(view: UIView, from: CGAffineTransform = CGAffineTransform(scaleX: 0.0001, y: 0.0001), to: CGAffineTransform = .identity, time: TimeInterval = 0.14, daly: TimeInterval = 0, shake: Bool = false, finish: FinishAnimation? = nil) {
        view.transform = from
        
        DispatchQueue.main.asyncAfter(deadline: .now() + daly) {
            UIView.animate(withDuration: time) {
                view.transform = to
            } completion: { (_) in
                finish?()
            }
        }
    }
    
    func success() {
        customPopupView.closeView(nil)
    }
}
