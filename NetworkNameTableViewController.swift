//
//  NetworkNameTableViewController.swift
//  Indoor Blueprint
//
//  Created by Nijel Hunt on 9/18/22.
//

import UIKit
import ProgressHUD
import FirebaseFirestore
import SCLAlertView
import FirebaseAuth
import FirebaseStorage

class NetworkNameTableViewController: UITableViewController {

    
    @IBOutlet weak var networkNameTextField: UITextField!
    
    var blueprintUid  : String!

    var blueprint: Blueprint!
    
    let db = Firestore.firestore()
    
    
    internal static func instantiate(with blueprintId: String) -> NetworkNameTableViewController {

        let vc = UIStoryboard(name: "Networks", bundle: nil).instantiateViewController(withIdentifier: "NetworkNameVC") as! NetworkNameTableViewController
        vc.blueprintUid = blueprintId
        return vc
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        reloadData()
        
    }
    
    func reloadData(){
        FirestoreManager.getBlueprint(blueprintUid) { network in
       //     self.navigationController?.title = network?.name
            self.blueprint = network
            self.networkNameTextField.text = network?.name
        }
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return 2
    }
    
    private func alertAndDismiss(_ message: String) {
        
        //activityIndicator.stopAnimating()
        ProgressHUD.dismiss()
        
        view.isUserInteractionEnabled = true
        
        let alert = UIAlertController(title: "Uh oh!", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    private func validateFields() -> Bool {

        // ------- username -------
        guard let username = networkNameTextField.text, username != "" else {
            alertAndDismiss("Network Name cannot be empty")
            return false
        }
        
        
//        checkUsername(field: trimmedUN) { (success) in
//             if success == true {
//                 let alertController = UIAlertController(title: "Error", message: "Username is taken", preferredStyle: UIAlertController.Style.alert)
//                 let defaultAction = UIAlertAction(title: "OK", style: .cancel, handler: nil)
//                 alertController.addAction(defaultAction)
//
//                 self.present(alertController, animated: true, completion: nil)
//                 return
//             } else {
//
//             }}
        
        return true
    
    }
    
    @IBAction func saveAction(_ sender: Any) {
        guard let blueprint = blueprint else {
            return
        }
        
        // no changes made
        if (networkNameTextField.text == blueprint.name){
          //  navigationController?.popViewController(animated: true)
            self.dismiss(animated: true)
        }
        
        ProgressHUD.show()
        
        // ----------  validate fields ----------
        if !validateFields() { return }
    
                 
             
                
        // ---------- create update doc ----------
        var updateDoc = [String:Any]()
                 if self.networkNameTextField.text != blueprint.name {
            //updateDoc[user.username] = usernameTextField.text
            
           let docRef = self.db.collection("blueprints").document(blueprintUid)

           docRef.updateData([
            "name": self.networkNameTextField.text
           ])
             ProgressHUD.dismiss()
                 
                         
     //            let profileVC = self.navigationController?.viewControllers.first as? ProfileViewController
             let profileVC = self.navigationController?.viewControllers.first as? UserProfileViewController
                // profileVC?.collectionView.refreshControl?.beginRefreshing()
               //  profileVC?.reloadData()
                 self.dismiss(animated: true) //navigationController?.popViewController(animated: true)
       }
                          
                       
                   
            
        
//        if usernameTextField.text != user.bio {
//            updateDoc[User.BIO] = bioInput.text
//        }
        
        // ---------- update ----------
//        let group = DispatchGroup()
//
//        // user info
//        group.enter()
//        FirestoreManager.updateUser(updateDoc) { success in
//
//            if !success {
//                return self.alertAndDismiss("We're sorry, your profile cannot be updated at this time. Please try again")
//            }
//
//            group.leave()
//        }
//
//        // profile image changed
//                 if self.profileImageChanged, let data = self.profileImageView.image?.jpegData(compressionQuality: 0.5) {
//
//            group.enter()
//            StorageManager.updateProfilePicture(withData: data) { success in
//
//                if (success == nil) {
//                    return self.alertAndDismiss("We're sorry, your profile cannot be updated at this time. Please try again")
//                }
//
//                group.leave()
//            }
//        }
//
//        // profile image deleted
//                 if self.profileImageDeleted {
//            StorageManager.getProPic(Auth.auth().currentUser!.uid) { image in
//
//                if image != UIImage(named: "nouser") {
//
//                    group.enter()
//                    StorageManager.deleteProPic(self.user.uid) { success in
//                        if !success {
//                            return self.alertAndDismiss("We're sorry, your profile cannot be updated at this time. Please try again")
//                        }
//
//                        group.leave()
//                    }
//                }
//            }
//        }
        
        
        
       // group.notify(queue: DispatchQueue.main) {
            
       //     self.activityIndicator.isHidden = true
       
    //    }
             
    }
    

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
          // Try to find next responder
          if let nextField = textField.superview?.viewWithTag(textField.tag + 1) as? UITextField {
             nextField.becomeFirstResponder()
          } else {
             // Not found, so remove keyboard.
             textField.resignFirstResponder()
          }
          // Do not add a line break
          return false
       }
    
    /*
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "reuseIdentifier", for: indexPath)

        // Configure the cell...

        return cell
    }
    */

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
