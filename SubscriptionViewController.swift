//
//  SubscriptionViewController.swift
//  Indoor Blueprint
//
//  Created by Nijel Hunt on 5/25/23.
//

import UIKit

class SubscriptionViewController: UIViewController {

    @IBOutlet weak var amountDueLabel: UILabel!
    @IBOutlet weak var monthlyPriceLabel: UILabel!
    @IBOutlet weak var monthlyTitleLabel: UILabel!
    @IBOutlet weak var monthlyCheckImgView: UIImageView!
    @IBOutlet weak var yearlyCheckImgView: UIImageView!
    @IBOutlet weak var monthlyView: UIView!
    @IBOutlet weak var yearlyView: UIView!
    
    
    @IBOutlet weak var yearlySubPriceLabel: UILabel!
    @IBOutlet weak var yearlyPriceLabel: UILabel!
    @IBOutlet weak var yearlyTitleLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        monthlyView.layer.borderWidth = 2
        monthlyView.layer.borderColor = UIColor.white.cgColor
        monthlyCheckImgView.image = nil
        monthlyCheckImgView.backgroundColor = .clear
        monthlyCheckImgView.layer.borderWidth = 1
        monthlyCheckImgView.layer.borderColor = UIColor.white.cgColor
        // Do any additional setup after loading the view.
        
        let monthlyTap = UITapGestureRecognizer(target: self, action: #selector(monthlyAction))
        monthlyView.addGestureRecognizer(monthlyTap)
        
        let yearlyTap = UITapGestureRecognizer(target: self, action: #selector(yearlyAction))
        yearlyView.addGestureRecognizer(yearlyTap)
    }
    
    @objc func monthlyAction(){
        monthlyView.backgroundColor = .white
        monthlyCheckImgView.image = UIImage(systemName: "checkmark.circle.fill")
        monthlyCheckImgView.contentMode = .scaleAspectFit
        monthlyCheckImgView.tintColor = .tintColor
        monthlyCheckImgView.backgroundColor = .white
        monthlyTitleLabel.textColor = .black
        monthlyPriceLabel.textColor = .black
        
        
        yearlyView.backgroundColor = .clear
        yearlyView.layer.borderWidth = 2
        yearlyView.layer.borderColor = UIColor.white.cgColor
        yearlyCheckImgView.image = nil
        yearlyCheckImgView.backgroundColor = .clear
        yearlyCheckImgView.layer.borderWidth = 1
        yearlyCheckImgView.layer.borderColor = UIColor.white.cgColor
        yearlyTitleLabel.textColor = .white
        yearlyPriceLabel.textColor = .white
        yearlySubPriceLabel.textColor = .systemGray5
        
        amountDueLabel.text = "$9.99"
    }
    
    @objc func yearlyAction(){
        yearlyView.backgroundColor = .white
        yearlyCheckImgView.image = UIImage(systemName: "checkmark.circle.fill")
        yearlyCheckImgView.contentMode = .scaleAspectFit
        yearlyCheckImgView.tintColor = .tintColor
        yearlyCheckImgView.backgroundColor = .white
        yearlyTitleLabel.textColor = .black
        yearlyPriceLabel.textColor = .black
        yearlySubPriceLabel.textColor = .darkGray
        
        monthlyView.backgroundColor = .clear
        monthlyView.layer.borderWidth = 2
        monthlyView.layer.borderColor = UIColor.white.cgColor
        monthlyCheckImgView.image = nil
        monthlyCheckImgView.backgroundColor = .clear
        monthlyCheckImgView.layer.borderWidth = 1
        monthlyCheckImgView.layer.borderColor = UIColor.white.cgColor
        monthlyTitleLabel.textColor = .white
        monthlyPriceLabel.textColor = .white
        
        amountDueLabel.text = "$83.99"
    }

    @IBAction func closeAction(_ sender: Any) {
        self.dismiss(animated: true)
    }
}
