//
//  ComposeArtworkViewController.swift
//  Indoor Blueprint
//
//  Created by Nijel Hunt on 11/20/22.
//

import UIKit
import OpenAIKit
import ProgressHUD
import FirebaseAuth
import FirebaseFirestore

class ComposeArtworkViewController: UIViewController, UITextViewDelegate {

    @IBOutlet weak var generatedImageView: UIImageView!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var textCountRemainingLabel: UILabel!
    @IBOutlet weak var imageBtn: UIButton!
    @IBOutlet weak var modelBtn: UIButton!
    @IBOutlet weak var createBtn: UIButton!
    @IBOutlet weak var exampleStackView: UIStackView!
    @IBOutlet weak var settingsImgView: UIImageView!
    @IBOutlet weak var promptTextView: UITextView!
    @IBOutlet weak var backImgView: UIImageView!
    
    // URL of the model to download
    let modelUrl = URL(string: "http://localhost:8080/Diffusion.zip")
    
    // variable to store generated image
    var generatedImage : UIImage?
    
    // flags to check if image or model is selected
    var isImage = false
    var isModel = false
    
    // variable to store user's credits
    var credits = 0
    
    // reference to Firestore database
    let db = Firestore.firestore()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //set the initial text for the promptTextView
        promptTextView.text = "Type anything"
        //set the initial text color for the promptTextView
        promptTextView.textColor = UIColor.lightGray
        //create a tap gesture for the back button
        let backTap = UITapGestureRecognizer(target: self, action: #selector(back))
        backImgView.addGestureRecognizer(backTap)
        //set the delegate for the promptTextView
        promptTextView.delegate = self
        //set the text container inset for the promptTextView
        promptTextView.textContainerInset = UIEdgeInsets(top: 15, left: 12, bottom: 15, right: 12)

        //create a tap gesture to dismiss the keyboard
        let dismissKey = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(dismissKey)
        
        //set the background color for the create button
        createBtn.backgroundColor = UIColor(red: 199/255, green: 199/255, blue: 204/255, alpha: 1)
        //set the user interface style for the view
        view.overrideUserInterfaceStyle = .light
        //call the setup function
        setup()
    }

    private var openAI: OpenAI?

    func setup(){
        //initialize the OpenAI object with the organization and API key
         openAI = OpenAI(Configuration(organization: "Personal", apiKey: "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"))
        if Auth.auth().currentUser != nil{
            FirestoreManager.getUser(Auth.auth().currentUser?.uid ?? "") { user in
                self.credits = user?.points ?? 0
            }
        }
    }
    
    // Asynchronously generates image using OpenAI with given prompt
    func generateImage(prompt: String) async -> UIImage? {
        guard let openAI = openAI else {
            return nil
        }
        do {
            let params = ImageParameters(prompt: prompt, resolution: .medium, responseFormat: .base64Json)
            
            let result = try await openAI.createImage(parameters: params)
            
            let data = result.data[0].image
            let image = try openAI.decodeBase64Image(data)
            return image
        }
        catch {
            print(String(describing: error))
            return nil
        }
    }
    
    // If a generated image exists, present an alert before dismissing the view
    @objc func back() {
        if self.generatedImage != nil {
            self.loseArtAlert()
            return
        }
        self.dismiss(animated: true, completion: nil)
    }
    
    @objc func loseArtAlert(){
            // create an alert to confirm if the user wants to leave the creation and lose their generated art
            let alertController = UIAlertController(title: "Leave Creation", message: "Are you sure you want to leave? You will lose your generated art.", preferredStyle: .alert)
            
            // action to dismiss the view controller and lose the generated art
            let purchaseAction = UIAlertAction(title: "Leave", style: .default, handler: { (_) in
                self.dismiss(animated: true, completion: nil)
            })
            
            // action to cancel and stay on the current view controller
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: { (_) in
                
            })
           
            // add the actions to the alert controller
            alertController.addAction(purchaseAction)
            alertController.addAction(cancelAction)
            
