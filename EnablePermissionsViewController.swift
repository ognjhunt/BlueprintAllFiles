//
//  EnablePermissionsViewController.swift
//  Indoor Blueprint
//
//  Created by Nijel Hunt on 5/20/23.
//

import UIKit
import CoreLocation
import FirebaseAuth
import AVFoundation
import FirebaseFirestore
import ProgressHUD

class EnablePermissionsViewController: UIViewController, CLLocationManagerDelegate, UIApplicationDelegate {

    var window: UIWindow?
    
    var locationManager: CLLocationManager?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        locationManager = CLLocationManager()
            locationManager?.delegate = self
        // Do any additional setup after loading the view.
        

    }
    
    @IBAction func allowAction(_ sender: Any) {
        self.shouldCheck = true
        //Camera
        AVCaptureDevice.requestAccess(for: AVMediaType.video) { response in
            if response {
                //access granted
                self.locationManager?.requestAlwaysAuthorization()
            } else {
                //access denied
                self.checkCameraAccess()
            }
        }
    }
    
    
    
    @objc func goToSettings(){
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
                    return
                }

                if UIApplication.shared.canOpenURL(settingsUrl) {
                    UIApplication.shared.open(settingsUrl, completionHandler: { (success) in
                        print("Settings opened: \(success)") // Prints true
                    })
                }
    }

    var shouldCheck = false
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            if CLLocationManager.isMonitoringAvailable(for: CLBeaconRegion.self) {
                if CLLocationManager.isRangingAvailable() {
                    // do stuff
                    self.registerForPushNotifications()
                }
            }
        } else {
            // show error
            if self.shouldCheck == true {
                self.checkLocationPermission()
            }
        }
    }
    
    

    func getNotificationSettings() {
        UNUserNotificationCenter.current().getNotificationSettings { (settings) in
            print("Notification settings: \(settings)")
            guard settings.authorizationStatus == .authorized else {
                self.view.endEditing(true)
                ProgressHUD.show("Loading...")
                self.goToLaunch()
                let defaults = UserDefaults.standard
                defaults.set(true, forKey: "finishedPermissions")
                
                ProgressHUD.dismiss()
                return
            }
            
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
                self.view.endEditing(true)
                ProgressHUD.show("Loading...")
                self.goToLaunch()
                let defaults = UserDefaults.standard
                defaults.set(true, forKey: "finishedPermissions")

                ProgressHUD.dismiss()
                return
            }
        }
    }

    func registerForPushNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { (granted, error) in
            print("Permission granted: \(granted)")

            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                    self.view.endEditing(true)
                    ProgressHUD.show("Loading...")
                    self.goToLaunch()
                    let defaults = UserDefaults.standard
                    defaults.set(true, forKey: "finishedPermissions")
                    ProgressHUD.dismiss()
                    return
                }
            } else {
                self.getNotificationSettings()
            }
        }
    }

    
