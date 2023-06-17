//
//  InitialViewController.swift
//  Indoor Blueprint
//
//  Created by Nijel Hunt on 5/20/23.
//

import UIKit

class InitialViewController: UIViewController {
    
    var window: UIWindow?

    @IBOutlet weak var arrowImgView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        arrowImgView.layer.borderColor = UIColor.white.cgColor
        arrowImgView.layer.borderWidth = 1.5
        // Do any additional setup after loading the view.
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tap))
        arrowImgView.addGestureRecognizer(tapGesture)
    }
    
    @objc func tap(){
        let storyboard = UIStoryboard(name: "Walkthrough", bundle: nil)
        var next = storyboard.instantiateViewController(withIdentifier: "EnablePermissionsVC") as! EnablePermissionsViewController
       // next.modalPresentationStyle = .fullScreen
        self.present(next, animated: true, completion: nil)
    }
    

    @IBAction func accountAction(_ sender: Any) {
        let storyboard = UIStoryboard(name: "SignUp", bundle: nil)
        var next = storyboard.instantiateViewController(withIdentifier: "LogInVC") as! LogInViewController
        next.modalPresentationStyle = .fullScreen
       
        self.present(next, animated: true, completion: nil)
    }
    

}