            // present the alert to the user
            self.present(alertController, animated: true, completion: nil)
        }
        
        @objc func dismissKeyboard() {
            // resign the keyboard as the first responder when the user taps outside of the text view
            promptTextView.resignFirstResponder()
        }
        
        func promptAlert() {
        // create an alert to inform the user to enter a prompt for generating content
        let alertController = UIAlertController(title: "Input Prompt", message: "Enter a prompt which will be used to generate some content.", preferredStyle: .alert)
        let purchaseAction = UIAlertAction(title: "OK", style: .default, handler: { (_) in
           // GO TO PURCHASE POINTS VC -- DO NOT LOSE GENERATED CONTENT
        })
        alertController.addAction(purchaseAction)
            
        self.present(alertController, animated: true, completion: nil)
        
        }
    
    func categoryAlert() {
        let alertController = UIAlertController(title: "Choose Category", message: "Choose a category between generating an image or 3D model.", preferredStyle: .alert)
        let purchaseAction = UIAlertAction(title: "OK", style: .default, handler: { (_) in
            // GO TO PURCHASE POINTS VC -- DO NOT LOSE GENERATED CONTENT
            
        })
       
        alertController.addAction(purchaseAction)
        self.present(alertController, animated: true, completion: nil)
        
        }
    
    // This function is triggered when the "image" button is pressed.
    // It sets the 'isImage' flag to true and the 'isModel' flag to false.
    // It also changes the appearance of the "image" button to indicate that it is selected.
    // Finally, it checks if the prompt text view is not empty and if it is not, it changes the color of the 'create' button.
    @IBAction func imageAction(_ sender: Any) {
        isImage = true
        isModel = false
        imageBtn.tintColor = .white
        imageBtn.backgroundColor = .systemBlue
        modelBtn.tintColor = .tintColor
        modelBtn.backgroundColor = UIColor(red: 59/255, green: 102/255, blue: 246/255, alpha: 0.15)
        print("\(promptTextView.text) is textView text")
        if !promptTextView.text.isEmpty && promptTextView.text != "" && promptTextView.text != " " && promptTextView.text != "Type anything" {
            self.createBtn.backgroundColor = .tintColor
        } else {
            self.createBtn.backgroundColor = UIColor(red: 199/255, green: 199/255, blue: 204/255, alpha: 1)
        }
    }
    
    
    // This function is triggered when the "model" button is pressed.
    // It sets the 'isModel' flag to true and the 'isImage' flag to false.
    // It also changes the appearance of the "model" button to indicate that it is selected.
    // Finally, it checks if the prompt text view is not empty and if it is not, it changes the color of the 'create' button.
    @IBAction func modelAction(_ sender: Any) {
        isModel = true
        isImage = false
        modelBtn.tintColor = .white
        modelBtn.backgroundColor = .systemBlue
        imageBtn.tintColor = .tintColor
        imageBtn.backgroundColor = UIColor(red: 59/255, green: 102/255, blue: 246/255, alpha: 0.15)
        if !promptTextView.text.isEmpty && promptTextView.text != "" && promptTextView.text != " " && promptTextView.text != "Type anything" {
            self.createBtn.backgroundColor = .tintColor
        } else {
            self.createBtn.backgroundColor = UIColor(red: 199/255, green: 199/255, blue: 204/255, alpha: 1)
        }
    }
    
    func buyPointsImageAlert() {
        // create an alert to inform the user that they do not have enough credits to generate an image
        let alertController = UIAlertController(title: "Not Enough Credits :/", message: "To generate content on Blueprint, it requires 1 credit per image. You can add credits to your account now.", preferredStyle: .alert)
        // create an action to allow the user to purchase more credits
        let purchaseAction = UIAlertAction(title: "Purchase", style: .default, handler: { (_) in
           // GO TO PURCHASE POINTS VC -- DO NOT LOSE GENERATED CONTENT
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            var next = storyboard.instantiateViewController(withIdentifier: "PurchasePointsVC") as! PurchasePointsViewController
            next.modalPresentationStyle = .fullScreen
            self.present(next, animated: true, completion: nil)
        })
        // create an action to allow the user to cancel the purchase
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: { (_) in
            
        })
        // add the actions to the alert
        alertController.addAction(purchaseAction)
        alertController.addAction(cancelAction)
        // present the alert
        self.present(alertController, animated: true, completion: nil)
    }

    func buyPointsModelAlert() {
        // create an alert to inform the user that they do not have enough credits to generate a model
        let alertController = UIAlertController(title: "Not Enough Credits :/", message: "To generate content on Blueprint, it requires 10 credits per model. You can add credits to your account now.", preferredStyle: .alert)
        // create an action to allow the user to purchase more credits
        let purchaseAction = UIAlertAction(title: "Purchase", style: .default, handler: { (_) in
           // GO TO PURCHASE POINTS VC -- DO NOT LOSE GENERATED CONTENT
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            var next = storyboard.instantiateViewController(withIdentifier: "PurchasePointsVC") as! PurchasePointsViewController
            next.modalPresentationStyle = .fullScreen
            self.present(next, animated: true, completion: nil)
        })
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: { (_) in
            
        })
       
        alertController.addAction(purchaseAction)
        alertController.addAction(cancelAction)
        self.present(alertController, animated: true, completion: nil)
        
    }
    
    //This function updates the points of the current user in the Firestore database
     func updatePoints(){
            if Auth.auth().currentUser != nil{
                let docRef2 = self.db.collection("users").document(Auth.auth().currentUser?.uid ?? "")
                docRef2.updateData([
                    "points": FieldValue.increment(Int64(-1))
                ])
            }
        }

    //This function shows an alert that lets the user know that the feature of generating 3D models is not available yet
    func chooseImageAlert(){
        let alertController = UIAlertController(title: "Feature Coming Soon", message: "As of right now, generating 3D models is not available, if you want to generate content choose an image.", preferredStyle: .alert)
        let purchaseAction = UIAlertAction(title: "OK", style: .default, handler: { (_) in
         
        })
       
        alertController.addAction(purchaseAction)
        self.present(alertController, animated: true, completion: nil)
    }

    
    func createAccountAlert(){
        let alertController = UIAlertController(title: "Create Blueprint Account", message: "To save and upload generated content to Blueprint's Marketplace, you must first create an account.", preferredStyle: .alert)
        let purchaseAction = UIAlertAction(title: "Sign Up", style: .default, handler: { (_) in
           // GO TO PURCHASE POINTS VC -- DO NOT LOSE GENERATED CONTENT
            let storyboard = UIStoryboard(name: "SignUp", bundle: nil)
//            var next = storyboard.instantiateViewController(withIdentifier: "CreateAccountVC") as! CreateAccountViewController
            var next = storyboard.instantiateViewController(withIdentifier: "SignUpVC") as! SignUpViewController
            next.modalPresentationStyle = .fullScreen
            self.present(next, animated: true, completion: nil)
        })
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: { (_) in
            
        })
       
        alertController.addAction(purchaseAction)
        alertController.addAction(cancelAction)
        self.present(alertController, animated: true, completion: nil)
    }
    
    @IBAction func createAction(_ sender: Any) {
        // SEND REQUEST TO THIRD PARTY WITH PROMPT - SHOW PROGRESS - THEN SHOW IMAGE THAT IT GENERATES -- IF #D MODEL, THEN GET SCREENSHOT OF 3D MODEL THAT IS USED IN NEXT VC
        
        if self.createBtn.currentTitle == "Upload" {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
           // print("\(LaunchViewController.auth.currentUser?.uid) is the current user id")
            
            var next = storyboard.instantiateViewController(withIdentifier: "ContentDetailsTableVC") as! ContentDetailsTableViewController
            let navVC = UINavigationController(rootViewController: next)
           // var next = UserProfileViewController.instantiate(with: user)
          
            navVC.modalPresentationStyle = .fullScreen
            present(navVC, animated: true, completion: nil)
        }
        
        
        if self.createBtn.currentTitle == "Generate" {
            if self.createBtn.backgroundColor == .tintColor {
            //    self.progressView.isHidden = false
              //  self.createAccountAlert()
                if Auth.auth().currentUser != nil{
                    if !promptTextView.text.trimmingCharacters(in: .whitespaces).isEmpty && self.isImage == true {
                        Task {
                                if self.credits < 1 {
                                    self.buyPointsImageAlert()
                                    return
                                } else {
                                    ProgressHUD.show("Generating art")
                                    view.isUserInteractionEnabled = false
                                    UIView.animate(withDuration: 1.1, delay: 0, options: [.curveEaseInOut], animations: {
                                        
                                        self.createBtn.backgroundColor = .systemGreen
                                        self.createBtn.setTitle("Upload", for: .normal)
                                        
                                    })
                                    let result = await self.generateImage(prompt: self.promptTextView.text)
                                    // let progress = resu
                                    if result == nil {
                                        print("Failed to get image")
                                        ProgressHUD.dismiss()
                                        self.createBtn.backgroundColor = .tintColor
                                        self.createBtn.setTitle("Generate", for: .normal)
                                        self.failedAlert()
                                        view.isUserInteractionEnabled = true
                                        return
                                    }
                                    self.updatePoints()
                                    generatedImage = result
                                    self.generatedImageView.image = result
                                    
                                    guard let data = result?.jpegData(compressionQuality: 0.65) else { return }
                                    let encoded = try! PropertyListEncoder().encode(data)
                                    UserDefaults.standard.set(encoded, forKey: "image")
                                    progressView.isHidden = true
                                    view.isUserInteractionEnabled = true
                                    self.imageBtn.isUserInteractionEnabled = false
                                    self.modelBtn.isUserInteractionEnabled = false
                                    ProgressHUD.dismiss()
                                }
                        }
                    } else if !promptTextView.text.trimmingCharacters(in: .whitespaces).isEmpty && self.isModel == true {
                        self.chooseImageAlert()
                        return
                    }
                } else {
                    self.createAccountAlert()
                    return
                }
                
                
            } else {
                if promptTextView.text.isEmpty || promptTextView.text == "" || promptTextView.text == " " || promptTextView.text == "Type anything" {
                    self.promptAlert()
                } else if self.isModel != true && self.isImage != true {
                    print("\(self.modelBtn.backgroundColor) is background color of model btn")
                    print("\(self.imageBtn.backgroundColor) is background color of imageBtn")
                    self.categoryAlert()
                }
            }
        }
        
    }
    
    func failedAlert(){
        let alertController = UIAlertController(title: "Uh oh!", message: "Something within your prompt was against Blueprint's user guidelines, meaning we could not generate it. You will not be charged any credits for this. Try again with another prompt.", preferredStyle: .alert)
        let purchaseAction = UIAlertAction(title: "OK", style: .default, handler: { (_) in
//            self.createBtn.backgroundColor = UIColor(red: 199/255, green: 199/255, blue: 204/255, alpha: 1)
//
//            self.createBtn.setTitle("Generate", for: .normal)
        })
      
        alertController.addAction(purchaseAction)
        self.present(alertController, animated: true, completion: nil)
    }
    
    func saveImage() {
        guard let data = UIImage(named: "image")?.jpegData(compressionQuality: 0.65) else { return }
        let encoded = try! PropertyListEncoder().encode(data)
        UserDefaults.standard.set(encoded, forKey: "image")
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.textColor == UIColor.lightGray {
            textView.text = nil
            textView.textColor = UIColor.black
        }
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text.isEmpty {
            textView.text = "Type anything"
            textView.textColor = UIColor.lightGray
        } else {
            if self.isImage == true || self.isModel == true {
                self.createBtn.backgroundColor = .tintColor
            } else {
                self.createBtn.backgroundColor = UIColor(red: 199/255, green: 199/255, blue: 204/255, alpha: 1)
            }
        }
    
    }
    
    func textViewDidChange(_ textView: UITextView) {
        let count = textView.text.count
        textCountRemainingLabel.text = String(400 - count)
//        if (text == "\n") {
//            textView.resignFirstResponder()
//        }
    }
    
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
//        if (text == "\n") {
//             textView.resignFirstResponder()
//             return false
//         }
//         return true
        if(text == "\n"){
                textView.resignFirstResponder()
                return false
            }
            else {
                return textView.text.count + (text.count - range.length) <= 400
            }
        
        
    }
    
}