//    func registerForPushNotifications() {
//        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) {
//            (granted, error) in
//            print("Permission granted: \(granted)")
//
//            if granted {
//                DispatchQueue.main.async {
//                    UIApplication.shared.registerForRemoteNotifications()
//                    self.goToLaunch()
//                    return
//                }
//            } else {
//                self.getNotificationSettings()
//            }
//
//        }
//    }
//
//
//    func getNotificationSettings() {
//        UNUserNotificationCenter.current().getNotificationSettings { (settings) in
//            print("Notification settings: \(settings)")
//            guard settings.authorizationStatus == .authorized else {
//                self.goToLaunch()
//                return
//
//            }
//            DispatchQueue.main.async {
//                UIApplication.shared.registerForRemoteNotifications()
//                self.goToLaunch()
//            }
//        }
//    }
    
    func saveDeviceToken(_ deviceToken: Data) {
        // Check if user is logged in
        if let user = Auth.auth().currentUser {
            // Save device token to user's document in Firestore
            let deviceTokenString = deviceToken.reduce("", {$0 + String(format: "%02x", $1)})
            let userRef = Firestore.firestore().collection("users").document(user.uid)
            userRef.updateData(["deviceToken": deviceTokenString]) { (error) in
                if let error = error {
                    print("Error saving device token: \(error.localizedDescription)")
                } else {
                    print("Successfully saved device token for user \(user.uid)")
                }
            }
        } else {
            // Save device token to UserDefaults or Keychain
            let deviceTokenString = deviceToken.reduce("", {$0 + String(format: "%02x", $1)})
            UserDefaults.standard.set(deviceTokenString, forKey: "device_token")
        }
    }

    func goToLaunch() {
        DispatchQueue.main.async {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let next = storyboard.instantiateViewController(withIdentifier: "LaunchVC") as! LaunchViewController
            next.modalPresentationStyle = .fullScreen
            self.present(next, animated: true, completion: nil)
        }
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Handle error
        print("Failed to register for remote notifications with error: \(error)")
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.reduce("", {$0 + String(format: "%02x", $1)})
        print("Device Token: \(token)")
        if let user = Auth.auth().currentUser {
            // Convert token to Data
            let deviceTokenData = token.data(using: .utf8)
            // Save the device token to the user's profile in your database
            saveDeviceToken(deviceTokenData!)
        } else {
            // Save the device token to local storage or in memory
            UserDefaults.standard.set(token, forKey: "device_token")
        }
    }
    
    func checkCameraAccess() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .denied:
            
                AVCaptureDevice.requestAccess(for: .video) { success in
                    if success {
                        print("Permission granted, proceed")
                    } else {
                        DispatchQueue.main.async {
                        print("Denied, request permission from settings")
                        let needLocationView = UIView(frame: CGRect(x: 58, y: 313, width: 274, height: 194))
                        needLocationView.backgroundColor = .white
                        needLocationView.clipsToBounds = true
                        needLocationView.layer.cornerRadius = 14
                        let titleLabel = UILabel(frame: CGRect(x: 105.67, y: 21, width: 63, height: 28))
                        titleLabel.text = "Oops!"
                        titleLabel.textColor = .black
                        titleLabel.font = UIFont.systemFont(ofSize: 21, weight: .semibold)
                        let titleUnderView = UIView(frame: CGRect(x: 92, y: 59, width: 90, height: 1))
                        titleUnderView.backgroundColor = .systemGray6
                        let messageLabel = UILabel(frame: CGRect(x: 15, y: 68, width: 244, height: 56))
                        messageLabel.numberOfLines = 3
                        messageLabel.textColor = .darkGray
                        messageLabel.textAlignment = .center
                        messageLabel.text = "Blueprint is a camera app! To continue, you'll need to allow Camera access in Settings."
                        messageLabel.font = UIFont.systemFont(ofSize: 14)
                        let settingsButton = UIButton(frame: CGRect(x: 57, y: 139, width: 160, height: 40))
                        settingsButton.clipsToBounds = true
                        settingsButton.layer.cornerRadius = 20
                        settingsButton.backgroundColor = UIColor(red: 69/255, green: 65/255, blue: 78/255, alpha: 1.0)
                        settingsButton.setTitle("Settings", for: .normal)
                        settingsButton.setTitleColor(.white, for: .normal)
                        settingsButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
                        settingsButton.addTarget(self, action: #selector(self.goToSettings), for: .touchUpInside)
                        needLocationView.addSubview(titleLabel)
                        needLocationView.addSubview(titleUnderView)
                        needLocationView.addSubview(messageLabel)
                        needLocationView.addSubview(settingsButton)
                        self.view.addSubview(needLocationView)
                    }}}
        case .restricted:
            print("Restricted, device owner must approve")
        case .authorized:
            print("Authorized, proceed")
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { success in
                if success {
                    print("Permission granted, proceed")
                } else {
                    print("Permission denied")
                    let needLocationView = UIView(frame: CGRect(x: 58, y: 313, width: 274, height: 194))
                    needLocationView.backgroundColor = .white
                    needLocationView.clipsToBounds = true
                    needLocationView.layer.cornerRadius = 14
                    let titleLabel = UILabel(frame: CGRect(x: 105.67, y: 21, width: 63, height: 28))
                    titleLabel.text = "Oops!"
                    titleLabel.textColor = .black
                    titleLabel.font = UIFont.systemFont(ofSize: 21, weight: .semibold)
                    let titleUnderView = UIView(frame: CGRect(x: 92, y: 59, width: 90, height: 1))
                    titleUnderView.backgroundColor = .systemGray6
                    let messageLabel = UILabel(frame: CGRect(x: 15, y: 68, width: 244, height: 56))
                    messageLabel.numberOfLines = 3
                    messageLabel.textColor = .darkGray
                    messageLabel.textAlignment = .center
                    messageLabel.text = "Blueprint is a camera app! To continue, you'll need to allow Camera access in Settings."
                    messageLabel.font = UIFont.systemFont(ofSize: 14)
                    let settingsButton = UIButton(frame: CGRect(x: 57, y: 139, width: 160, height: 40))
                    settingsButton.clipsToBounds = true
                    settingsButton.layer.cornerRadius = 20
                    settingsButton.backgroundColor = UIColor(red: 69/255, green: 65/255, blue: 78/255, alpha: 1.0)
                    settingsButton.setTitle("Settings", for: .normal)
                    settingsButton.setTitleColor(.white, for: .normal)
                    settingsButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
                    settingsButton.addTarget(self, action: #selector(self.goToSettings), for: .touchUpInside)
                    needLocationView.addSubview(titleLabel)
                    needLocationView.addSubview(titleUnderView)
                    needLocationView.addSubview(messageLabel)
                    needLocationView.addSubview(settingsButton)
                    self.view.addSubview(needLocationView)
                }
            }
        }
    }
    
    var originalAnchorLikes = Int()
    
    func checkLocationPermission() {
        var authorizationStatus: CLAuthorizationStatus?

        if #available(iOS 14.0, *) {
            authorizationStatus = self.locationManager?.authorizationStatus // CLAuthorizationStatus(rawValue: locationManager?.authorizationStatus().rawValue)
        } else {
            authorizationStatus = CLLocationManager.authorizationStatus()
        }
        if authorizationStatus == .notDetermined {
            locationManager?.requestWhenInUseAuthorization()
        } else {
            let needLocationView = UIView(frame: CGRect(x: 58, y: 313, width: 274, height: 194))
            needLocationView.backgroundColor = .white
            needLocationView.clipsToBounds = true
            needLocationView.layer.cornerRadius = 14
            let titleLabel = UILabel(frame: CGRect(x: 105.67, y: 21, width: 63, height: 28))
            titleLabel.text = "Oops!"
            titleLabel.textColor = .black
            titleLabel.font = UIFont.systemFont(ofSize: 21, weight: .semibold)
            let titleUnderView = UIView(frame: CGRect(x: 92, y: 59, width: 90, height: 1))
            titleUnderView.backgroundColor = .systemGray6
            let messageLabel = UILabel(frame: CGRect(x: 15, y: 68, width: 244, height: 56))
            messageLabel.numberOfLines = 3
            messageLabel.textColor = .darkGray
            messageLabel.textAlignment = .center
            messageLabel.text = "Blueprint is a location-based app! To continue, you'll need to allow Location access in Settings."
            messageLabel.font = UIFont.systemFont(ofSize: 14)
            let settingsButton = UIButton(frame: CGRect(x: 57, y: 139, width: 160, height: 40))
            settingsButton.clipsToBounds = true
            settingsButton.layer.cornerRadius = 20
            settingsButton.backgroundColor = UIColor(red: 69/255, green: 65/255, blue: 78/255, alpha: 1.0)
            settingsButton.setTitle("Settings", for: .normal)
            settingsButton.setTitleColor(.white, for: .normal)
            settingsButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
            settingsButton.addTarget(self, action: #selector(goToSettings), for: .touchUpInside)
            needLocationView.addSubview(titleLabel)
            needLocationView.addSubview(titleUnderView)
            needLocationView.addSubview(messageLabel)
            needLocationView.addSubview(settingsButton)
            view.addSubview(needLocationView)
        }}
    

}


