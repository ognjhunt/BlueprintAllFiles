//
//  ContactsViewController.swift
//  Indoor Blueprint
//
//  Created by Nijel Hunt on 1/8/23.
//

import UIKit
import Contacts
import ContactsUI


class ContactsViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        pullContacts()
        // Do any additional setup after loading the view.
    }
    
//    class func getContacts(filter: ContactsFilter = .none) -> [CNContact] { //  ContactsFilter is Enum find it below
//
//            let contactStore = CNContactStore()
//            let keysToFetch = [
//                CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
//                CNContactPhoneNumbersKey,
//                CNContactEmailAddressesKey,
//                CNContactThumbnailImageDataKey] as [Any]
//
//            var allContainers: [CNContainer] = []
//            do {
//                allContainers = try contactStore.containers(matching: nil)
//            } catch {
//                print("Error fetching containers")
//            }
//
//            var results: [CNContact] = []
//
//            for container in allContainers {
//                let fetchPredicate = CNContact.predicateForContactsInContainer(withIdentifier: container.identifier)
//
//                do {
//                    let containerResults = try contactStore.unifiedContacts(matching: fetchPredicate, keysToFetch: keysToFetch as! [CNKeyDescriptor])
//                    results.append(contentsOf: containerResults)
//                } catch {
//                    print("Error fetching containers")
//                }
//            }
//            return results
//        }
    
    
        
    func pullContacts() {
        
        let store = CNContactStore()
        
        store.requestAccess(for: CNEntityType.contacts) { hasPermission, error in
              if error != nil {
                   print(error!)
              }
         }
        
        if (CNContactStore.authorizationStatus(for: CNEntityType.contacts) == .authorized) {
                                 
            let request = CNContactFetchRequest(keysToFetch: [
                CNContactGivenNameKey as CNKeyDescriptor,
                CNContactFamilyNameKey as CNKeyDescriptor,
                CNContactEmailAddressesKey as CNKeyDescriptor,
                CNContactPhoneNumbersKey as CNKeyDescriptor
            ])
                        
            do {
                try store.enumerateContacts(with: request) {
                    (contact, stop) in
                    print(contact)
                }
                
            } catch {
                print("error: \(error)")
            }
        }
    }
}
