//
//  LaunchViewController.swift
//  DecorateYourRoom
//
//  Created by Nijel Hunt on 5/27/21.
//  Copyright © 2021 Placenote. All rights reserved.
//

import UIKit
import RealityKit
import SwiftUI
import ARKit
import MultipeerConnectivity
import Foundation
import MultipeerHelper
import FocusEntity
import RoomPlan
import FirebaseAuth
import Combine
import CoreLocation
//import WebKit
import FirebaseFirestore
import ProgressHUD
import SCLAlertView
import GeoFire
import Photos
//import AzureSpatialAnchors
import FirebaseStorage
import Alamofire
import Speech
import AVKit
import JavaScriptCore
import ChatGPTSwift

protocol BlueprintViewControllerDelegate {
    func updateNetworkImg()
    
}

private let anchorNamePrefix = "model-"

// Special dictionary key used to track an unsaved anchor
let unsavedAnchorId = "placeholder-id"

// Colors for the local anchors to indicate status
let readyColor = UIColor.blue.withAlphaComponent(0.6)           // light blue for a local anchor
let savedColor = UIColor.green.withAlphaComponent(0.6)          // green when the cloud anchor was saved successfully
let foundColor = UIColor.yellow.withAlphaComponent(0.6)         // yellow when we successfully located a cloud anchor
let deletedColor = UIColor.black.withAlphaComponent(0.6)        // grey for a deleted cloud anchor
let failedColor = UIColor.red.withAlphaComponent(0.6)

class BlueprintViewController: UIViewController, ARSessionDelegate, UIGestureRecognizerDelegate, CLLocationManagerDelegate, UIPopoverPresentationControllerDelegate, MultipeerHelperDelegate, UITableViewDelegate, UITableViewDataSource {

    
    var locationManager: CLLocationManager?
    
    var delegate: BlueprintViewControllerDelegate?
    
    var sceneManager = SceneManager()
   
    @IBOutlet weak var userGuideBtnTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var closeUserGuideImgView: UIImageView!
    @IBOutlet weak var userGuideBtn: UIButton!
    @IBOutlet weak var styleTableView: UITableView!
    @IBOutlet weak var scanImgView: UIImageView!
    @IBOutlet weak var speechLabelBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var recordSpeechUnderView: UIView!
    @IBOutlet weak var changeInputMethodLabel: UILabel!
    @IBOutlet weak var copilotBtn: UIButton!
    @IBOutlet weak var libraryImageView: UIImageView!
    @IBOutlet weak var composeImgView: UIImageView!
    @IBOutlet weak var buttonStackViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var anchorInfoStackView: UIStackView!
    @IBOutlet weak var shareImgView: UIImageView!
    @IBOutlet weak var anchorCommentsLabel: UILabel!
    @IBOutlet weak var anchorLikesLabel: UILabel!
    @IBOutlet weak var commentImg: UIImageView!
    @IBOutlet weak var heartImg: UIImageView!
    @IBOutlet weak var anchorUserImg: UIImageView!
    @IBOutlet weak var profileImgView: UIImageView!
    @IBOutlet weak var searchImgView: UIImageView!
    @IBOutlet weak var addImgView: UIImageView!
    @IBOutlet weak var buttonStackView: UIStackView!
    @IBOutlet weak var sceneInfoButton: UIButton!
    @IBOutlet weak var wordsBtnTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var cancelWalkthroughButton: UIButton!
    @IBOutlet weak var walkthroughViewLabel: UILabel!
    @IBOutlet weak var walkthroughView: UIView!
    @IBOutlet weak var saveButtonBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var numberOfEditsImg: UIImageView!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var scanBtn: UIButton!
    @IBOutlet weak var trashBtn: UIButton!
    @IBOutlet weak var duplicateBtn: UIButton!
    @IBOutlet weak var removeBtn: UIButton!
    @IBOutlet weak var placementStackView: UIStackView!
    @IBOutlet weak var placementStackBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var confirmBtn: UIButton!
    @IBOutlet weak var likeBtn: UIButton!
    @IBOutlet weak var sceneView: CustomARView!
    @IBOutlet weak var networkBtn: UIButton!
    @IBOutlet weak var toggleBtn: UIButton!
    @IBOutlet weak var networksNearImg: UIImageView!
    @IBOutlet weak var wordsBtn: UIButton!
    @IBOutlet weak var recordAudioImgView: UIImageView!
    @IBOutlet weak var recordedSpeechLabel: UILabel!
    @IBOutlet weak var optionFourBtn: UIButton!
    @IBOutlet weak var optionFiveBtn: UIButton!
    @IBOutlet weak var recordedSpeechTextView: UITextView!
    @IBOutlet weak var optionTwoBtn: UIButton!
    @IBOutlet weak var optionOneBtn: UIButton!
    @IBOutlet weak var optionThreeBtn: UIButton!
    @IBOutlet weak var optionsScrollView: UIScrollView!
    @IBOutlet weak var videoBtn: UIButton!
    
    @StateObject var modelsViewModel = ModelsViewModel()
    
    struct GlobalVariable{
        static var myString = String()
    }
    
    @Published var recentlyPlaced: [Model] = []
    
    var defaultConfiguration: ARWorldTrackingConfiguration {
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
      //  config.geometryQuality = .high
        config.sceneReconstruction = .meshWithClassification
        config.isCollaborationEnabled = true
        
        config.frameSemantics.insert(.personSegmentationWithDepth)
        config.environmentTexturing = .automatic
        return config
    }
    
    var progressView : UIView?
    var progressBar : UIProgressView?
    
    let config = ARWorldTrackingConfiguration()

    let db = Firestore.firestore()
    
    var currentLocation: CLLocation?
    var originalLocation = CLLocation()
    
    var arState: ARState?
    
    struct ModelAnchor {
        var model: ModelEntity
        var anchor: ARAnchor?
    }
    
    var anchorPlaced: ARAnchor?
    
    var modelsConfirmedForPlacement: [ModelAnchor] = []
   
    
    var isVideoMode: Bool = false
    var isTextMode: Bool = false
    var isObjectMode: Bool? = true
    var isScanMode: Bool?
    
    var trashZone: GradientView!
    var shadeView: UIView!
    var resetButton: UIButton!
    
    var keyboardHeight: CGFloat!
    
    var stickyNotes = [StickyNoteEntity]()
    
    var subscription: Cancellable!
    
    let defaults = UserDefaults.standard
    var textNode:SCNNode?
    var textSize:CGFloat = 5
    var textDistance:Float = 15
    let coachingOverlay = ARCoachingOverlayView()
    
    var shareRecognizer = UITapGestureRecognizer()
    var doubleTap = UITapGestureRecognizer()
    var profileRecognizer = UITapGestureRecognizer()
    var textSettingsRecognizer = UITapGestureRecognizer()
    var browseRec = UITapGestureRecognizer()
    var undoTextRecognizer = UITapGestureRecognizer()
    var hideMeshRecognizer = UITapGestureRecognizer()
    
    // Cache for 3D text geometries representing the classification values.
    var modelsForClassification: [ARMeshClassification: ModelEntity] = [:]
    
    var videoNode: VideoNodeSK?
    var videoPlayerCreated = false
    
    var showFeaturePoints = false
    var placementType: ARHitTestResult.ResultType = .featurePoint
    
    var focusEntity: FocusEntity?
    private var modelManager: ModelManager = ModelManager()
    
    var configuration = ARWorldTrackingConfiguration()
    
    var multipeerHelp: MultipeerHelper!

    
   // private var loadedMetaData: LibPlacenote.MapMetadata = LibPlacenote.MapMetadata()
      
    var selectedObject: VirtualObject?
    static var selectedEntityName = ""
    static var selectedEntityID = ""
    var currentConnectedNetwork = "TR5GY49mciaf42wUc8pZ"
    var selectedEntity: ModelEntity?
    var selectedAnchor: AnchorEntity?
    
      var selectedNode: SCNNode?

      /// The object that is tracked for use by the pan and rotation gestures.
      var trackedObject: VirtualObject? {
          didSet {
              guard trackedObject != nil else { return }
              selectedObject = trackedObject
          }
      }
    
    var categoryTableView = UITableView()
    
    var selectedModelURL: URL?
    
    var didTap: Bool?
    
    var networkBtnImg = UIImage(named: "network")
    
    private var modelCollectionView : UICollectionView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupAudioSession()
        checkCameraAccess()
        setupNewUI()
        setupJavaScriptEnvironment()
     //   scanningUI()
        
        styleTableView.delegate = self
        styleTableView.dataSource = self
        styleTableView.register(StyleTableViewCell.self, forCellReuseIdentifier: "StyleTableViewCell")
        
        categoryTableView = UITableView(frame: CGRect(x: 0, y: view.frame.height - 140, width: view.frame.width, height: 140)) // Add this line to create categoryTableView programmatically
        categoryTableView.delegate = self
        categoryTableView.dataSource = self
        categoryTableView.isScrollEnabled = false
        categoryTableView.showsVerticalScrollIndicator = false
        categoryTableView.separatorStyle = .none
        categoryTableView.register(CategoryTableViewCell.self, forCellReuseIdentifier: "CategoryTableViewCell")
        //view.addSubview(categoryTableView)
        
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: "isCreatingNetwork")
        defaults.set(false, forKey: "connectToNetwork")
        defaults.set(false, forKey: "showDesignWalkthrough")
        defaults.set("", forKey: "modelUid")
        defaults.set("", forKey: "blueprintId")
        guard ARWorldTrackingConfiguration.isSupported else {
            fatalError("""
                ARKit is not available on this device. For apps that require ARKit
                for core functionality, use the `arkit` key in the key in the
                `UIRequiredDeviceCapabilities` section of the Info.plist to prevent
                the app from installing. (If the app can't be installed, this error
                can't be triggered in a production scenario.)
                In apps where AR is an additive feature, use `isSupported` to
                determine whether to show UI for launching AR experiences.
            """) // For details, see https://developer.apple.com/documentation/arkit
        }
       
        
        let swipeDown = UISwipeGestureRecognizer(target: self, action: #selector(down))
        swipeDown.direction = .down
        let swipeUp = UISwipeGestureRecognizer(target: self, action: #selector(up))
        swipeUp.direction = .up
        
        sceneView.addGestureRecognizer(swipeDown)
        sceneView.addGestureRecognizer(swipeUp)
        
        imagePicker.delegate = self
        
        networkBtn.setImage(UIImage(systemName: "network"), for: .normal)
        videoBtn.layer.cornerRadius = 22.5
        //  backImg.layer.borderWidth = 1
        // backImg.layer.borderColor = UIColor.lightGray.cgColor
        videoBtn.layer.shadowRadius = 4
        videoBtn.layer.shadowOpacity = 0//.95
        videoBtn.layer.shadowColor = UIColor.black.cgColor
        //note.view?.layer.cornerRadius = 5
        videoBtn.layer.masksToBounds = false
        videoBtn.layer.shadowOffset = CGSize(width: 0, height: 3.0)
        
        copilotBtn.layer.cornerRadius = 22.5
        //  backImg.layer.borderWidth = 1
        // backImg.layer.borderColor = UIColor.lightGray.cgColor
        copilotBtn.layer.shadowRadius = 4
        copilotBtn.layer.shadowOpacity = 0//.95
        copilotBtn.layer.shadowColor = UIColor.black.cgColor
        //note.view?.layer.cornerRadius = 5
        copilotBtn.layer.masksToBounds = false
        copilotBtn.layer.shadowOffset = CGSize(width: 0, height: 3.0)
        
        //   wordsBtn.layer.cornerRadius = 19
        //  backImg.layer.borderWidth = 1
        // backImg.layer.borderColor = UIColor.lightGray.cgColor
        wordsBtn.layer.shadowRadius = 4
        wordsBtn.layer.shadowOpacity = 0.95
        wordsBtn.layer.shadowColor = UIColor.black.cgColor
        //note.view?.layer.cornerRadius = 5
        wordsBtn.layer.masksToBounds = false
        wordsBtn.layer.shadowOffset = CGSize(width: 0, height: 3.0)
//
//        feedbackControl = addFeedbackButton()
//        feedbackControl.backgroundColor = .clear
//        feedbackControl.setTitleColor(.yellow, for: .normal)
//        feedbackControl.contentHorizontalAlignment = .left
       // feedbackControl.isHidden = true
        
     //   layoutButtons()
        
        
        progressView = UIView(frame: CGRect(x: 0, y: 95, width: UIScreen.main.bounds.width, height: 30))
        progressView?.backgroundColor = UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 0.90)

        progressBar = UIProgressView(frame: CGRect(x: 20, y: 13, width: UIScreen.main.bounds.width - 40, height: 10))
     //   progressBar?.heightAnchor = 25
        progressBar?.progressViewStyle = .default
        progressBar?.progressTintColor = .systemGreen
        progressBar?.autoresizesSubviews = true
        progressBar?.clearsContextBeforeDrawing = true
        
        progressView?.addSubview(progressBar!)
     //   sceneView.addSubview(progressView!)
        anchorSettingsImg.isHidden = true
       // self.progressView?.isHidden = true
        
        let supportLiDAR = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
        guard supportLiDAR else {
            print("LiDAR isn't supported here")
            setup()
//            if UITraitCollection.current.userInterfaceStyle == .light {
//                browseTableView.backgroundColor = UIColor(red: 241/255, green: 244/255, blue: 244/255, alpha: 1.0)
//                //topview.backgroundColor = UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 0.90)
//            } else {
//                browseTableView.backgroundColor = UIColor(red: 34/255, green: 34/255, blue: 34/255, alpha: 1.0)
//                searchField.overrideUserInterfaceStyle = .light
//            }
            //checkWalkthrough()
            return
        }
        setupLidar()
        
       // startSession()
     //   checkWalkthrough()
        //   let searchTap = UITapGestureRecognizer(target: self, action: #selector(searchAction(_:)))
        let searchTap = UITapGestureRecognizer(target: self, action: #selector(editAlert))
        addButton.layer.cornerRadius = 26
        let largeConfig = UIImage.SymbolConfiguration(pointSize: 19, weight: .bold, scale: .large)
        //   let largeBoldDoc = UIImage(systemName: "plus.circle.fill", withConfiguration: largeConfig)
        let largeBoldDoc = UIImage(systemName: "plus", withConfiguration: largeConfig)
        addButton.setImage(largeBoldDoc, for: .normal)
        addButton.backgroundColor = UIColor.systemBlue
        addButton.tintColor = .white
        addButton.layer.shadowRadius = 4
        addButton.layer.shadowOpacity = 0.95
        addButton.layer.shadowColor = UIColor.black.cgColor
        //note.view?.layer.cornerRadius = 5
        addButton.layer.masksToBounds = false
        addButton.layer.shadowOffset = CGSize(width: 0, height: 3.3)
        if Auth.auth().currentUser?.uid != nil {
            sceneView.addSubview(addButton)
        }
        addButton.addGestureRecognizer(searchTap)
        
        sceneInfoButton.clipsToBounds = true
        sceneInfoButton.layer.cornerRadius = 4
        sceneInfoButton.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMinXMinYCorner]
        
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(appMovedToBackground), name: UIApplication.willResignActiveNotification, object: nil)
        
        anchorUserImg.layer.borderColor = UIColor.white.cgColor
        anchorUserImg.layer.borderWidth = 0.8
   
        let likeAction = UITapGestureRecognizer(target: self, action: #selector(like))
        heartImg.isUserInteractionEnabled = true
        heartImg.addGestureRecognizer(likeAction)
    
        
        let libraryAction = UITapGestureRecognizer(target: self, action: #selector(goToLibrary))
        libraryImageView.isUserInteractionEnabled = true
        libraryImageView.addGestureRecognizer(libraryAction)
        
        let recordAction = UITapGestureRecognizer(target: self, action: #selector(recordAudio))
        recordAudioImgView.isUserInteractionEnabled = true
        recordAudioImgView.addGestureRecognizer(recordAction)
        
        let connectAction = UITapGestureRecognizer(target: self, action: #selector(selectStyle))
        styleTableView.isUserInteractionEnabled = true
   //     styleTableView.addGestureRecognizer(connectAction)
        
        let cancelAction = UITapGestureRecognizer(target: self, action: #selector(cancelUserGuideAction))
        closeUserGuideImgView.isUserInteractionEnabled = true
        closeUserGuideImgView.addGestureRecognizer(cancelAction)
        
     //   self.showStyles()
    }
    
    let walkthroughLabel = UILabel(frame: CGRect(x: 25, y: 550, width: UIScreen.main.bounds.width - 50, height: 80))
    var circle =  UIView() // UIView(frame: CGRect(x: 9, y: 45, width: 50, height: 50))
    var circle2 =  UIView()
    
    private func setupAudioSession() {
            //enable other applications music to play while quizView
            let options = AVAudioSession.CategoryOptions.mixWithOthers
            let mode = AVAudioSession.Mode.default
            let category = AVAudioSession.Category.playback
            try? AVAudioSession.sharedInstance().setCategory(category, mode: mode, options: options)
            //---------------------------------------------------------------------------------
            try? AVAudioSession.sharedInstance().setActive(true)
        }
    
    
    
    var continueWalkthroughButton = UIButton()
    var continueNetworkWalkthroughButton = UIButton()
    
    func setupNewUI(){
     //   //topview.isHidden = true
        addButton.isHidden = true
        if defaults.bool(forKey: "finishedCreateWalkthrough") == false{
            self.buttonStackViewBottomConstraint.constant = -140
            self.continueWalkthroughButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 130, y: 5, width: 110, height: 35))
            self.continueWalkthroughButton.backgroundColor = .systemBlue// UIColor(red: <#T##CGFloat#>, green: <#T##CGFloat#>, blue: <#T##CGFloat#>, alpha: <#T##CGFloat#>)
            self.continueWalkthroughButton.setTitle("Continue", for: .normal)
            self.continueWalkthroughButton.setTitleColor(.white, for: .normal)
            self.continueWalkthroughButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
            self.continueWalkthroughButton.layer.cornerRadius = 6
            self.continueWalkthroughButton.clipsToBounds = true
            self.continueWalkthroughButton.isUserInteractionEnabled = true
         //   self.continueWalkthroughButton.addTarget(self, action: #selector(continueWalkthrough), for: .touchUpInside)
          //  self.view.addSubview(self.continueWalkthroughButton)
        }
        let scanTap = UITapGestureRecognizer(target: self, action: #selector(editAlert)) //editAlert
        scanImgView.addGestureRecognizer(scanTap)
        
        let searchTap = UITapGestureRecognizer(target: self, action: #selector(searchUI))
        searchImgView.addGestureRecognizer(searchTap)
        
        let profileTap = UITapGestureRecognizer(target: self, action: #selector(goToUserProfile)) //goToUserProfile
        profileImgView.addGestureRecognizer(profileTap)
        
        let networkTap = UITapGestureRecognizer(target: self, action: #selector(editAlert))
        addImgView.addGestureRecognizer(networkTap)
        
        let createTap = UITapGestureRecognizer(target: self, action: #selector(showStyles))//goToCapturedRoom
        composeImgView.addGestureRecognizer(createTap)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
        print("Received memory warning.")

        // Release any unneeded memory here
        // For example, you can release large images or other data that's not currently in use
 //       heavyImage = nil

        // You can also release any objects that have been retained by properties in the class
        // For example, if you have a reference to an observer, you should remove it
  //      NotificationCenter.default.removeObserver(observer)
    }
    
    @objc func shareFile(fileURL: URL) {
        let activityViewController = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        present(activityViewController, animated: true, completion: nil)
    }
    
    var modelUid = ""
    var blueprintId = ""
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
      //  layoutButtons()
    }
    
    @objc func appMovedToBackground() {
        print("App moved to background!")
        if Auth.auth().currentUser?.uid != nil {
            FirestoreManager.getUser(Auth.auth().currentUser?.uid ?? "") { user in
                if user?.currentConnectedNetworkID != "" || user?.currentConnectedNetworkID != nil {
                    let docRef = self.db.collection("users").document(Auth.auth().currentUser?.uid ?? "")
                    docRef.updateData([
                        "currentConnectedNetworkID": ""
                    ])
                }
            }
        }
        for id in currentSessionAnchorIDs {
            let docRef = self.db.collection("sessionAnchors").document(id)
            docRef.delete()

        }
        self.sceneView.scene.anchors.removeAll()
        if self.videoPlayer != nil && self.videoPlayer.rate != 0 {
            self.videoPlayer.pause()
        }
        
        self.entityName.removeFromSuperview()
        self.entityProfileBtn.removeFromSuperview()
        self.buttonStackView.isHidden = false
        self.anchorUserImg.isHidden = true
        self.anchorInfoStackView.isHidden = true
        self.anchorSettingsImg.isHidden = true
        self.placementStackView.isHidden = true
        self.entityName.isHidden = true
        self.entityProfileBtn.isHidden = true
//        self.checkCameraAccess()
//        self.chec
        self.networksNear()
    //    self.focusEntity = FocusEntity(on: sceneView, focus: .classic)
    }
    
    func checkWalkthrough(){
        if defaults.bool(forKey: "finishedDesignWalkthrough") == false {
            self.userGuideBtn.setTitle("HOW TO: DESIGN A BLUEPRINT", for: .normal)
            defaults.set(true, forKey: "showDesignWalkthrough")
            self.userGuideBtn.isHidden = false
            self.closeUserGuideImgView.isHidden = false
            self.networkBtn.isHidden = true
            self.networksNearImg.isHidden = true
            placementStackBottomConstraint.constant = 55
            saveButtonBottomConstraint.constant = -5
            return
        }
        
        else {
            self.userGuideBtn.isHidden = true
            self.closeUserGuideImgView.isHidden = true
            self.networkBtn.isHidden = false
            self.networksNearImg.isHidden = false
            return
        }

    }
    
    var currentSessionAnchorIDs = [String]()
    var continueTaps = 0
    var continueNetworkTaps = 0
    
    @objc func cancelUserGuideAction(){
        let defaults = UserDefaults.standard
        if userGuideBtn.titleLabel?.text == "HOW TO: DESIGN A BLUEPRINT" {
            let alertController = UIAlertController(title: "Skip Walkthrough?", message: "Feel free to skip this if you already know how to design a Blueprint. All user guides are also located within your Settings.", preferredStyle: .alert)
            
            // action to dismiss the view controller and lose the generated art
            let purchaseAction = UIAlertAction(title: "Skip", style: .default, handler: { (_) in
                defaults.set(true, forKey: "finishedDesignWalkthrough")
                defaults.set(false, forKey: "showDesignWalkthrough")

                self.userGuideBtn.isHidden = true
                self.closeUserGuideImgView.isHidden = true
                self.editInstructions.removeFromSuperview()
                self.circle.removeFromSuperview()
                self.circle2.removeFromSuperview()

                self.networkBtn.isHidden = false
                self.networksNearImg.isHidden = false
                self.networkBtn.isUserInteractionEnabled = true
                self.composeImgView.isUserInteractionEnabled = true
                self.profileImgView.isUserInteractionEnabled = true
              
            })
            
            // action to cancel and stay on the current view controller
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: { (_) in
                
            })
           
            // add the actions to the alert controller
            alertController.addAction(purchaseAction)
            alertController.addAction(cancelAction)
            
            // present the alert to the user
            self.present(alertController, animated: true, completion: nil)
        } else if userGuideBtn.titleLabel?.text == "CONNECT TO NEARBY BLUEPRINT" {
            
            let alertController = UIAlertController(title: "Skip Walkthrough?", message: "Feel free to skip this if you already know how to connect to nearby Blueprints. All user guides are also located within your Settings.", preferredStyle: .alert)
            
            // action to dismiss the view controller and lose the generated art
            let purchaseAction = UIAlertAction(title: "Skip", style: .default, handler: { (_) in
                defaults.set(true, forKey: "finishedConnectWalkthrough")

                self.userGuideBtn.isHidden = true
                self.closeUserGuideImgView.isHidden = true
                self.editInstructions.removeFromSuperview()
                self.circle.removeFromSuperview()
                self.circle2.removeFromSuperview()

                self.networkBtn.isHidden = false
                self.networksNearImg.isHidden = false
                self.scanImgView.isUserInteractionEnabled = true
                self.composeImgView.isUserInteractionEnabled = true
                self.profileImgView.isUserInteractionEnabled = true
                if self.num >= 1 {
                    self.editInstructions = UILabel(frame: CGRect(x: 15, y: 135, width: UIScreen.main.bounds.width - 30, height: 50))
                    self.editInstructions.textAlignment = .center
                    self.editInstructions.text = "There is a Blueprint near your location. Explore and connect with it!" // "There is a Blueprint near your location. Do you want to connect?"
                    self.editInstructions.backgroundColor = .white
                    self.editInstructions.textColor = .black
                    self.editInstructions.clipsToBounds = true
                    self.editInstructions.layer.cornerRadius = 12
                   // self.editInstructions.padding = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
                    self.editInstructions.numberOfLines = 2
                    self.editInstructions.font = UIFont.systemFont(ofSize: 16, weight: .medium)
                    self.view.addSubview(self.editInstructions)
                }
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
    }
    
    @IBAction func userGuideAction(_ sender: Any) {
       if userGuideBtn.titleLabel?.text == "HOW TO: DESIGN A BLUEPRINT" {
            circle.frame = CGRect(x: buttonStackView.frame.minX - 13.5, y: buttonStackView.frame.minY - 13.5, width: 55, height: 55)
            circle.backgroundColor = .clear
            circle.layer.cornerRadius = 27.5
            circle.clipsToBounds = true
            circle.layer.borderColor = UIColor.systemBlue.cgColor
            circle.layer.borderWidth = 4
            circle.isUserInteractionEnabled = false
            circle.alpha = 1.0
            sceneView.addSubview(circle)
            
            circle2.frame = CGRect(x: circle.frame.midX + 55, y: buttonStackView.frame.minY - 13.5, width: 55, height: 55)
            circle2.backgroundColor = .clear
            circle2.layer.cornerRadius = 27.5
            circle2.clipsToBounds = true
            circle2.layer.borderColor = UIColor.systemBlue.cgColor
            circle2.layer.borderWidth = 4
            circle2.isUserInteractionEnabled = false
            circle2.alpha = 1.0
            sceneView.addSubview(circle2)
            
          
            UIView.animate(withDuration: 0.85, delay: 0, options: [.curveEaseInOut, .repeat, .autoreverse], animations: {
                self.circle.alpha = 0.1
                self.circle2.alpha = 0.1
            })
            self.editInstructions.removeFromSuperview()
            self.networkBtn.isUserInteractionEnabled = false
            self.composeImgView.isUserInteractionEnabled = true
            self.searchImgView.isUserInteractionEnabled = true
            self.profileImgView.isUserInteractionEnabled = false
            self.editInstructions = UILabel(frame: CGRect(x: 15, y: scanImgView.frame.minY - 120, width: UIScreen.main.bounds.width - 30, height: 75))
            self.editInstructions.textAlignment = .center
            self.editInstructions.text = "Use our AI-powered design features or explore Blueprint's Marketplace for the ideal 3D content for your space with these two buttons!" // "There is a Blueprint near your location. Do you want to connect?"
            self.editInstructions.backgroundColor = .white
            self.editInstructions.textColor = .black
            self.editInstructions.clipsToBounds = true
            self.editInstructions.layer.cornerRadius = 12
            // self.editInstructions.padding = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
            self.editInstructions.numberOfLines = 3
            self.editInstructions.font = UIFont.systemFont(ofSize: 16, weight: .medium)
            self.view.addSubview(self.editInstructions)
        }
    }
    //    @objc func continueWalkthrough(){
//        continueTaps += 1
//        let defaults = UserDefaults.standard
//        if defaults.bool(forKey: "finishedWalkthrough") == false {
////            if self.continueTaps == 1 {
////                defaults.set(true, forKey: "newSecond")
////                self.walkthroughViewLabel.text = "3 of 8"
////                self.walkthroughLabel.frame = CGRect(x: 35, y: 300, width: UIScreen.main.bounds.width - 70, height: 100)
////                self.walkthroughLabel.numberOfLines = 0
//////                self.walkthroughLabel.text = "Tap the search button in the top left corner to search for digital assets"
////                self.walkthroughLabel.text = "To create a Blueprint Network click the left plus button. This makes it so you can save digital content in place at any indoor location."
////                circle.frame = CGRect(x: (UIScreen.main.bounds.width / 2) - 108, y: UIScreen.main.bounds.height - 151, width: 50, height: 50)
////
////                circle.layer.cornerRadius = (circle.frame.height) / 2
////
////             //  circle.frame =   CGRect(x: searchBtn.frame.minX - 5, y: searchBtn.frame.minY - 5, width: 50, height: 50)
////           circle.backgroundColor = .clear
////          // circle.layer.cornerRadius = 25
////           circle.clipsToBounds = true
////           circle.layer.borderColor = UIColor.systemBlue.cgColor
////           circle.layer.borderWidth = 4
////           circle.isUserInteractionEnabled = false
////           circle.alpha = 1.0
////                UIView.animate(withDuration: 0.85, delay: 0, options: [.curveEaseInOut, .repeat, .autoreverse], animations: {
////                    self.circle.alpha = 0.1
////                       })
////
////            }
//
//            if self.continueTaps == 1 {
//                defaults.set(true, forKey: "newSecond")
//                self.walkthroughViewLabel.text = "3 of 9"
//                self.walkthroughLabel.frame = CGRect(x: 50, y: 360, width: UIScreen.main.bounds.width - 100, height: 65)
//                self.walkthroughLabel.numberOfLines = 0
////                self.walkthroughLabel.text = "Tap the search button in the top left corner to search for digital assets"
//                self.walkthroughLabel.text = "Click Create to use AI to generate your own images and 3D models."
//                circle.frame = CGRect(x: (UIScreen.main.bounds.width / 2) - 107.5, y: UIScreen.main.bounds.height - 151, width: 50, height: 50)
//
//                circle.layer.cornerRadius = (circle.frame.height) / 2
//
//             //  circle.frame =   CGRect(x: searchBtn.frame.minX - 5, y: searchBtn.frame.minY - 5, width: 50, height: 50)
//           circle.backgroundColor = .clear
//          // circle.layer.cornerRadius = 25
//           circle.clipsToBounds = true
//           circle.layer.borderColor = UIColor.systemBlue.cgColor
//           circle.layer.borderWidth = 4
//           circle.isUserInteractionEnabled = false
//           circle.alpha = 1.0
//                UIView.animate(withDuration: 0.85, delay: 0, options: [.curveEaseInOut, .repeat, .autoreverse], animations: {
//                    self.circle.alpha = 0.1
//                       })
//            }
//
//            else if self.continueTaps == 2 {
//                defaults.set(true, forKey: "newThird")
//                self.walkthroughViewLabel.text = "4 of 9"
//                self.walkthroughLabel.frame = CGRect(x: 50, y: 300, width: UIScreen.main.bounds.width - 100, height: 65)
//                self.walkthroughLabel.numberOfLines = 0
////                self.walkthroughLabel.text = "Tap the search button in the top left corner to search for digital assets"
//                self.walkthroughLabel.text = "Click Profile to view your profile or to create your Blueprint account."
//                circle.frame = CGRect(x: (UIScreen.main.bounds.width / 2) + 58, y: UIScreen.main.bounds.height - 151, width: 50, height: 50)
//
//                circle.layer.cornerRadius = (circle.frame.height) / 2
//
//             //  circle.frame =   CGRect(x: searchBtn.frame.minX - 5, y: searchBtn.frame.minY - 5, width: 50, height: 50)
//           circle.backgroundColor = .clear
//          // circle.layer.cornerRadius = 25
//           circle.clipsToBounds = true
//           circle.layer.borderColor = UIColor.systemBlue.cgColor
//           circle.layer.borderWidth = 4
//           circle.isUserInteractionEnabled = false
//           circle.alpha = 1.0
//                UIView.animate(withDuration: 0.85, delay: 0, options: [.curveEaseInOut, .repeat, .autoreverse], animations: {
//                    self.circle.alpha = 0.1
//                       })
//            }
//
//            else if self.continueTaps == 3 {
//                defaults.set(true, forKey: "newFourth")
//                self.walkthroughViewLabel.text = "5 of 9"
//                self.walkthroughLabel.frame = CGRect(x: 32.5, y: 400, width: UIScreen.main.bounds.width - 65, height: 110)
//                self.walkthroughLabel.numberOfLines = 0
////                self.walkthroughLabel.text = "Tap the search button in the top left corner to search for digital assets"
//                self.walkthroughLabel.text = "The network icon will show how many networks are within range. Very similar to a Wi-Fi network, you’ll be able to connect to any Network and experience the digital content within them."
//                circle.frame = CGRect(x: (UIScreen.main.bounds.width - 73), y: 71, width: 50, height: 50)
//
//                circle.layer.cornerRadius = (circle.frame.height) / 2
//
//             //  circle.frame =   CGRect(x: searchBtn.frame.minX - 5, y: searchBtn.frame.minY - 5, width: 50, height: 50)
//           circle.backgroundColor = .clear
//          // circle.layer.cornerRadius = 25
//           circle.clipsToBounds = true
//           circle.layer.borderColor = UIColor.systemBlue.cgColor
//           circle.layer.borderWidth = 4
//           circle.isUserInteractionEnabled = false
//           circle.alpha = 1.0
//                UIView.animate(withDuration: 0.85, delay: 0, options: [.curveEaseInOut, .repeat, .autoreverse], animations: {
//                    self.circle.alpha = 0.1
//                       })
//            }
//            else if self.continueTaps == 4 {
//                defaults.set(true, forKey: "newFifth")
//                self.walkthroughViewLabel.text = "6 of 9"
//                self.walkthroughLabel.frame = CGRect(x: 35, y: 500, width: UIScreen.main.bounds.width - 120, height: 68)
//                self.walkthroughLabel.numberOfLines = 0
////                self.walkthroughLabel.text = "Tap the search button in the top left corner to search for digital assets"
//                self.walkthroughLabel.text = "To browse content you've creations and collected, click the library button."
//                circle.frame = CGRect(x: (UIScreen.main.bounds.width - 72), y: 130, width: 50, height: 50)
//
//                circle.layer.cornerRadius = (circle.frame.height) / 2
//
//             //  circle.frame =   CGRect(x: searchBtn.frame.minX - 5, y: searchBtn.frame.minY - 5, width: 50, height: 50)
//           circle.backgroundColor = .clear
//          // circle.layer.cornerRadius = 25
//           circle.clipsToBounds = true
//           circle.layer.borderColor = UIColor.systemBlue.cgColor
//           circle.layer.borderWidth = 4
//           circle.isUserInteractionEnabled = false
//           circle.alpha = 1.0
//                UIView.animate(withDuration: 0.85, delay: 0, options: [.curveEaseInOut, .repeat, .autoreverse], animations: {
//                    self.circle.alpha = 0.1
//                       })
//            }
//            else if self.continueTaps == 5 {
//                defaults.set(true, forKey: "newSixth")
//                self.walkthroughViewLabel.text = "7 of 9"
//                self.walkthroughLabel.frame = CGRect(x: 60, y: 500, width: UIScreen.main.bounds.width - 120, height: 55)
//                self.walkthroughLabel.numberOfLines = 0
////                self.walkthroughLabel.text = "Tap the search button in the top left corner to search for digital assets"
//                self.walkthroughLabel.text = "To add messages or text to a location, click to ABC button."
//                circle.frame = CGRect(x: (UIScreen.main.bounds.width - 73), y: 184.5, width: 50, height: 50)
//
//                circle.layer.cornerRadius = (circle.frame.height) / 2
//
//             //  circle.frame =   CGRect(x: searchBtn.frame.minX - 5, y: searchBtn.frame.minY - 5, width: 50, height: 50)
//           circle.backgroundColor = .clear
//          // circle.layer.cornerRadius = 25
//           circle.clipsToBounds = true
//           circle.layer.borderColor = UIColor.systemBlue.cgColor
//           circle.layer.borderWidth = 4
//           circle.isUserInteractionEnabled = false
//           circle.alpha = 1.0
//                UIView.animate(withDuration: 0.85, delay: 0, options: [.curveEaseInOut, .repeat, .autoreverse], animations: {
//                    self.circle.alpha = 0.1
//                       })
//            }
//
//            else if self.continueTaps == 6 {
//                defaults.set(true, forKey: "newSeventh")
//
//                self.walkthroughViewLabel.text = "8 of 9"
//            //    self.continueWalkthroughButton.setTitle("Finish", for: .normal)
//                self.walkthroughLabel.frame = CGRect(x: 60, y: 500, width: UIScreen.main.bounds.width - 120, height: 55)
//                self.walkthroughLabel.numberOfLines = 0
////                self.walkthroughLabel.text = "Tap the search button in the top left corner to search for digital assets"
//                self.walkthroughLabel.text = "To add photos or videos to a location, click to video button."
//                circle.frame = CGRect(x: (UIScreen.main.bounds.width - 73), y: 244.5, width: 50, height: 50)
//
//                circle.layer.cornerRadius = (circle.frame.height) / 2
//
//             //  circle.frame =   CGRect(x: searchBtn.frame.minX - 5, y: searchBtn.frame.minY - 5, width: 50, height: 50)
//           circle.backgroundColor = .clear
//          // circle.layer.cornerRadius = 25
//           circle.clipsToBounds = true
//           circle.layer.borderColor = UIColor.systemBlue.cgColor
//           circle.layer.borderWidth = 4
//           circle.isUserInteractionEnabled = false
//           circle.alpha = 1.0
//                UIView.animate(withDuration: 0.85, delay: 0, options: [.curveEaseInOut, .repeat, .autoreverse], animations: {
//                    self.circle.alpha = 0.1
//                       })
//            }
//
//            else if self.continueTaps == 7 {
//                defaults.set(true, forKey: "newSeventh")
//
//                self.walkthroughViewLabel.text = "9 of 9"
//                self.continueWalkthroughButton.removeFromSuperview()// .setTitle("Finish", for: .normal)
//                self.walkthroughLabel.frame = CGRect(x: 60, y: 500, width: UIScreen.main.bounds.width - 120, height: 75)
//                self.walkthroughLabel.numberOfLines = 0
////                self.walkthroughLabel.text = "Tap the search button in the top left corner to search for digital assets"
//                self.walkthroughLabel.text = "Now tap the search icon and add your first piece of digital content to the world!"
//                circle.frame = CGRect(x: (UIScreen.main.bounds.width / 2) - 25, y: UIScreen.main.bounds.height - 151, width: 50, height: 50)
//
//                circle.layer.cornerRadius = (circle.frame.height) / 2
//
//             //  circle.frame =   CGRect(x: searchBtn.frame.minX - 5, y: searchBtn.frame.minY - 5, width: 50, height: 50)
//           circle.backgroundColor = .clear
//          // circle.layer.cornerRadius = 25
//           circle.clipsToBounds = true
//           circle.layer.borderColor = UIColor.systemBlue.cgColor
//           circle.layer.borderWidth = 4
//           circle.isUserInteractionEnabled = false
//           circle.alpha = 1.0
//                self.buttonStackView.isUserInteractionEnabled = true
//                UIView.animate(withDuration: 0.85, delay: 0, options: [.curveEaseInOut, .repeat, .autoreverse], animations: {
//                    self.circle.alpha = 0.1
//                       })
//            }
////            else if self.continueTaps == 7 {
////                defaults.set(true, forKey: "finishedWalkthrough")
////                self.walkthroughView.removeFromSuperview()
////                self.circle.removeFromSuperview()
////                self.walkthroughLabel.removeFromSuperview()
////                self.buttonStackView.isUserInteractionEnabled = true
////                self.videoBtn.isUserInteractionEnabled = true
////                self.wordsBtn.isUserInteractionEnabled = true
////                self.networkBtn.isUserInteractionEnabled = true
////                self.buttonStackViewBottomConstraint.constant = -87
////            }
//        }
//
//    }
    
    
    var needLocationView = UIView()
    
    func setup(){
        
        sceneView.session.delegate = self
        
       // sceneView.session.delegate = Coordinator
        
        setupCoachingOverlay()
        
        focusEntity = FocusEntity(on: sceneView, focus: .classic)
        
     //   sceneView.environment.sceneUnderstanding.options = []
        
      //  networkBtnImg?.image = UIImage(named: "guitarpbr")
       // arView.environment.lighting.
        entityProfileBtn.isUserInteractionEnabled = false
        entityProfileBtn.isHidden = true
        // Turn on occlusion from the scene reconstruction's mesh.
     //   sceneView.environment.sceneUnderstanding.options.insert(.occlusion)
        
        // Turn on physics for the scene reconstruction's mesh.
  //      sceneView.environment.sceneUnderstanding.options.insert(.physics)
        
    //    sceneView.environment.sceneUnderstanding.options.insert(.receivesLighting)
        
    //    sceneView.environment.sceneUnderstanding.options.insert(.collision)

        // Display a debug visualization of the mesh.
      //  sceneView.debugOptions.insert(.showSceneUnderstanding)
       
        // Manually configure what kind of AR session to run since
        // ARView on its own does not turn on mesh classification.
   //     sceneView.automaticallyConfigureSession = false
        configuration.planeDetection = [.horizontal, .vertical]
      //  configuration.sceneReconstruction = .mesh
        configuration.isCollaborationEnabled = true
      //  configuration.frameSemantics.insert(.personSegmentationWithDepth)
      //  configuration.environmentTexturing = .automatic
        sceneView.session.run(configuration)
        holdGesture = UILongPressGestureRecognizer(target: self, action: #selector(didLongPress(_:)))
        holdGesture.delegate = self
        sceneView.addGestureRecognizer(holdGesture)
        
        profileRecognizer = UITapGestureRecognizer(target: self, action: #selector(goToProfile(_:)))
        profileRecognizer.delegate = self
    //    entityProfileBtn.addGestureRecognizer(profileRecognizer)
        
        shareRecognizer = UITapGestureRecognizer(target: self, action: #selector(share(_:)))
        shareRecognizer.delegate = self
        // Do any additional setup after loading the view.
        
        
        hideMeshRecognizer = UITapGestureRecognizer(target: self, action: #selector(hideMesh(_:)))
        hideMeshRecognizer.delegate = self
        toggleBtn.addGestureRecognizer(hideMeshRecognizer)
        
//        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(hideUI(_:)))
//        doubleTap.numberOfTapsRequired = 2
//        doubleTap.delegate = self
     //   sceneView.addGestureRecognizer(doubleTap)
        if defaults.bool(forKey: "headsUp") == false {
            needLocationView = UIView(frame: CGRect(x: 58, y: 313, width: 274, height: 194))
            needLocationView.backgroundColor = .white
            needLocationView.clipsToBounds = true
            needLocationView.layer.cornerRadius = 14
            let titleLabel = UILabel(frame: CGRect(x: 85.67, y: 21, width: 103, height: 28))
            titleLabel.text = "Heads Up!"
            titleLabel.textColor = .black
            titleLabel.font = UIFont.systemFont(ofSize: 21, weight: .semibold)
            let titleUnderView = UIView(frame: CGRect(x: 92, y: 59, width: 90, height: 1))
            titleUnderView.backgroundColor = .systemGray4
            let messageLabel = UILabel(frame: CGRect(x: 15, y: 68, width: 244, height: 56))
            messageLabel.numberOfLines = 3
            messageLabel.textColor = .darkGray
            messageLabel.textAlignment = .center
            messageLabel.text = "Blueprint is better with LiDAR! This phone model does not support this feature, but you can still use the app."
            messageLabel.font = UIFont.systemFont(ofSize: 14)
            let settingsButton = UIButton(frame: CGRect(x: 57, y: 139, width: 160, height: 40))
            settingsButton.clipsToBounds = true
            settingsButton.layer.cornerRadius = 20
            settingsButton.backgroundColor = UIColor(red: 69/255, green: 65/255, blue: 78/255, alpha: 1.0)
            settingsButton.setTitle("OK", for: .normal)
            settingsButton.setTitleColor(.white, for: .normal)
            settingsButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
            settingsButton.addTarget(self, action: #selector(self.headsUp), for: .touchUpInside)
            needLocationView.addSubview(titleLabel)
            needLocationView.addSubview(titleUnderView)
            needLocationView.addSubview(messageLabel)
            needLocationView.addSubview(settingsButton)
            self.view.addSubview(needLocationView)
            //self.topView.isUserInteractionEnabled = false
            self.addButton.isUserInteractionEnabled = false
            self.videoBtn.isUserInteractionEnabled = false
            self.wordsBtn.isUserInteractionEnabled = false
            self.walkthroughView.isUserInteractionEnabled = false
            self.sceneView.isUserInteractionEnabled = false
            self.buttonStackView.isUserInteractionEnabled = false
            self.networkBtn.isUserInteractionEnabled = false
        }
    }
    
    @objc func headsUp(){
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "headsUp")
        self.needLocationView.removeFromSuperview()
        //self.topView.isUserInteractionEnabled = true
        self.addButton.isUserInteractionEnabled = true
        self.videoBtn.isUserInteractionEnabled = true
        self.wordsBtn.isUserInteractionEnabled = true
        self.walkthroughView.isUserInteractionEnabled = true
        self.sceneView.isUserInteractionEnabled = true
        self.buttonStackView.isUserInteractionEnabled = true
        self.networkBtn.isUserInteractionEnabled = true
    }

    var holdGesture = UILongPressGestureRecognizer()
  
    static private let auth = Auth.auth()
    
    func setupLidar(){
        sceneView.session.delegate = self
       // sceneView.debugOptions.insert(.showStatistics)
        setupCoachingOverlay()
      //  sceneView.sess
        focusEntity = FocusEntity(on: sceneView, focus: .classic)
        
        sceneView.environment.sceneUnderstanding.options = []
        
      //  networkBtnImg?.image = UIImage(named: "guitarpbr")
       // arView.environment.lighting.
        entityProfileBtn.isUserInteractionEnabled = false
        entityProfileBtn.isHidden = true
        // Turn on occlusion from the scene reconstruction's mesh.
        sceneView.environment.sceneUnderstanding.options.insert(.occlusion)
        
        // Turn on physics for the scene reconstruction's mesh.
      //  sceneView.environment.sceneUnderstanding.options.insert(.physics)
        
        sceneView.environment.sceneUnderstanding.options.insert(.receivesLighting)
        
       // sceneView.environment.sceneUnderstanding.options.insert(.collision)
        
//        sceneView.renderOptions = [
//                    .disableHDR,
//                    .disableDepthOfField,
//                    .disableMotionBlur,
//                    .disableFaceMesh,
//                    .disablePersonOcclusion,
//                    .disableCameraGrain
//                ]
        
        // Display a debug visualization of the mesh.
      //  sceneView.debugOptions.insert(.showSceneUnderstanding)
        if !connectedToNetwork {
            self.copilotBtn.isHidden = true
            self.videoBtn.isHidden = true
            self.wordsBtn.isHidden = true
            self.libraryImageView.isHidden = true
        //    self.copilotBtn.isHidden = true
            self.networksNearImg.transform = CGAffineTransform(scaleX: 1.15, y: 1.15)
            // make the button grow to twice its original size
            self.networkBtn.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
//                self.networkBtn.frame.size.height = self.networkBtn.frame.size.height * 2
//                self.networkBtn.frame.size.width = self.networkBtn.frame.size.width * 2
//
//                // adjust the button's x,y coordinates so it appears to stay in place
//            self.networkBtn.frame.origin.x = self.networkBtn.frame.origin.x - (self.networkBtn.frame.size.width / 1)
//            self.networkBtn.frame.origin.y = self.networkBtn.frame.origin.y - (self.networkBtn.frame.size.height / 1)
//            let largeConfig = UIImage.SymbolConfiguration(pointSize: 26, weight: .regular, scale: .large)
//            //   let largeBoldDoc = UIImage(systemName: "plus.circle.fill", withConfiguration: largeConfig)
//            let largeBoldDoc = UIImage(systemName: "network", withConfiguration: largeConfig)
//            self.networkBtn.setImage(largeBoldDoc, for: .normal)
            self.buttonStackViewBottomConstraint.constant = -100
        }
        // Manually configure what kind of AR session to run since
        // ARView on its own does not turn on mesh classification.
        sceneView.automaticallyConfigureSession = false
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.sceneReconstruction = .meshWithClassification
     //   configuration.isCollaborationEnabled = true
        configuration.frameSemantics.insert(.personSegmentationWithDepth)
     //   configuration.environmentTexturing = .automatic
        if #available(iOS 16.0, *) {
            if let hiResFormat = ARWorldTrackingConfiguration.recommendedVideoFormatFor4KResolution {
                configuration.videoFormat = hiResFormat
            }
        } else {
            // Fallback on earlier versions
        }
        sceneView.session.run(configuration)
        
        // NEW
        
        setupMultipeer()

        
        // Prevent the screen from being dimmed to avoid interrupting the AR experience.
        UIApplication.shared.isIdleTimerDisabled = true
        
        holdGesture = UILongPressGestureRecognizer(target: self, action: #selector(didLongPress(_:)))
        holdGesture.delegate = self
        sceneView.addGestureRecognizer(holdGesture)
        
        profileRecognizer = UITapGestureRecognizer(target: self, action: #selector(goToProfile(_:)))
        profileRecognizer.delegate = self
    //    entityProfileBtn.addGestureRecognizer(profileRecognizer)
        
        shareRecognizer = UITapGestureRecognizer(target: self, action: #selector(share(_:)))
        shareRecognizer.delegate = self
//        shareImg.addGestureRecognizer(shareRecognizer)
        // Do any additional setup after loading the view.
        
        
        hideMeshRecognizer = UITapGestureRecognizer(target: self, action: #selector(hideMesh(_:)))
        hideMeshRecognizer.delegate = self
        toggleBtn.addGestureRecognizer(hideMeshRecognizer)
        
     //   let doubleTap = UITapGestureRecognizer(target: self, action: #selector(connectedNetworkUI(_:)))
        doubleTap = UITapGestureRecognizer(target: self, action: #selector(removeAllModels(_:)))
        doubleTap.numberOfTapsRequired = 2
        doubleTap.delegate = self
        sceneView.addGestureRecognizer(doubleTap)
    }
    
    let blueprintName = "F26B869C-3942-4D91-BA3A-081A1B0F7186-Mes.usdz"
    
    var modelVertices: [SIMD3<Float>] = []
    
    @objc func selectStyle(){
        if Auth.auth().currentUser?.uid != nil {
            let alertController = UIAlertController(title: "Subscribe to Access Style", message: "Premium styles, 3D content and textures require being subscribed to Blueprint Pro.", preferredStyle: .alert)
            let saveAction = UIAlertAction(title: "Subscribe", style: .default, handler: { (_) in
                self.goToSubscription()
                
            })
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: { (_) in
                self.cancelAIAction()
            })
            alertController.addAction(saveAction)
            alertController.addAction(cancelAction)
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    @objc func goToSubscription(){
        if let viewController = self.storyboard?.instantiateViewController(
            withIdentifier: "SubscriptionVC") {
            viewController.modalPresentationStyle = .fullScreen
            self.present(viewController, animated: true)
        }
    }
    
    @objc func downloadBlueprint(){
        var blueprintResult: ModelEntity?
        FirebaseStorageHelper.asyncDownloadToFilesystem(relativePath: "blueprints/\(blueprintName ?? "")") { localUrl in
            self.cancellable = ModelEntity.loadModelAsync(contentsOf: localUrl).sink(receiveCompletion: { loadCompletion in
                switch loadCompletion {
                case .failure(let error):
                    print("Unable to load modelEntity for \(self.modelName). Error: \(error.localizedDescription)")

                case .finished:
                    break
                }
            }, receiveValue: { roomEntity in
                // Set result to the loaded model entity
                blueprintResult = roomEntity

              //  self.currentEntity = modelEntity
                
                self.getVerticesOfRoom(entity: roomEntity, roomEntity.transform.matrix)

                    // Get the min and max X, Y and Z positions of the room
                    var minVertex = SIMD3<Float>(Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude)
                    var maxVertex = SIMD3<Float>(-Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude)
                for vertex in self.modelVertices {
                     if vertex.x < minVertex.x { minVertex.x = vertex.x }
                     if vertex.y < minVertex.y { minVertex.y = vertex.y }
                     if vertex.z < minVertex.z { minVertex.z = vertex.z }
                     if vertex.x > maxVertex.x { maxVertex.x = vertex.x }
                     if vertex.y > maxVertex.y { maxVertex.y = vertex.y }
                     if vertex.z > maxVertex.z { maxVertex.z = vertex.z }
                    }

                    // Compose the corners of the floor
                    let upperLeftCorner: SIMD3<Float> = SIMD3<Float>(minVertex.x, minVertex.y, minVertex.z)
                    let lowerLeftCorner: SIMD3<Float> = SIMD3<Float>(minVertex.x, minVertex.y, maxVertex.z)
                    let lowerRightCorner: SIMD3<Float> = SIMD3<Float>(maxVertex.x, minVertex.y, maxVertex.z)
                    let upperRightCorner: SIMD3<Float> = SIMD3<Float>(maxVertex.x, minVertex.y, minVertex.z)

                    // Create the floor's ModelEntity
                    let floorPositions: [SIMD3<Float>] = [upperLeftCorner, lowerLeftCorner, lowerRightCorner, upperRightCorner]
                    var floorMeshDescriptor = MeshDescriptor(name: "floor")
                    floorMeshDescriptor.positions = MeshBuffers.Positions(floorPositions)
                    // Positions should be specified in CCWISE order
                    floorMeshDescriptor.primitives = .triangles([0, 1, 2, 2, 3, 0])
                    let simpleMaterial = SimpleMaterial(color: .gray, isMetallic: false)
                    let floorModelEntity = ModelEntity(mesh: try! .generate(from: [floorMeshDescriptor]), materials: [simpleMaterial])
                 //   guard let floorModelEntity = floorModelEntity else {
                 //    return
                 //   }

                
                    // Add the floor as a child of the room
                roomEntity.addChild(floorModelEntity)
                self.currentEntity = roomEntity
                let anchor =  self.focusEntity?.anchor //AnchorEntity(plane: .any)// // AnchorEntity(world: [0,-0.2,0])
                print(anchor)
                // anchor?.scale = [1.2,1.0,1.0]
                anchor?.addChild(self.currentEntity)
                self.sceneView.scene.addAnchor(anchor!)
                self.modelPlacementUI()
/*
                //self.placeEntity(model: self.currentEntity)
                let entityBounds = self.currentEntity.visualBounds(relativeTo: nil) // Get the bounds of the RoomPlan scan Entity.
                let width = entityBounds.extents.x + 0.025 // Slightly extend the width of the "floor" past the model, adjust to your preference.
                let height = Float(0.002) // Set the "height" of the floor, or its thickness, to your preference.
                let depth = entityBounds.extents.z + 0.0125 // Set the length/depth of the floor slightly past the model, adjust to your preference.

                let boxResource = MeshResource.generateBox(size: SIMD3<Float>(width, height, depth))
                let material = SimpleMaterial(color: .white, roughness: 0, isMetallic: true)
                let floorEntity = ModelEntity(mesh: boxResource, materials: [material])

                let yCenter = (entityBounds.center.y * 100) - 1.0 // Set the offset of the floor slightly from the mode, adjust to your preference.
                floorEntity.scale = [100.0, 100.0, 100.0] // Scale the model by a factor of 100, as noted in the [release notes](https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-16-release-notes) for working with RoomPlan entities.
                floorEntity.position = [entityBounds.center.x * 100, yCenter, entityBounds.center.z * 100]
                self.currentEntity.addChild(floorEntity)
                self.currentEntity.generateCollisionShapes(recursive: true)
                self.sceneView.installGestures([.translation, .rotation, .scale], for: self.currentEntity)
                let anchor =  self.focusEntity?.anchor //AnchorEntity(plane: .any)// // AnchorEntity(world: [0,-0.2,0])
                print(anchor)
                // anchor?.scale = [1.2,1.0,1.0]
                anchor?.addChild(self.currentEntity)
//                let scale = model?.scale
//                print("\(scale) is scale")
                self.currentEntity.scale = [Float(0.2), Float(0.2), Float(0.2)]
                self.sceneView.scene.addAnchor(anchor!)
                self.modelPlacementUI()*/
            })
        }
        
        
    }
    
    var alertView = UIView()
    var xImageView = UIImageView()
    
    func showNearbyBlueprintAlert(){
        alertView = UIView(frame: CGRect(x: 20, y: 130, width: UIScreen.main.bounds.width - 40, height: 120))
        alertView.clipsToBounds = true
        alertView.layer.cornerRadius = 12
        alertView.backgroundColor = .lightGray
        
        let imageView = UIImageView(frame: CGRect(x: 12, y: 12, width: 25, height: 25))
        let largeConfig = UIImage.SymbolConfiguration(pointSize: 17, weight: .medium, scale: .small)
        //   let largeBoldDoc = UIImage(systemName: "plus.circle.fill", withConfiguration: largeConfig)
        let largeBoldDoc = UIImage(systemName: "network", withConfiguration: largeConfig)
        imageView.image = largeBoldDoc
        imageView.backgroundColor = .systemBlue
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .white
        imageView.layer.cornerRadius = 5
        alertView.addSubview(imageView)
        
        let blueprintLabel = UILabel(frame: CGRect(x: 45, y: 15, width: 70, height: 20))
        blueprintLabel.text = "Blueprint"
        blueprintLabel.textColor = .darkGray
        blueprintLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        alertView.addSubview(blueprintLabel)
        
        let nowLabel = UILabel(frame: CGRect(x: alertView.frame.maxX - 62, y: 15.5, width: 30, height: 16))
        nowLabel.text = "now"
        nowLabel.textColor = .darkGray
        nowLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        alertView.addSubview(nowLabel)
        
        let titleLabel = UILabel(frame: CGRect(x: 12, y: 46, width: 170, height: 18))
        titleLabel.text = "Available Blueprint"
        titleLabel.textColor = .black
        titleLabel.font = UIFont.systemFont(ofSize: 17, weight: .bold)
        alertView.addSubview(titleLabel)
        
        let subtitleLabel = UILabel(frame: CGRect(x: 12, y: 66, width: 320, height: 43))
        subtitleLabel.text = "'\(self.nearbyBlueprintName)' is an available Blueprint nearby."
        subtitleLabel.numberOfLines = 2
        subtitleLabel.textColor = .black
        subtitleLabel.font = UIFont.systemFont(ofSize: 17, weight: .regular)
        alertView.addSubview(subtitleLabel)
        
        xImageView = UIImageView(frame: CGRect(x: alertView.frame.minX - 10, y: alertView.frame.minY - 12.5, width: 30, height: 30))
       
        xImageView.image = UIImage(systemName: "xmark.circle.fill")
        xImageView.contentMode = .scaleAspectFit
        xImageView.tintColor = .white
      //  xImageView.backgroundColor = .white
        xImageView.isUserInteractionEnabled = true
        
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(viewNetworks))
        alertView.addGestureRecognizer(tap)
        
        let tap1 = UITapGestureRecognizer(target: self, action: #selector(closeNearbyBlueprintAlert))
        xImageView.addGestureRecognizer(tap1)
        
        view.addSubview(alertView)
        view.addSubview(xImageView)
        
//        alertView.animate(withDuration: 0.7, delay: 0, options: [.curveLinear],
//                       animations: {
//                        self.center.y += self.bounds.height
//                        self.layoutIfNeeded()
//
//        },  completion: {(_ completed: Bool) -> Void in
//        self.isHidden = true
//            })
    }
    
    func getVerticesOfRoom(entity: Entity, _ transformChain: simd_float4x4) {
      let modelEntity = entity as? ModelEntity
      guard let modelEntity = modelEntity else {
       // If the Entity isn't a ModelEntity, skip it and check if we can get the vertices of its children
       let updatedTransformChain = entity.transform.matrix * transformChain
       for currEntity in entity.children {
        getVerticesOfRoom(entity: currEntity, updatedTransformChain)
       }
       return
      }

      // Below we get the vertices of the ModelEntity
      let updatedTransformChain = modelEntity.transform.matrix * transformChain

      // Iterate over all instances
      var instancesIterator = modelEntity.model?.mesh.contents.instances.makeIterator()
      while let currInstance = instancesIterator?.next() {
       // Get the model of the current instance
       let currModel = modelEntity.model?.mesh.contents.models[currInstance.model]

       // Iterate over the parts of the model
       var partsIterator = currModel?.parts.makeIterator()
       while let currPart = partsIterator?.next() {
        // Iterate over the positions of the part
        var positionsIterator = currPart.positions.makeIterator()
        while let currPosition = positionsIterator.next() {
         // Transform the position and store it
         let transformedPosition = updatedTransformChain * SIMD4<Float>(currPosition.x, currPosition.y, currPosition.z, 1.0)
         modelVertices.append(SIMD3<Float>(transformedPosition.x, transformedPosition.y, transformedPosition.z))
        }
       }
      }

      // Check if we can get the vertices of the children of the ModelEntity
      for currEntity in modelEntity.children {
       getVerticesOfRoom(entity: currEntity, updatedTransformChain)
      }
     }
  

//    private func layoutButton(_ button: UIButton, top: Double, lines: Double) {
//        let wideSize = sceneView.bounds.size.width - 20.0
//        button.frame = CGRect(x: 10.0, y: top, width: Double(wideSize), height: lines * 40)
//        if (lines > 1) {
//            button.titleLabel?.lineBreakMode = NSLineBreakMode.byWordWrapping
//        }
//    }
//

    private func distance(_ a: [NSNumber], _ b: [NSNumber]) -> Float {
        if a.count != 3 || b.count != 3 {
            return 0
        }
        let dx = a[0].floatValue - b[0].floatValue
        let dy = a[1].floatValue - b[1].floatValue
        let dz = a[2].floatValue - b[2].floatValue
        return sqrt(dx * dx + dy * dy + dz * dz)
    }
    
    private let _jsContext = JSContext()!
    
    // MARK: - JavaScript

    private func setupJavaScriptEnvironment() {
        // Define print() function for logging
        let printFn: @convention(block) (String) -> Void = { message in print(message) }
        _jsContext.setObject(printFn, forKeyedSubscript: "print" as NSString)
        
//        // Define a block that calls your searchEntity function
//        let searchEntityFn: @convention(block) (String) -> String? = { query in
//            return self.searchEntity(query: query)
//        }
//        // Add the block to the _jsContext with the key "searchEntity"
//        _jsContext.setObject(searchEntityFn, forKeyedSubscript: "searchEntity" as NSString)
        
//        // Define a block that calls your searchEntity function
//        let searchEntityFn: @convention(block) (String, @escaping (String?) -> Void) -> Void = { query, completion in
//            print("searchEntity called with query: \(query)")
//            self.searchEntity(query: query) { result in
//                completion(result)
//            }
//        }
//        // Add the block to the _jsContext with the key "searchEntity"
//        _jsContext.setObject(searchEntityFn, forKeyedSubscript: "searchEntity" as NSString)
        
        // Define a block that calls your downloadEntity function and returns its result
        let downloadEntityFn: @convention(block) (String) -> JSValue? = { modelID in
            if let entity = self.downloadEntity(modelID: "2mG9Q1zMR6Avye5JZHFX") {
                return JSValue(object: entity, in: self._jsContext)
            } else {
                return nil
            }
        }

        // Add the block to the _jsContext with the key "downloadEntity"
        _jsContext.setObject(downloadEntityFn, forKeyedSubscript: "downloadEntity" as NSString)
        
//        // Define a block that calls your downloadEntity function and returns its result
//        let downloadEntityFn: @convention(block) (String, @escaping (JSValue?) -> Void) -> Void = { modelID, completion in
//            self.downloadEntity(modelID: modelID) { entity in
//                if let entity = entity {
//                    completion(JSValue(object: entity, in: self._jsContext))
//                } else {
//                    completion(nil)
//                }
//            }
//        }
//
//        // Add the block to the _jsContext with the key "downloadEntity"
//        _jsContext.setObject(downloadEntityFn, forKeyedSubscript: "downloadEntity" as NSString)

        
        // Define a block that calls your placeEntity function and passes it a ModelEntity value
        // takes in modelEntity downloaded from downloadEntityFn and places it in the correct location
        let placeEntityFn: @convention(block) (JSValue) -> Void = { model in
            if let model = model.toObjectOf(ModelEntity.self) as? ModelEntity {
                self.placeEntity(model: model)
            }
        }

        // Add the block to the _jsContext with the key "placeEntity"
        _jsContext.setObject(placeEntityFn, forKeyedSubscript: "placeEntity" as NSString)


        // ChatGPT often insists on using a distance() function even when we tell it not to
        let distanceFn: @convention(block) ([NSNumber], [NSNumber]) -> Float = { return self.distance($0, $1) }
        _jsContext.setObject(distanceFn, forKeyedSubscript: "distance" as NSString)
    }
    
    /// Wraps the user prompt in more context about the system to help ChatGPT generate usable code. - will need to change based off functions and needs of Blueprint
    public func augmentPrompt(prompt: String) -> String {
        return """

    Assume:
    - A function searchEntity() exists that takes only a string describing the object (for example, 'TV', 'carpet', or 'chair'). The return value is the first object's ID in the results array that it returns from our database.
    - Objects returned by downloadEntity() have only three properties, each of them an array of length 3: 'position' (the position), 'scale' (the scale), and 'euler' (rotation specified as Euler angles in degrees).
    - Objects returned by downloadEntity() must have their properties initialized after the object is created.
    - Each plane has two properties: 'center', the center position of the plane, and 'size', the size of the plane in each dimension. Each of these is an array of numbers of length 3.
    - A global variable 'cameraPosition' containing the camera position, which is the user position, as a 3-element float array.
    - The function placeEntity() places the downloaded object on the plane that makes the most sense for the description of the object. For example - a mounted TV will be placed on a vertical wall.

    Write Javascript code for the user that:

    \(prompt)

    The code must obey the following constraints:
    - Is wrapped in an anonymous function that is then executed.
    - Does not define any new functions.
    - Defines all variables and constants used.
    - Does not call any functions besides those given above and those defined by the base language spec.
    """
    }
    
    private var _cameraTransform: simd_float4x4?

    public func runCode(code: String) {
        _jsContext.evaluateScript(code)
    }

    private func updateGlobalVariables(frame: ARFrame) {
        _cameraTransform = frame.camera.transform
        let cameraPosition = frame.camera.transform.position
        _jsContext.setObject([ cameraPosition.x, cameraPosition.y, cameraPosition.z ], forKeyedSubscript: "cameraPosition" as NSString)
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
            
        }
    
    }
    
    func textViewDidChange(_ textView: UITextView) {
        let count = textView.text.count
      //  textCountRemainingLabel.text = String(400 - count)

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
    
    func transcribeSpeechData(_ data: Data, completion: @escaping (Result<String, Error>) -> Void) {
        let apiKey = "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"
        //Error Here - need correct URL
        let url = "https://api.openai.com/v1/audio/transcriptions"
        let headers: HTTPHeaders = [
            "Content-Type": "audio/wav",
            "Authorization": "Bearer \(apiKey)"
        ]
        
        AF.upload(data, to: url, headers: headers)
            .validate()
            .responseDecodable(of: TranscriptionResponse.self) { response in
                switch response.result {
                case .success(let transcriptionResponse):
                    completion(.success(transcriptionResponse.transcription))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
    }

    struct TranscriptionResponse: Decodable {
        let transcription: String
    }
    
   // let audioRecorder = SpeechRecorder()
    
    let whisperManager = WhisperManager()

    let speechRecognizer        = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    var recognitionRequest      : SFSpeechAudioBufferRecognitionRequest?
    var recognitionTask         : SFSpeechRecognitionTask?
    let audioEngine             = AVAudioEngine()
    
    var promptLabel = UILabel()
    var cancelImg = UIImageView()
    
    @objc func closeNearbyBlueprintAlert(){
        self.alertView.removeFromSuperview()
        self.xImageView.removeFromSuperview()
    }
    
    @objc func cancelAIAction(){
        networkBtn.isHidden = false
        self.networksNear()
        
        self.checkWalkthrough()
       // libraryImageView.isHidden = false
      //  wordsBtn.isHidden = false
       // videoBtn.isHidden = false
        recordAudioImgView.isHidden = true
        recordSpeechUnderView.isHidden = true
        recordedSpeechLabel.isHidden = true
        changeInputMethodLabel.isHidden = true
      //  copilotBtn.isHidden = false
        placementStackView.isHidden = true
        backArrowImg.isHidden = true
        buttonStackView.isHidden = false
        optionsScrollView.isHidden = true
        self.removeOptionImages()
        self.styleTableView.isHidden = true
        self.skipBtn.isHidden = true
        self.categoryTableView.isHidden = true
        self.overView.isHidden = true
      //  self.scanImgView.isHidden = false
        self.optionTwoBtn.layer.borderColor = UIColor.clear.cgColor
        self.optionThreeBtn.layer.borderColor = UIColor.clear.cgColor
        self.optionFourBtn.layer.borderColor = UIColor.clear.cgColor
        self.optionFiveBtn.layer.borderColor = UIColor.clear.cgColor
        if defaults.bool(forKey: "showDesignWalkthrough") == true {
            
            self.editInstructions.removeFromSuperview()
           
            self.editInstructions = UILabel(frame: CGRect(x: 15, y: scanImgView.frame.minY - 120, width: UIScreen.main.bounds.width - 30, height: 75))
            self.editInstructions.textAlignment = .center
            self.editInstructions.text = "Use our AI-powered design features or explore Blueprint's Marketplace for the ideal 3D content for your space with these two buttons!" // "There is a Blueprint near your location. Do you want to connect?"
            self.editInstructions.backgroundColor = .white
            self.editInstructions.textColor = .black
            self.editInstructions.clipsToBounds = true
            self.editInstructions.layer.cornerRadius = 12
            // self.editInstructions.padding = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
            self.editInstructions.numberOfLines = 3
            self.editInstructions.font = UIFont.systemFont(ofSize: 16, weight: .medium)
            self.view.addSubview(self.editInstructions)
        } else {
            self.editInstructions.isHidden = true

        }
        promptLabel.isHidden = true
        cancelImg.isHidden = true
//        if audioEngine.isRunning {
//            self.audioEngine.stop()
//            self.recognitionRequest?.endAudio()
//        }
        self.networkBtn.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        self.networksNearImg.transform = CGAffineTransform(scaleX: 1.15, y: 1.15)
        self.recordSpeechUnderView.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
        self.recordAudioImgView.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
        self.sceneView.addGestureRecognizer(doubleTap)
        self.sceneView.addGestureRecognizer(holdGesture)
    }
    
    @IBAction func copilotAction(_ sender: Any) {
        self.setupSpeech()
        networkBtn.isHidden = true
        libraryImageView.isHidden = true
        wordsBtn.isHidden = true
        videoBtn.isHidden = true
        recordAudioImgView.isHidden = false
        recordAudioImgView.tintColor = UIColor(red: 216/255, green: 71/255, blue: 56/255, alpha: 1.0)
        recordSpeechUnderView.isHidden = false
        recordedSpeechLabel.isHidden = false
        recordedSpeechLabel.text = "Hold to Speak"
        recordedSpeechLabel.backgroundColor = .clear
        recordedSpeechLabel.textColor = .white
        changeInputMethodLabel.isHidden = false
        copilotBtn.isHidden = true
        buttonStackView.isHidden = true
        networksNearImg.isHidden = true

        promptLabel = UILabel(frame: CGRect(x: (view.frame.width - 250) / 2, y: 70, width: 250, height: 80))
        promptLabel.numberOfLines = 2
        promptLabel.textColor = .white
        promptLabel.tintColor = .white
        promptLabel.text = "How would you like to design your space?"
        promptLabel.textAlignment = .center
        promptLabel.font = UIFont.systemFont(ofSize: 21, weight: .semibold)
        view.addSubview(promptLabel)

        cancelImg = UIImageView(frame: CGRect(x: 22, y: 58, width: 22, height: 22))
        cancelImg.tintColor = .white
        cancelImg.isUserInteractionEnabled = true
        cancelImg.clipsToBounds = true
        cancelImg.contentMode = .scaleAspectFit
        let smallConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold, scale: .medium)
        let smallBoldDoc = UIImage(systemName: "xmark", withConfiguration: smallConfig)
        cancelImg.image = smallBoldDoc
        let tap = UITapGestureRecognizer(target: self, action: #selector(cancelAIAction))
        cancelImg.addGestureRecognizer(tap)
        view.addSubview(cancelImg)
        changeInputMethodLabel.isUserInteractionEnabled = true
        let show = UITapGestureRecognizer(target: self, action: #selector(showKeyboard))
        changeInputMethodLabel.addGestureRecognizer(show)
        
        
//        guard let path = Bundle.main.path(forResource: "forestwaterfall", ofType: "mp4") else { return }
//        let videoUrl = URL(fileURLWithPath: path)
//        let playerItem = AVPlayerItem(url: videoUrl)
//
//        let videoPlayer = AVPlayer(playerItem: playerItem)
//        self.videoPlayer = videoPlayer
//
//        let videoMaterial = VideoMaterial(avPlayer: videoPlayer)
//        let mesh = MeshResource.generateBox(width: 1.6, height: 0.2, depth: 1.0)   //.generatePlane(width: 1.5, depth: 1)
//        let videoPlane = ModelEntity(mesh: mesh, materials: [videoMaterial])
//       // videoPlane.name = "Giannis"
//
//        // let anchor = AnchorEntity(anchor: focusEntity?.currentPlaneAnchor as! ARAnchor)
//        let anchor = AnchorEntity(plane: .any) // AnchorEntity(anchor: focusEntity?.currentPlaneAnchor as! ARAnchor) // focusEntity?.currentPlaneAnchor//
//        print(anchor)
//        anchor.addChild(videoPlane)
//
//
//        videoPlane.generateCollisionShapes(recursive: true)
//
//       // videoPlane.
//        //
//        sceneView.installGestures([.translation, .rotation, .scale], for: videoPlane)
//
//       // sceneView.scene.addAnchor(anchor!)
//        sceneView.scene.anchors.append(anchor)
//
//        videoPlayer.play()
//
//        NotificationCenter.default.addObserver(self, selector: #selector(loopVideo), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: playerItem)
        
//        let vc = ScanViewController()
//        navigationController!.pushViewController(vc, animated: true)
    }
    
    @objc func showKeyboard(){
        messageView.addSubview(messageTextView)
  //      messageView.addSubview(messageButtonUnderline)
        messageView.addSubview(postMessageButton)
   //     messageView.addSubview(cancel)
        messageView.addSubview(messageButtonView)
        view.addSubview(messageView)
    }
    
    @objc func recordAudio(){
        if audioEngine.isRunning {
            self.audioEngine.stop()
            self.recognitionRequest?.endAudio()
       //     self.searchImgView.isUserInteractionEnabled = false
           // self.btnStart.setTitle("Start Recording", for: .normal)
        } else {
            self.recordTapped()
            UIView.animate(withDuration: 0.2) {
                self.recordedSpeechLabel.frame.origin.y -= 7
                self.speechLabelBottomConstraint.constant = 135
                self.recordSpeechUnderView.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
                self.recordAudioImgView.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
                        }
           // self.btnStart.setTitle("Stop Recording", for: .normal)
        }
    }
    
//    func searchEntity(query: String, completion: @escaping (String?) -> Void) {
//        let capQuery = query.capitalized
//        FirestoreManager.searchModels(queryStr: "P") { searchedModels in
//            if let firstModel = searchedModels.first {
//                // Set result to the id of the first model in the searchedModels array
//                let result = firstModel.id
//                self.modelUid = result ?? ""
//                completion(result)
//            } else {
//                completion(nil)
//            }
//        }
//    }
    
    
//    func searchEntity(query: String) -> String? {
//        var result: String?
//        let capQuery = query.capitalized
//        FirestoreManager.searchModels(queryStr: "P") { searchedModels in
//            if let firstModel = searchedModels.first {
//                // Set result to the id of the first model in the searchedModels array
//                result = firstModel.id
//                self.modelUid = result ?? ""
//                //return result
//            }
//        }
//        //need completion handler, this is returning before searchModels is returning a value
//        return result
//    }
    
    func searchEntity(query: String, completion: @escaping (String?) -> Void) {
        let capQuery = query.capitalized
        FirestoreManager.searchModels(queryStr: capQuery) { searchedModels in
            if let firstModel = searchedModels.first {
                // Set result to the id of the first model in the searchedModels array
                let result = firstModel.id
                self.modelUid = result
                completion(result)
            } else {
                completion(nil)
            }
        }
    }

    
    //get result of searchEntity (id of model) and use that modelID  to download the correct entity to be used within the AR view

//    func downloadEntity(modelID: String, completion: @escaping (ModelEntity?) -> Void) {
//        FirestoreManager.getModel(modelID) { model in
//            let modelName = model?.modelName
//            print("\(modelName ?? "") is model name")
//
//            FirebaseStorageHelper.asyncDownloadToFilesystem(relativePath: "models/\(modelName ?? "")") { localUrl in
//                self.cancellable = ModelEntity.loadModelAsync(contentsOf: localUrl).sink(receiveCompletion: { loadCompletion in
//                    switch loadCompletion {
//                    case .failure(let error):
//                        print("Unable to load modelEntity for \(modelName). Error: \(error.localizedDescription)")
//                        completion(nil)
//                    case .finished:
//                        break
//                    }
//                }, receiveValue: { modelEntity in
//                    self.currentEntity = modelEntity
//
//                    self.placeEntity(model: self.currentEntity)
//
//                    // Call the completion handler with the loaded model entity
//                    completion(modelEntity)
//                })
//            }
//        }
//    }
    
    // Modify your downloadEntity function to return a ModelEntity value
    func downloadEntity(modelID: String) -> ModelEntity? {
        var result: ModelEntity?
        FirestoreManager.getModel(modelID) { model in
            let modelName = model?.modelName
            print("\(modelName ?? "") is model name")

            FirebaseStorageHelper.asyncDownloadToFilesystem(relativePath: "models/\(modelName ?? "")") { localUrl in
                self.cancellable = ModelEntity.loadModelAsync(contentsOf: localUrl).sink(receiveCompletion: { loadCompletion in
                    switch loadCompletion {
                    case .failure(let error):
                        print("Unable to load modelEntity for \(modelName). Error: \(error.localizedDescription)")

                    case .finished:
                        break
                    }
                }, receiveValue: { modelEntity in
                    // Set result to the loaded model entity
                    result = modelEntity

                    self.currentEntity = modelEntity

                    self.placeEntity(model: self.currentEntity)
                })
            }
        }
        //need completion handler - result is returning before asyncDownload is finished
        return result
    }

    
    //Anything we dont have in our database - if ChatGPT cant find it, from artwork to textures for flooring - will be created using this function.
//    func generateImage(prompt: String) async -> UIImage? {
//
//
//        // after generating image, upload the object to the database
//
//        // it will then have to be sized & placed at correct location
//        // placeEntity func
//    }
    
    // After finding or generating content, scale the entity and size it correctly based on user prompt.
    func scaleEntity(modelId: String) {
        // based on prompt scale the object
        
    }
    
    // After finding or generating content, rotate the entity correctly based on user prompt.
    func rotateEntity(modelId: String) {
        // based on prompt rotate the object
        
    }
        public typealias Vector3 = SIMD3<Float>
        public typealias Vector4 = SIMD4<Float>
    
    // takes in modelEntity downloaded from downloadEntityFn and places it in the correct location based on user prompt.
    func placeEntity(model: ModelEntity) {
        let planeAnchor = AnchorEntity(.plane([.vertical, .horizontal],
                                              classification: [.floor, .ceiling],
                                              minimumBounds: [0.7, 0.7]))
        print("\(planeAnchor.position) is planeAnchor position")
        planeAnchor.addChild(model)
        self.sceneView.scene.addAnchor(planeAnchor)
    }
//    func placeEntity() {
//        let planeAnchor = AnchorEntity(.plane([.vertical, .horizontal],
//                                              classification: [.floor, .ceiling],
//                                              minimumBounds: [0.7, 0.7]))
//        print("\(planeAnchor.position) is planeAnchor position")
//        planeAnchor.addChild(self.currentEntity)
//        self.sceneView.scene.addAnchor(planeAnchor)
//    }

    
    func setupSpeech() {

        //self.btnStart.isEnabled = false
        self.speechRecognizer?.delegate = self

        SFSpeechRecognizer.requestAuthorization { (authStatus) in

            var isButtonEnabled = false

            switch authStatus {
            case .authorized:
                isButtonEnabled = true

            case .denied:
                isButtonEnabled = false
                print("User denied access to speech recognition")

            case .restricted:
                isButtonEnabled = false
                print("Speech recognition restricted on this device")

            case .notDetermined:
                isButtonEnabled = false
                print("Speech recognition not yet authorized")
            @unknown default:
                fatalError()
            }

            OperationQueue.main.addOperation() {
                self.recordAudioImgView.isUserInteractionEnabled = isButtonEnabled
            }
        }
    }
    
//    var optionsIDArray = ["kfryesPpvBmlhhVTohMz", "6CwMVBiRJob46q4gR5VV", "5nonCjQT4zYsX8hWTPi6", "AV8N12VCVJUQi24aoMR1", "uz9qRIM24cMmYXXte0CV"] //xbWdRPZeD3nQB4TozEXR
    
    var optionsIDArray = ["2mG9Q1zMR6Avye5JZHFX", "dRzbalWkKFzABlD5MTwl", "fMSGm7hwCQh2Aq9WLjFH", "4rIGwSVijh77o4qj1uRt", "bDohDSgk5IlFTkd5ODSx"] //xbWdRPZeD3nQB4TozEXR
    
    func showOptions(){
        
        ProgressHUD.dismiss()
     //   self.removeCloseButton()
        // print("modelEntity for \(self.name) has been loaded.")
        self.changeInputMethodLabel.isHidden = true
      //  self.promptLabel.isHidden = true
      //  self.cancelImg.isHidden = true
        self.recordedSpeechLabel.isHidden = true
        self.recordSpeechUnderView.isHidden = true
        self.recordAudioImgView.isHidden = true
        self.recordSpeechUnderView.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
        self.recordAudioImgView.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
        
        self.optionsScrollView.isHidden = false
        self.view.isUserInteractionEnabled = true
        self.sceneView.addGestureRecognizer(doubleTap)
        self.sceneView.addGestureRecognizer(holdGesture)
        
        self.promptCount += 1
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.downloadDemoContent))
        optionsScrollView.addGestureRecognizer(tap)
    }
    
    
    @IBAction func optionOneAction(_ sender: Any) {
        self.changedOptions = true
        sceneView.scene.removeAnchor(currentAnchor)
        self.optionOneBtn.layer.borderWidth = 3.5
        self.optionOneBtn.layer.borderColor = UIColor.systemYellow.cgColor
        self.optionTwoBtn.layer.borderColor = UIColor.clear.cgColor
        self.optionThreeBtn.layer.borderColor = UIColor.clear.cgColor
        self.optionFourBtn.layer.borderColor = UIColor.clear.cgColor
        self.optionFiveBtn.layer.borderColor = UIColor.clear.cgColor
        currentEntity.removeFromParent()
        detailAnchor.removeFromParent()
//            let id = String(self.currentAnchor.id)
//            if !connectedToNetwork {
//                let docRef = self.db.collection("sessionAnchors").document(id)
//                docRef.delete()
//            }
         //.removeLast()
        if self.selectedAnchorID != "" {
            let id = self.selectedAnchorID
            if let index = self.currentSessionAnchorIDs.firstIndex(of: self.selectedAnchorID) {
                self.currentSessionAnchorIDs.removeAll(where: { $0 == self.selectedAnchorID })
                self.sceneManager.anchorEntities.remove(at: index)
            }
//            let index = self.currentSessionAnchorIDs.firstIndex(of: self.selectedAnchorID)!
//            self.currentSessionAnchorIDs.removeAll(where: { $0 == id })
//
//            //HAS PROBLEM AT INDEX: 0
//
//            self.sceneManager.anchorEntities.remove(at: index)
        }
        selectedEntity?.removeFromParent()
        
        self.entityName.removeFromSuperview()
        self.entityProfileBtn.removeFromSuperview()
        //Download object to focusentity
        self.modelUid = optionsIDArray.first ?? ""
        self.downloadOption()
    }
    
    @IBAction func optionTwoAction(_ sender: Any) {
        self.changedOptions = true
        sceneView.scene.removeAnchor(currentAnchor)
        self.optionTwoBtn.layer.borderWidth = 3.5
        self.optionTwoBtn.layer.borderColor = UIColor.systemYellow.cgColor
        self.optionOneBtn.layer.borderColor = UIColor.clear.cgColor
      //  self.optionTwoBtn.layer.borderColor = UIColor.clear.cgColor
        self.optionThreeBtn.layer.borderColor = UIColor.clear.cgColor
        self.optionFourBtn.layer.borderColor = UIColor.clear.cgColor
        self.optionFiveBtn.layer.borderColor = UIColor.clear.cgColor
        currentEntity.removeFromParent()
        detailAnchor.removeFromParent()
//            let id = String(self.currentAnchor.id)
//            if !connectedToNetwork {
//                let docRef = self.db.collection("sessionAnchors").document(id)
//                docRef.delete()
//            }
         //.removeLast()
        if self.selectedAnchorID != "" {
            let id = self.selectedAnchorID
            if let index = self.currentSessionAnchorIDs.firstIndex(of: self.selectedAnchorID) {
                self.currentSessionAnchorIDs.removeAll(where: { $0 == self.selectedAnchorID })
                self.sceneManager.anchorEntities.remove(at: index)
            }
//            let index = self.currentSessionAnchorIDs.firstIndex(of: self.selectedAnchorID)!
//            self.currentSessionAnchorIDs.removeAll(where: { $0 == id })
//
//            //HAS PROBLEM AT INDEX: 0
//
//            self.sceneManager.anchorEntities.remove(at: index)
        }
        selectedEntity?.removeFromParent()
        
        self.entityName.removeFromSuperview()
        self.entityProfileBtn.removeFromSuperview()
        //Download object to focusentity
        self.modelUid = optionsIDArray[1]
        self.downloadOption()
    }
    
    @IBAction func optionThreeAction(_ sender: Any) {
        self.changedOptions = true
        sceneView.scene.removeAnchor(currentAnchor)
        self.optionThreeBtn.layer.borderWidth = 3.5
        self.optionThreeBtn.layer.borderColor = UIColor.systemYellow.cgColor
        self.optionOneBtn.layer.borderColor = UIColor.clear.cgColor
        self.optionTwoBtn.layer.borderColor = UIColor.clear.cgColor
    //    self.optionThreeBtn.layer.borderColor = UIColor.clear.cgColor
        self.optionFourBtn.layer.borderColor = UIColor.clear.cgColor
        self.optionFiveBtn.layer.borderColor = UIColor.clear.cgColor
        currentEntity.removeFromParent()
        detailAnchor.removeFromParent()
//            let id = String(self.currentAnchor.id)
//            if !connectedToNetwork {
//                let docRef = self.db.collection("sessionAnchors").document(id)
//                docRef.delete()
//            }
         //.removeLast()
        if self.selectedAnchorID != "" {
            let id = self.selectedAnchorID
            if let index = self.currentSessionAnchorIDs.firstIndex(of: self.selectedAnchorID) {
                self.currentSessionAnchorIDs.removeAll(where: { $0 == self.selectedAnchorID })
                self.sceneManager.anchorEntities.remove(at: index)
            }

//            let index = self.currentSessionAnchorIDs.firstIndex(of: self.selectedAnchorID)!
//            self.currentSessionAnchorIDs.removeAll(where: { $0 == id })
//
//            //HAS PROBLEM AT INDEX: 0
//
//            self.sceneManager.anchorEntities.remove(at: index)
        }
        selectedEntity?.removeFromParent()
        
        self.entityName.removeFromSuperview()
        self.entityProfileBtn.removeFromSuperview()
        //Download object to focusentity
        self.modelUid = optionsIDArray[2]
        self.downloadOption()
    }
    
    @IBAction func optionFourAction(_ sender: Any) {
        self.changedOptions = true
        sceneView.scene.removeAnchor(currentAnchor)
        self.optionFourBtn.layer.borderWidth = 3.5
        self.optionFourBtn.layer.borderColor = UIColor.systemYellow.cgColor
        self.optionOneBtn.layer.borderColor = UIColor.clear.cgColor
        self.optionTwoBtn.layer.borderColor = UIColor.clear.cgColor
        self.optionThreeBtn.layer.borderColor = UIColor.clear.cgColor
       // self.optionFourBtn.layer.borderColor = UIColor.clear.cgColor
        self.optionFiveBtn.layer.borderColor = UIColor.clear.cgColor
        currentEntity.removeFromParent()
        detailAnchor.removeFromParent()
//            let id = String(self.currentAnchor.id)
//            if !connectedToNetwork {
//                let docRef = self.db.collection("sessionAnchors").document(id)
//                docRef.delete()
//            }
         //.removeLast()
        if self.selectedAnchorID != "" {
            let id = self.selectedAnchorID
            if let index = self.currentSessionAnchorIDs.firstIndex(of: self.selectedAnchorID) {
                self.currentSessionAnchorIDs.removeAll(where: { $0 == self.selectedAnchorID })
                self.sceneManager.anchorEntities.remove(at: index)
            }
//            let index = self.currentSessionAnchorIDs.firstIndex(of: self.selectedAnchorID)!
//            self.currentSessionAnchorIDs.removeAll(where: { $0 == id })
//
//            //HAS PROBLEM AT INDEX: 0
//
//            self.sceneManager.anchorEntities.remove(at: index)
        }
        selectedEntity?.removeFromParent()
        
        self.entityName.removeFromSuperview()
        self.entityProfileBtn.removeFromSuperview()
        //Download object to focusentity
        self.modelUid = optionsIDArray[3]
        self.downloadOption()
    }
    
    @IBAction func optionFiveAction(_ sender: Any) {
        self.changedOptions = true
        sceneView.scene.removeAnchor(currentAnchor)
        self.optionFiveBtn.layer.borderWidth = 3.5
        self.optionFiveBtn.layer.borderColor = UIColor.systemYellow.cgColor
        self.optionOneBtn.layer.borderColor = UIColor.clear.cgColor
        self.optionTwoBtn.layer.borderColor = UIColor.clear.cgColor
        self.optionThreeBtn.layer.borderColor = UIColor.clear.cgColor
        self.optionFourBtn.layer.borderColor = UIColor.clear.cgColor
     //   self.optionFiveBtn.layer.borderColor = UIColor.clear.cgColor
        currentEntity.removeFromParent()
        detailAnchor.removeFromParent()
//            let id = String(self.currentAnchor.id)
//            if !connectedToNetwork {
//                let docRef = self.db.collection("sessionAnchors").document(id)
//                docRef.delete()
//            }
         //.removeLast()
        if self.selectedAnchorID != "" {
            let id = self.selectedAnchorID
            if let index = self.currentSessionAnchorIDs.firstIndex(of: self.selectedAnchorID) {
                self.currentSessionAnchorIDs.removeAll(where: { $0 == self.selectedAnchorID })
                self.sceneManager.anchorEntities.remove(at: index)
            }
//            let index = self.currentSessionAnchorIDs.firstIndex(of: self.selectedAnchorID)!
//            self.currentSessionAnchorIDs.removeAll(where: { $0 == id })
//
//            //HAS PROBLEM AT INDEX: 0
//
//            self.sceneManager.anchorEntities.remove(at: index)
        }
        selectedEntity?.removeFromParent()
        
        self.entityName.removeFromSuperview()
        self.entityProfileBtn.removeFromSuperview()
        //Download object to focusentity
        self.modelUid = optionsIDArray[4]
        self.downloadOption()
    }
    var isRecording = false
    
    var promptCount = 0
    //------------------------------------------------------------------------------

    func recordTapped() {
//        if isRecording {
//                    audioRecorder.stopRecording()
//                    isRecording = false
//
//                    if let audioUrl = audioRecorder.audioFileURL {
//                        print(audioUrl)
//                        whisperManager.transcribeAudio(audioUrl: audioUrl) { transcript in
//                            if let transcript = transcript {
//                              //  whisperNotionManager.addToNotion(text: transcript)
//                                self.recordedSpeechLabel.text = transcript
//                            }
//                        }
//                        self.recordAudioImgView.tintColor = UIColor(red: 21/255, green: 126/255, blue: 251/255, alpha: 1.0)
//                        self.recognitionRequest = nil
//                        self.recognitionTask = nil
//
//                        self.recordAudioImgView.isUserInteractionEnabled = true
//                        self.promptCount += 1
//                        self.optionOneBtn.layer.borderColor = UIColor.systemYellow.cgColor
//                        self.optionTwoBtn.layer.borderColor = UIColor.clear.cgColor
//                        self.optionThreeBtn.layer.borderColor = UIColor.clear.cgColor
//                        self.optionFourBtn.layer.borderColor = UIColor.clear.cgColor
//                        self.optionFiveBtn.layer.borderColor = UIColor.clear.cgColor
//                        self.downloadDemoContent()
//                    }
//
//                } else {
//                    // Start a new recording session and reset the state
//                    audioRecorder.startRecording()
//                    isRecording = true
//                    self.changeInputMethodLabel.text = "Tap the record button again to stop recording. We'll take it from there!"
//                   // self.recordedSpeechLabel.frame.origin.y -= 7
//                    self.recordedSpeechLabel.backgroundColor = UIColor.white
//                    self.recordedSpeechLabel.textColor = .black
//                    self.recordedSpeechLabel.layer.cornerRadius = 12
//                }
    }
    
//    func startRecording() {
//
//        // Clear all previous session data and cancel task
//        if recognitionTask != nil {
//            recognitionTask?.cancel()
//            recognitionTask = nil
//        }
//
//        // Create instance of audio session to record voice
//        let audioSession = AVAudioSession.sharedInstance()
//        do {
//            try audioSession.setCategory(AVAudioSession.Category.record, mode: AVAudioSession.Mode.measurement, options: AVAudioSession.CategoryOptions.defaultToSpeaker)
//            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
//        } catch {
//            print("audioSession properties weren't set because of an error.")
//        }
//
//        self.recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
//
//        let inputNode = audioEngine.inputNode
//
//        guard let recognitionRequest = recognitionRequest else {
//            fatalError("Unable to create an SFSpeechAudioBufferRecognitionRequest object")
//        }
//
//        recognitionRequest.shouldReportPartialResults = true
//
//      //  self.recordedSpeechLabel.frame.origin.y -= 7
//
//        self.recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest, resultHandler: { (result, error) in
//
//            var isFinal = false
//
//            if result != nil {
//                self.changeInputMethodLabel.text = "Tap the record button again to stop recording. We'll take it from there!"
//               // self.recordedSpeechLabel.frame.origin.y -= 7
//                self.recordedSpeechLabel.backgroundColor = UIColor.white
//                self.recordedSpeechLabel.textColor = .black
//                self.recordedSpeechLabel.layer.cornerRadius = 12
//               // self.recordedSpeechLabel.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
////                self.recordedSpeechTextView.isScrollEnabled = false
////                self.recordedSpeechTextView.translatesAutoresizingMaskIntoConstraints = true
//
//                print(result?.bestTranscription.formattedString)
//                self.recordedSpeechLabel.text = result?.bestTranscription.formattedString
//               // self.recordedSpeechTextView.sizeToFit()
//                isFinal = (result?.isFinal)!
//            }
//
//            if error != nil || isFinal {
//
//                self.audioEngine.stop()
//                inputNode.removeTap(onBus: 0)
//                self.recordAudioImgView.tintColor = UIColor(red: 21/255, green: 126/255, blue: 251/255, alpha: 1.0)
//                self.recognitionRequest = nil
//                self.recognitionTask = nil
//
//                self.recordAudioImgView.isUserInteractionEnabled = true
//                // Send prompt to ChatGPT
//             //   self.sendToChatGPT(prompt: self.recordedSpeechLabel.text ?? "")
//
////                self.searchEntity(query: "painting") { result in
////                    if let result = result {
////                        // download the object with the given ID and add it to the scene
////                        self.checkD()
////                    } else {
////                        // handle error
////                        return
////                    }
////                }
//                self.promptCount += 1
//                self.optionOneBtn.layer.borderColor = UIColor.systemYellow.cgColor
//                self.optionTwoBtn.layer.borderColor = UIColor.clear.cgColor
//                self.optionThreeBtn.layer.borderColor = UIColor.clear.cgColor
//                self.optionFourBtn.layer.borderColor = UIColor.clear.cgColor
//                self.optionFiveBtn.layer.borderColor = UIColor.clear.cgColor
//                self.downloadDemoContent()
//            }
//        })
//
//        let recordingFormat = inputNode.outputFormat(forBus: 0)
//        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
//            self.recognitionRequest?.append(buffer)
//        }
//
//        self.audioEngine.prepare()
//
//        do {
//            try self.audioEngine.start()
//        } catch {
//            print("audioEngine couldn't start because of an error.")
//        }
//
//       // self.lblText.text = "Say something, I'm listening!"
//    }
    
    
    func checkD(){
        toggleBtn.isHidden = true
        self.sceneInfoButton.isHidden = true
        self.undoButton.isHidden = true
    self.anchorSettingsImg.isHidden = true
    self.entityName.removeFromSuperview()
    self.entityProfileBtn.removeFromSuperview()
        dismissKeyboard()
        ProgressHUD.show("Loading...")
        view.isUserInteractionEnabled = false
  //      self.addCloseButton()
    print("\(self.modelName) is modelName")
        
       
        let group = DispatchGroup()

        // Enter the dispatch group before starting the first async task
        group.enter()
        FirestoreManager.getModel(self.modelUid) { model in
            let modelName = model?.modelName
            print("\(modelName ?? "") is model name")
            // Enter the dispatch group before starting the second async task
            group.enter()
            FirebaseStorageHelper.asyncDownloadToFilesystem(relativePath: "models/\(modelName ?? "")")  { localUrl in
                self.cancellable = ModelEntity.loadModelAsync(contentsOf: localUrl).sink(receiveCompletion: { loadCompletion in
                    switch loadCompletion {
                    case.failure(let error): print("Unable to load modelEntity for Mayflower Ship Model. Error: \(error.localizedDescription)")
                        ProgressHUD.dismiss()
                    case.finished:
                        break
                    }
                    // Leave the dispatch group after finishing the second async task
                    group.leave()
                }, receiveValue: { modelEntity in
                    self.currentEntity = modelEntity
                    if self.modelUid == "kUCg8YOdf4buiXMwmxm7" {
                        self.tvStand = modelEntity
                    }
                        self.currentEntity.name = model?.name ?? ""
                     //   self.modelUid =
                        print(self.currentEntity)
                        self.currentEntity.generateCollisionShapes(recursive: true)
                        let physics = PhysicsBodyComponent(massProperties: .default,
                                                                    material: .default,
                                                                        mode: .dynamic)
                        // modelEntity.components.set(physics)
                    if self.modelUid == "MbfjeiKYGfOFTw74eb33" {
                        self.sceneView.installGestures([.rotation, .scale], for: self.currentEntity) //.translation
                        let anchor =  self.focusEntity?.anchor
                        print(anchor)
                        anchor?.addChild(self.currentEntity)
                        let scale = model?.scale
                        print("\(scale) is scale")
                        self.currentEntity.scale = [Float(scale ?? 0.01), Float(scale ?? 0.01), Float(scale ?? 0.01)]
                        //create variable specifically for tvStand
                        self.tvStand?.addChild(modelEntity) // .addAnchor(anchor!) //maybe currentEntity, not anchor
                        modelEntity.setPosition(SIMD3(0.0, 0.78, 0.0), relativeTo: self.tvStand)
                       // self.sceneView.scene.addAnchor(anchor!)
                        print("modelEntity for Samsung 65' QLED 4K Curved Smart TV has been loaded.")
                        ProgressHUD.dismiss()
                        self.removeCloseButton()
                       // print("modelEntity for \(self.name) has been loaded.")
                        self.view.isUserInteractionEnabled = true
                        self.sceneView.isUserInteractionEnabled = true
                    } else {
                        self.sceneView.installGestures([.translation, .rotation, .scale], for: self.currentEntity)
                        let anchor =  self.focusEntity?.anchor //AnchorEntity(plane: .any)// // AnchorEntity(world: [0,-0.2,0])
                        print(anchor)
                        // anchor?.scale = [1.2,1.0,1.0]
                        anchor?.addChild(self.currentEntity)
                        let scale = model?.scale
                        print("\(scale) is scale")
                        self.currentEntity.scale = [Float(scale ?? 0.01), Float(scale ?? 0.01), Float(scale ?? 0.01)]
                        self.sceneView.scene.addAnchor(anchor!)
                        // self.currentEntity?.scale *= self.scale
                        print("modelEntity for Mayflower Ship Model has been loaded.")
                        ProgressHUD.dismiss()
                        self.removeCloseButton()
                        // print("modelEntity for \(self.name) has been loaded.")
                        self.changeInputMethodLabel.isHidden = true
                        self.promptLabel.isHidden = true
                        self.cancelImg.isHidden = true
                        self.recordedSpeechLabel.isHidden = true
                        self.recordSpeechUnderView.isHidden = true
                        self.recordAudioImgView.isHidden = true
                        self.recordSpeechUnderView.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
                        self.recordAudioImgView.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
                        self.modelPlacementUI()
                    }
                    // Leave the dispatch group after finishing the first async task
                    group.leave()
                })
            }
        }
        // Wait for all async tasks to finish and call the completion closure
        group.notify(queue: .main) {
            // Do something after all async tasks are finished
            self.view.isUserInteractionEnabled = true
        }

    }
    
    func createPlane(for planeAnchor: ARPlaneAnchor, material: SimpleMaterial) -> ModelEntity {

        // Get the plane's extent.
        if #available(iOS 16.0, *) {
            let extent = planeAnchor.planeExtent
        

        // Create a model entity sized to the plane's extent.
            let planeEntity = ModelEntity(mesh: .generatePlane (width: extent.width, depth: extent.height),
            materials: [material])

        // Orient the entity according to the extent's y-axis rotation.
        planeEntity.transform = Transform(pitch: 0, yaw: extent.rotationOnYAxis, roll: 0)

        // Center the entity on the plane.
        planeEntity.transform.translation = planeAnchor.center

        return planeEntity
        } else {
            // Fallback on earlier versions
            // Create a model entity sized to the plane's extent.
            let planeEntity = ModelEntity(mesh: .generatePlane (width: 1, depth: 1),
                materials: [material])

            // Orient the entity according to the extent's y-axis rotation.
            planeEntity.transform = Transform(pitch: 0, yaw: 0, roll: 0)

            // Center the entity on the plane.
            planeEntity.transform.translation = planeAnchor.center

            return planeEntity
        }
    }

    
    @objc func downloadDemoContent(){
        toggleBtn.isHidden = true
        self.sceneInfoButton.isHidden = true
        self.undoButton.isHidden = true
    self.anchorSettingsImg.isHidden = true
    self.entityName.removeFromSuperview()
    self.entityProfileBtn.removeFromSuperview()
        dismissKeyboard()
        ProgressHUD.show("Loading...")
        view.isUserInteractionEnabled = false
  //      self.addCloseButton()
    print("\(self.modelName) is modelName")
       
        if self.promptCount == 1 {
            self.optionsIDArray = ["kfryesPpvBmlhhVTohMz", "6CwMVBiRJob46q4gR5VV", "5nonCjQT4zYsX8hWTPi6", "AV8N12VCVJUQi24aoMR1", "uz9qRIM24cMmYXXte0CV"]
            self.modelUid = "kfryesPpvBmlhhVTohMz"
        }else if self.promptCount == 2 {
            self.optionFiveBtn.isHidden = true
            self.optionsIDArray = ["CYizrDMSTDonvpxwCxIN", "d08xRTuhHeNK3waBnFMA", "5nonCjQT4zYsX8hWTPi6", "rLK8byd3qLadPh2JL56Q"]
            self.modelUid = "CYizrDMSTDonvpxwCxIN"
            sceneView.scene.removeAnchor(currentAnchor)
            currentEntity.removeFromParent()
            detailAnchor.removeFromParent()
            if self.selectedAnchorID != "" {
                let id = self.selectedAnchorID
                if let index = self.currentSessionAnchorIDs.firstIndex(of: self.selectedAnchorID) {
                    self.currentSessionAnchorIDs.removeAll(where: { $0 == self.selectedAnchorID })
                    self.sceneManager.anchorEntities.remove(at: index)
                }
    //            let index = self.currentSessionAnchorIDs.firstIndex(of: self.selectedAnchorID)!
    //            self.currentSessionAnchorIDs.removeAll(where: { $0 == id })
    //
    //            //HAS PROBLEM AT INDEX: 0
    //
    //            self.sceneManager.anchorEntities.remove(at: index)
            }
            selectedEntity?.removeFromParent()
            
            self.entityName.removeFromSuperview()
            self.entityProfileBtn.removeFromSuperview()
        } else if self.promptCount == 3 {
            self.optionsIDArray = ["8EaV7rkVJCjn7iyzWUkR", "7LQYGxvKqTiCvL13pHhl", "tHACGFMQG80YKiMjQJhr", "ZqS6oeQMVahlAMJQ0qUQ", "Vix2PIBhfNCzmVnY7oWv"] //0R0BBDYP1KP1fChtON18
            self.modelUid = "8EaV7rkVJCjn7iyzWUkR"
            self.optionFiveBtn.isHidden = false
        } else if self.promptCount == 4 {
            self.optionFourBtn.isHidden = false
            self.optionFiveBtn.isHidden = true
            self.optionsIDArray = ["mSUMmPdsge7udfbicP1u", "myOwhkgkTtRS9pvM9SVV", "5nonCjQT4zYsX8hWTPi6", "AV8N12VCVJUQi24aoMR1", "uz9qRIM24cMmYXXte0CV"]
            self.modelUid = "mSUMmPdsge7udfbicP1u"
        } else if self.promptCount == 19 {
            self.optionFourBtn.isHidden = false
            self.optionsIDArray = ["5LWeAjR4wERzIR6HCCqc", "8RrMkkBUOdyVBWHUkKb6", "e4aE8GPAZ0D3UcD9wMPo", "AV8N12VCVJUQi24aoMR1", "uz9qRIM24cMmYXXte0CV"]
            self.modelUid = "5LWeAjR4wERzIR6HCCqc"
        } else if self.promptCount == 5 {
            self.optionFourBtn.isHidden = false
            self.optionFiveBtn.isHidden = false
            self.optionsIDArray = ["kUCg8YOdf4buiXMwmxm7", "HVlYhnpW35WRj2B6QNQn", "V6ASGob4TpGFdrh6qfZO", "AV8N12VCVJUQi24aoMR1", "uz9qRIM24cMmYXXte0CV"]
            self.modelUid = "kUCg8YOdf4buiXMwmxm7"
        } else if self.promptCount == 6 {
            self.optionFourBtn.isHidden = false
            self.optionFiveBtn.isHidden = false
            self.optionsIDArray = ["MbfjeiKYGfOFTw74eb33", "xTX5AW2SNl1OEIplvuDV", "5c9FAwQV4jJyryxfC21r", "rZaGU0xSVbDuoPTLg4eT", "fOKvonZjVOeWrzm9wrSc"]
            self.modelUid = "MbfjeiKYGfOFTw74eb33"
        }
        //self.updateOptions(index: 0)
        for i in 0..<optionsIDArray.count {
            self.updateOptions(index: i)
        }
        let group = DispatchGroup()

        // Enter the dispatch group before starting the first async task
        group.enter()
        FirestoreManager.getModel(self.modelUid) { model in
            let modelName = model?.modelName
            print("\(modelName ?? "") is model name")
            // Enter the dispatch group before starting the second async task
            group.enter()
            FirebaseStorageHelper.asyncDownloadToFilesystem(relativePath: "models/\(modelName ?? "")")  { localUrl in
                self.cancellable = ModelEntity.loadModelAsync(contentsOf: localUrl).sink(receiveCompletion: { loadCompletion in
                    switch loadCompletion {
                    case.failure(let error): print("Unable to load modelEntity for Mayflower Ship Model. Error: \(error.localizedDescription)")
                        ProgressHUD.dismiss()
                    case.finished:
                        break
                    }
                    // Leave the dispatch group after finishing the second async task
                    group.leave()
                }, receiveValue: { modelEntity in
                    self.currentEntity = modelEntity
                    if self.modelUid == "kUCg8YOdf4buiXMwmxm7" {
                        self.tvStand = modelEntity
                    }
                        self.currentEntity.name = model?.name ?? ""
                     //   self.modelUid =
                        print(self.currentEntity)
                        self.currentEntity.generateCollisionShapes(recursive: true)
                        let physics = PhysicsBodyComponent(massProperties: .default,
                                                                    material: .default,
                                                                        mode: .dynamic)
                        // modelEntity.components.set(physics)
                    if self.modelUid == "MbfjeiKYGfOFTw74eb33" {
                        self.sceneView.installGestures([.rotation, .scale], for: self.currentEntity) //.translation
                        let anchor =  self.focusEntity?.anchor
                        print(anchor)
                        anchor?.addChild(self.currentEntity)
                        let scale = model?.scale
                        print("\(scale) is scale")
                        self.currentEntity.scale = [Float(scale ?? 0.01), Float(scale ?? 0.01), Float(scale ?? 0.01)]
                        //create variable specifically for tvStand
                        self.tvStand?.addChild(modelEntity) // .addAnchor(anchor!) //maybe currentEntity, not anchor
                        modelEntity.setPosition(SIMD3(0.0, 0.78, 0.0), relativeTo: self.tvStand)
                       // self.sceneView.scene.addAnchor(anchor!)
                        print("modelEntity for Samsung 65' QLED 4K Curved Smart TV has been loaded.")
                        ProgressHUD.dismiss()
                        self.removeCloseButton()
                       // print("modelEntity for \(self.name) has been loaded.")
                        self.view.isUserInteractionEnabled = true
                        self.sceneView.isUserInteractionEnabled = true
                        self.changeInputMethodLabel.isHidden = true
                        self.promptLabel.isHidden = true
                        self.cancelImg.isHidden = true
                        self.recordedSpeechLabel.isHidden = true
                        self.recordSpeechUnderView.isHidden = true
                        self.optionsScrollView.isHidden = false
                        self.recordAudioImgView.isHidden = true
                        self.recordSpeechUnderView.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
                        self.recordAudioImgView.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
                        self.modelPlacementUI()
                    } else {
                        self.sceneView.installGestures([.translation, .rotation, .scale], for: self.currentEntity)
                        let anchor =  self.focusEntity?.anchor //AnchorEntity(plane: .any)// // AnchorEntity(world: [0,-0.2,0])
                        print(anchor)
                        // anchor?.scale = [1.2,1.0,1.0]
                        anchor?.addChild(self.currentEntity)
                        let scale = model?.scale
                        print("\(scale) is scale")
                        self.currentEntity.scale = [Float(scale ?? 0.01), Float(scale ?? 0.01), Float(scale ?? 0.01)]
                        self.sceneView.scene.addAnchor(anchor!)
                        // self.currentEntity?.scale *= self.scale
                        print("modelEntity for Mayflower Ship Model has been loaded.")
                        ProgressHUD.dismiss()
                        self.removeCloseButton()
                        // print("modelEntity for \(self.name) has been loaded.")
                        self.changeInputMethodLabel.isHidden = true
                        self.promptLabel.isHidden = true
                        self.cancelImg.isHidden = true
                        self.recordedSpeechLabel.isHidden = true
                        self.recordSpeechUnderView.isHidden = true
                        self.optionsScrollView.isHidden = false
                        self.recordAudioImgView.isHidden = true
                        self.recordSpeechUnderView.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
                        self.recordAudioImgView.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
                        self.modelPlacementUI()
                    }
                    // Leave the dispatch group after finishing the first async task
                    group.leave()
                })
            }
        }
        // Wait for all async tasks to finish and call the completion closure
        group.notify(queue: .main) {
            // Do something after all async tasks are finished
            self.view.isUserInteractionEnabled = true
        }

                
    }
    
    var optionUid = ""
    
    private static var thumbnailCache = NSCache<NSString, UIImage>()

    func updateOptions(index: Int) {
        BlueprintViewController.thumbnailCache.countLimit = 40
        BlueprintViewController.thumbnailCache.evictsObjectsWithDiscardedContent = true

        guard index >= 0 && index < optionsIDArray.count else {
            return
        }

        optionUid = optionsIDArray[index]

        FirestoreManager.getModel(optionUid) { model in
            let thumbnailName = model?.thumbnail

            // Check if the image is in the cache
            if let cachedImage = BlueprintViewController.thumbnailCache.object(forKey: thumbnailName as! NSString) {
                switch index {
                case 0:
                    self.optionOneBtn.setImage(cachedImage, for: .normal)
                    self.optionOneBtn.layer.borderWidth = 3.5
                    self.optionOneBtn.layer.borderColor = UIColor.systemYellow.cgColor
                case 1:
                    self.optionTwoBtn.setImage(cachedImage, for: .normal)
                case 2:
                    if self.promptCount == 4 {
                        self.optionThreeBtn.setImage(UIImage(named: "bluecarpet"), for: .normal)
                    } else {
                        self.optionThreeBtn.setImage(cachedImage, for: .normal)
                    }
                case 3:
                    if self.promptCount == 4 {
                        self.optionFourBtn.setImage(UIImage(named: "persian"), for: .normal)
                    } else {
                        self.optionFourBtn.setImage(cachedImage, for: .normal)
                    }
                case 4:
                    self.optionFiveBtn.setImage(cachedImage, for: .normal)
                default:
                    break
                }
            } else {
                StorageManager.getModelThumbnail(thumbnailName ?? "") { image in
                    // Remove optional binding and directly use the image constant
                       if image != nil {
                        // Add the image to the cache
                           BlueprintViewController.thumbnailCache.setObject(image, forKey: thumbnailName! as NSString)

                        switch index {
                        case 0:
                            self.optionOneBtn.setImage(image, for: .normal)
                            self.optionOneBtn.layer.borderWidth = 3.5
                            self.optionOneBtn.layer.borderColor = UIColor.systemYellow.cgColor
                        case 1:
                            self.optionTwoBtn.setImage(image, for: .normal)
                        case 2:
                            if self.promptCount == 4 {
                                self.optionThreeBtn.setImage(UIImage(named: "bluecarpet"), for: .normal)
                            } else {
                                self.optionThreeBtn.setImage(image, for: .normal)
                            }
                        case 3:
                            if self.promptCount == 4 {
                                self.optionFourBtn.setImage(UIImage(named: "persian"), for: .normal)
                            } else {
                                self.optionFourBtn.setImage(image, for: .normal)
                            }
                        case 4:
                            self.optionFiveBtn.setImage(image, for: .normal)
                        default:
                            break
                        }
                    }
                }
            }
        }
    }
    
    func updateOptionsCompletion(index: Int, completion: @escaping () -> Void) {
        BlueprintViewController.thumbnailCache.countLimit = 40
        BlueprintViewController.thumbnailCache.evictsObjectsWithDiscardedContent = true
        
        guard index >= 0 && index < optionsIDArray.count else {
            return
        }
        
        optionUid = optionsIDArray[index]
        
        FirestoreManager.getModel(optionUid) { model in
            let thumbnailName = model?.thumbnail
            
            // Check if the image is in the cache
            if let cachedImage = BlueprintViewController.thumbnailCache.object(forKey: thumbnailName as! NSString) {
                switch index {
                case 0:
                    self.optionOneBtn.setImage(cachedImage, for: .normal)
                    self.optionOneBtn.layer.borderWidth = 3.5
                    self.optionOneBtn.layer.borderColor = UIColor.systemYellow.cgColor
                case 1:
                    self.optionTwoBtn.setImage(cachedImage, for: .normal)
                case 2:
                    if self.promptCount == 4 {
                        self.optionThreeBtn.setImage(UIImage(named: "bluecarpet"), for: .normal)
                    } else {
                        self.optionThreeBtn.setImage(cachedImage, for: .normal)
                    }
                case 3:
                    if self.promptCount == 4 {
                        self.optionFourBtn.setImage(UIImage(named: "persian"), for: .normal)
                    } else {
                        self.optionFourBtn.setImage(cachedImage, for: .normal)
                    }
                case 4:
                    self.optionFiveBtn.setImage(cachedImage, for: .normal)
                default:
                    break
                }
                
                // Call the completion handler
                completion()
            } else {
                StorageManager.getModelThumbnail(thumbnailName ?? "") { image in
                    if image != nil {
                        BlueprintViewController.thumbnailCache.setObject(image, forKey: thumbnailName! as NSString)
                        
                        switch index {
                        case 0:
                            self.optionOneBtn.setImage(image, for: .normal)
                            self.optionOneBtn.layer.borderWidth = 3.5
                            self.optionOneBtn.layer.borderColor = UIColor.systemYellow.cgColor
                        case 1:
                            self.optionTwoBtn.setImage(image, for: .normal)
                        case 2:
                            if self.promptCount == 4 {
                                self.optionThreeBtn.setImage(UIImage(named: "bluecarpet"), for: .normal)
                            } else {
                                self.optionThreeBtn.setImage(image, for: .normal)
                            }
                        case 3:
                            if self.promptCount == 4 {
                                self.optionFourBtn.setImage(UIImage(named: "persian"), for: .normal)
                            } else {
                                self.optionFourBtn.setImage(image, for: .normal)
                            }
                        case 4:
                            self.optionFiveBtn.setImage(image, for: .normal)
                        default:
                            break
                        }
                    }
                    
                    // Call the completion handler
                    completion()
                }
            }
        }
    }


   
    
    func changePainting(){
        ProgressHUD.show("Loading...")
        toggleBtn.isHidden = true
        self.sceneInfoButton.isHidden = true
        self.undoButton.isHidden = true
    self.anchorSettingsImg.isHidden = true
    self.entityName.removeFromSuperview()
    self.entityProfileBtn.removeFromSuperview()
        let last = self.sceneManager.anchorEntities.last
        last?.removeFromParent()
        sceneManager.anchorEntities.removeLast()
        let lastID = self.currentSessionAnchorIDs.last
        print("\(lastID) is last ID")
        let docRef = self.db.collection("sessionAnchors").document(lastID ?? "")
        docRef.delete()
        self.currentSessionAnchorIDs.removeLast()
        dismissKeyboard()
      //  ProgressHUD.dismiss()
        
        view.isUserInteractionEnabled = false
  //      self.addCloseButton()
    print("\(self.modelName) is modelName")
        
        
        let group = DispatchGroup()

        // Enter the dispatch group before starting the first async task
        group.enter()
        FirestoreManager.getModel(self.modelUid) { model in
            let modelName = model?.modelName
            print("\(modelName ?? "") is model name")
            // Enter the dispatch group before starting the second async task
            group.enter()
            FirebaseStorageHelper.asyncDownloadToFilesystem(relativePath: "models/\(modelName ?? "")")  { localUrl in
                self.cancellable = ModelEntity.loadModelAsync(contentsOf: localUrl).sink(receiveCompletion: { loadCompletion in
                    switch loadCompletion {
                    case.failure(let error): print("Unable to load modelEntity for Mayflower Ship Model. Error: \(error.localizedDescription)")
                        ProgressHUD.dismiss()
                    case.finished:
                        break
                    }
                    // Leave the dispatch group after finishing the second async task
                    group.leave()
                }, receiveValue: { modelEntity in
                    self.currentEntity = modelEntity
                    if self.modelUid == "kUCg8YOdf4buiXMwmxm7" {
                        self.tvStand = modelEntity
                    }
                        self.currentEntity.name = model?.name ?? ""
                     //   self.modelUid =
                        print(self.currentEntity)
                        self.currentEntity.generateCollisionShapes(recursive: true)
                        let physics = PhysicsBodyComponent(massProperties: .default,
                                                                    material: .default,
                                                                        mode: .dynamic)
                        // modelEntity.components.set(physics)
                    if self.modelUid == "MbfjeiKYGfOFTw74eb33" {
                        self.sceneView.installGestures([.rotation, .scale], for: self.currentEntity) //.translation
                        let anchor =  self.focusEntity?.anchor
                        print(anchor)
                        anchor?.addChild(self.currentEntity)
                        let scale = model?.scale
                        print("\(scale) is scale")
                        self.currentEntity.scale = [Float(scale ?? 0.01), Float(scale ?? 0.01), Float(scale ?? 0.01)]
                        //create variable specifically for tvStand
                        self.tvStand?.addChild(modelEntity) // .addAnchor(anchor!) //maybe currentEntity, not anchor
                        modelEntity.setPosition(SIMD3(0.0, 0.78, 0.0), relativeTo: self.tvStand)
                       // self.sceneView.scene.addAnchor(anchor!)
                        print("modelEntity for Samsung 65' QLED 4K Curved Smart TV has been loaded.")
                        ProgressHUD.dismiss()
                        self.removeCloseButton()
                       // print("modelEntity for \(self.name) has been loaded.")
                        self.view.isUserInteractionEnabled = true
                        self.sceneView.isUserInteractionEnabled = true
                    } else {
                        self.sceneView.installGestures([.translation, .rotation, .scale], for: self.currentEntity)
                        let anchor =  self.focusEntity?.anchor //AnchorEntity(plane: .any)// // AnchorEntity(world: [0,-0.2,0])
                        print(anchor)
                        // anchor?.scale = [1.2,1.0,1.0]
                        anchor?.addChild(self.currentEntity)
                        let scale = model?.scale
                        print("\(scale) is scale")
                        self.currentEntity.scale = [Float(scale ?? 0.01), Float(scale ?? 0.01), Float(scale ?? 0.01)]
                        self.sceneView.scene.addAnchor(anchor!)
                        // self.currentEntity?.scale *= self.scale
                        print("modelEntity for Mayflower Ship Model has been loaded.")
                        ProgressHUD.dismiss()
                        self.removeCloseButton()
                        // print("modelEntity for \(self.name) has been loaded.")
                        self.changeInputMethodLabel.isHidden = true
                        self.promptLabel.isHidden = true
                        self.cancelImg.isHidden = true
                        self.recordedSpeechLabel.isHidden = true
                        self.recordSpeechUnderView.isHidden = true
                        self.recordAudioImgView.isHidden = true
                        self.recordSpeechUnderView.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
                        self.recordAudioImgView.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
                        self.modelPlacementUI()
                    }
                    // Leave the dispatch group after finishing the first async task
                    group.leave()
                })
            }
        }
        // Wait for all async tasks to finish and call the completion closure
        group.notify(queue: .main) {
            // Do something after all async tasks are finished
            self.view.isUserInteractionEnabled = true
        }

                
    }
    
    
    func placeTV(){
        ProgressHUD.show("Loading...")
        view.isUserInteractionEnabled = false
      
    print("\(self.modelName) is modelName")
        
        let group = DispatchGroup()

        // Enter the dispatch group before starting the first async task
        group.enter()
        FirestoreManager.getModel("MbfjeiKYGfOFTw74eb33") { model in
            let modelName = model?.modelName
            print("\(modelName ?? "") is model name")
            // Enter the dispatch group before starting the second async task
            group.enter()
            FirebaseStorageHelper.asyncDownloadToFilesystem(relativePath: "models/\(modelName ?? "")")  { localUrl in
                self.cancellable = ModelEntity.loadModelAsync(contentsOf: localUrl).sink(receiveCompletion: { loadCompletion in
                    switch loadCompletion {
                    case.failure(let error): print("Unable to load modelEntity for Mayflower Ship Model. Error: \(error.localizedDescription)")
                        ProgressHUD.dismiss()
                    case.finished:
                        break
                    }
                    // Leave the dispatch group after finishing the second async task
                    group.leave()
                }, receiveValue: { modelEntity in
                    self.currentEntity = modelEntity
                        self.currentEntity.name = model?.name ?? ""
                     //   self.modelUid =
                        print(self.currentEntity)
                        self.currentEntity.generateCollisionShapes(recursive: true)
                        let physics = PhysicsBodyComponent(massProperties: .default,
                                                                    material: .default,
                                                                        mode: .dynamic)
                    
                      //  self.tvStand?.addChild(modelEntity) // .addAnchor(anchor!) //maybe currentEntity, not anchor
                      //  modelEntity.setPosition(SIMD3(0.0, 0.78, 0.0), relativeTo: self.tvStand)
                    guard let query = self.sceneView.makeRaycastQuery(from: self.sceneView.center,
                                                                  allowing: .estimatedPlane,
                                                                 alignment: .vertical)
                            else { return }

                            guard let result = self.sceneView.session.raycast(query).first
                            else { return }

                            let raycastAnchor = AnchorEntity(world: result.worldTransform)
                    print("\(result.worldTransform) is worldTransform")
                            raycastAnchor.addChild(self.currentEntity)
                       // anchor?.addChild(self.currentEntity))
                    self.sceneView.scene.addAnchor(raycastAnchor)//
//

                        print("modelEntity for Samsung 65' QLED 4K Curved Smart TV has been loaded.")
                       // ProgressHUD.dismiss()
                    self.sceneView.installGestures([.translation, .rotation, .scale], for: self.currentEntity)
                        self.view.isUserInteractionEnabled = true
                        self.sceneView.isUserInteractionEnabled = true
                    
                    self.cancelAIAction()
                    self.placePainting()
                })
                // Leave the dispatch group after finishing the first async task
                group.leave()
                }
                
            }
    }
    
    func placePainting(){
     //   ProgressHUD.show("Loading...")
      //  view.isUserInteractionEnabled = false
      
    print("\(self.modelName) is modelName")
        
        let group = DispatchGroup()

        // Enter the dispatch group before starting the first async task
        group.enter()
        FirestoreManager.getModel("mr1hRfNicRNMZTsgVFyv") { model in
            let modelName = model?.modelName
            print("\(modelName ?? "") is model name")
            // Enter the dispatch group before starting the second async task
            group.enter()
            FirebaseStorageHelper.asyncDownloadToFilesystem(relativePath: "models/\(modelName ?? "")")  { localUrl in
                self.cancellable = ModelEntity.loadModelAsync(contentsOf: localUrl).sink(receiveCompletion: { loadCompletion in
                    switch loadCompletion {
                    case.failure(let error): print("Unable to load modelEntity for Mayflower Ship Model. Error: \(error.localizedDescription)")
                        ProgressHUD.dismiss()
                    case.finished:
                        break
                    }
                    // Leave the dispatch group after finishing the second async task
                    group.leave()
                }, receiveValue: { modelEntity in
                    self.currentEntity = modelEntity
                        self.currentEntity.name = model?.name ?? ""
                     //   self.modelUid =
                        print(self.currentEntity)
                    self.currentEntity.scale = [Float(0.008 ?? 0.01), Float(0.008 ?? 0.01), Float(0.008 ?? 0.01)]
                        self.currentEntity.generateCollisionShapes(recursive: true)
                        let physics = PhysicsBodyComponent(massProperties: .default,
                                                                    material: .default,
                                                                        mode: .dynamic)
                    
                    let floorPlane = AnchoringComponent.Target.plane(.horizontal, classification: .floor, minimumBounds: [0.2, 0.2])
                    let plane = AnchoringComponent.Target.Alignment.horizontal
                    let planeAnchor = AnchorEntity(.plane([.horizontal],
                                          classification: [.floor, .ceiling],
                                                          minimumBounds: [0.7, 0.7]))
                    let raycastAnchor = AnchorEntity(plane: plane)// (anchor: floorPlane)
                    print("\(planeAnchor.position) is planeAnchor position")
                    planeAnchor.addChild(self.currentEntity)
                       // anchor?.addChild(self.currentEntity))
                    self.sceneView.scene.addAnchor(planeAnchor)//self.sceneView.scene.anchors.append(planeAnchor)
                    
                 

                        print("modelEntity for Samsung 65' QLED 4K Curved Smart TV has been loaded.")
                        ProgressHUD.dismiss()
                    self.sceneView.installGestures([.translation, .rotation, .scale], for: self.currentEntity)
                        self.view.isUserInteractionEnabled = true
                        self.sceneView.isUserInteractionEnabled = true
                    
                  //  self.cancelAIAction()
                    //self.placePainting()
                })
                // Leave the dispatch group after finishing the first async task
                group.leave()
                }
                
            }
    }
    
    public func onMessageReceived(id: String, data: Data) {
        let decoder = JSONDecoder()
        do {
//            let msg = try decoder.decode(ChatGPTResponseMessage.self, from: data)
//            print("[ViewController] ChatGPT response message received. Code:\n\(msg.code)")
//            self.runCode(code: msg.code)
           //get code from chatGPT API response
        }
        catch {
            print("[ViewController] Failed to decode message")
        //    Util.hexDump(data)
        }
    }
    let api = ChatGPTAPI(apiKey: "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")
    

    private func sendToChatGPT(prompt: String) {
//        // Augment the user's prompt with additional material
//        if let augmentedPrompt = self.augmentPrompt(prompt: prompt) {
//            //ChatGPTPromptMessage(prompt: augmentedPrompt) - chatGPT api
//        }
        
        Task {
            do {
                    print(self.augmentPrompt(prompt: prompt))
                let response = try await self.api.sendMessage(text: self.augmentPrompt(prompt: prompt))
                
                   print(response)
                self.runCode(code: response)
               } catch {
                   print(error.localizedDescription)
               }
        }
    }
                          
    func chatGPTResponse(response: String){
        
//        let msg = try decoder.decode(T.self, from: data) decoder.decode(response, from: <#Data#>)
//           print("[ViewController] ChatGPT response message received. Code:\n\(msg.code)")
//            self.runCode(code: msg.code)
    }
                          
                          
    
    func uploadNetworkAlert() {
        let alertController = UIAlertController(title: "Upload Network", message: "Create a name for this Blueprint Network. This can be changed later.", preferredStyle: .alert)
        let saveAction = UIAlertAction(title: "Save", style: .default, handler: { (_) in
            let nameTextField = alertController.textFields![0]
            let name = (nameTextField.text ?? "").isEmpty ? "My Room" : nameTextField.text!
            self.networkName = name
            if name == "" || name == " " || name == "My Room" {
                self.uploadNetworkAlert()
            } else {
                self.uploadNetwork()
            }

        })
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: { (_) in
            //self.showAllUI()
            self.removeScanUI()
            self.wordsBtn.isHidden = false
            self.libraryImageView.isHidden = false
            self.videoBtn.isHidden = false
            self.buttonStackView.isHidden = false
            self.networkBtn.isHidden = false
            self.networksNearImg.isHidden = false
         //   self.feedbackControl.isHidden = true
        })
        alertController.addTextField { (textField) in
            textField.placeholder = "My Room"
            textField.autocapitalizationType = .sentences
            //textField.placeholder = "Network Name"
        }
        alertController.addAction(saveAction)
        alertController.addAction(cancelAction)
        self.present(alertController, animated: true, completion: nil)
        
    }
    
    
    var touches = 0
    
    var hideTaps = 0
    var multipeerSession: MultipeerSession!
    
    var peerSessionIDs = [MCPeerID: String]()
    
    var sessionIDObservation: NSKeyValueObservation?
    
  //  var searchView : UIView = SearchView()

    
    @objc func down(sender: UIGestureRecognizer){
        print("down")
        UIView.animate(withDuration: 2.0, animations: { () -> Void in
//            self.searchBar.frame = CGRect(x: 20.0, y: 60.0, width: 289, height: 44.0)
//            self.searchBar.delegate = self
            }, completion: { (Bool) -> Void in
        })
    }
    
    @objc func up(sender: UIGestureRecognizer){
        print("up")
        UIView.animate(withDuration: 2.0, animations: { () -> Void in
//            self.searchBar.frame = CGRect(x: 0.0, y: 0.0, width: 289, height: 44.0)
//            self.searchBar.delegate = self
        }, completion: { (Bool) -> Void in
        })
    }
    
    func setupMultipeer() {
//        // MARK: - Setting Up Multipeer Helper -
////        multipeerHelp = MultipeerHelper(
////          serviceName: "blueprint-helper-test",
////          sessionType: .both, //.host
////          delegate: self
////        )
////
////        // MARK: - Setting RealityKit Synchronization
////        guard let syncService = multipeerHelp.syncService else {
////          fatalError("could not create multipeerHelp.syncService")
////        }
////        sceneView.scene.synchronizationService = syncService
//
//        // Use key-value observation to monitor your ARSession's identifier.
//        // SENSE IF ANY CURRENT SESSIONS NEAR USER
//        sessionIDObservation = observe(\.sceneView.session.identifier, options: [.new]) { object, change in
//            print("SessionID changed to: \(change.newValue!)")
//            // Tell all other peers about your ARSession's changed ID, so
//            // that they can keep track of which ARAnchors are yours.
//            guard let multipeerSession = self.multipeerSession else { return }
//            self.sendARSessionIDTo(peers: multipeerSession.connectedPeers)
//        }
//
//        // Start looking for other players via MultiPeerConnectivity.
//         multipeerSession = MultipeerSession(receivedDataHandler: receivedData, peerJoinedHandler:
//                                            peerJoined, peerLeftHandler: peerLeft, peerDiscoveredHandler: peerDiscovered)
      }
    
    var undoButton = UIImageView(frame: CGRect(x: UIScreen.main.bounds.width - 47, y: 120, width: 25, height: 25))
    
    
    
    
    @objc func goToAnchorSettings(){
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
      //  print("\(LaunchViewController.auth.currentUser?.uid) is the current user id")
        var next = storyboard.instantiateViewController(withIdentifier: "AnchorSettingsTableVC") as! AnchorSettingsTableViewController
       // next.modalPresentationStyle = .fullScreen
        self.present(next, animated: true, completion: nil)
    }
    
//    func detectPlanes(){
//        session.addAnchor { (anchor) in
//        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
//            let texture = Texture(UIImage(named: "wildtextures_mossed-tree-bark-seamless-2k-texture")!)
//            let material = Material()
//            material.diffuseProperty = texture
//
//            let planeEntity = createPlane(for: planeAnchor, material: material)
//            sceneView.addChildNode(planeEntity)
////            anchor.addChild(videoPlane)
////
////
////            videoPlane.generateCollisionShapes(recursive: true)
////
////           // videoPlane.
////            //
////            sceneView.installGestures([.translation, .rotation, .scale], for: videoPlane)
////
////           // sceneView.scene.addAnchor(anchor!)
////            sceneView.scene.anchors.append(anchor)
//        }
//    }
    
    @objc func goToComposeArtwork(){
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        var next = storyboard.instantiateViewController(withIdentifier: "ComposeArtworkVC") as! ComposeArtworkViewController
         next.modalPresentationStyle = .fullScreen
        self.present(next, animated: true, completion: nil)
    
    }
    
    @objc func goToLibrary(){
        if Auth.auth().currentUser != nil {
            let user = Auth.auth().currentUser?.uid ?? ""
            let vc = LibraryViewController.instantiate(with: user) //(user:user)
            let navVC = UINavigationController(rootViewController: vc)
           // var next = UserProfileViewController.instantiate(with: user)
           //  navVC.modalPresentationStyle = .fullScreen
          //  self.navigationController?.pushViewController(next, animated: true)
            present(navVC, animated: true)
        } else {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            var next = storyboard.instantiateViewController(withIdentifier: "CreateAccountVC") as! CreateAccountViewController
           // next.modalPresentationStyle = .fullScreen
            self.present(next, animated: true, completion: nil)
        }
    }
    
    @objc func goToUserProfile(){

        if Auth.auth().currentUser != nil {
            let user = Auth.auth().currentUser?.uid ?? ""
            let vc = UserProfileViewController.instantiate(with: user) //(user:user)
            let navVC = UINavigationController(rootViewController: vc)
           // var next = UserProfileViewController.instantiate(with: user)
             navVC.modalPresentationStyle = .fullScreen
          //  self.navigationController?.pushViewController(next, animated: true)
            present(navVC, animated: true)
        } else {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            var next = storyboard.instantiateViewController(withIdentifier: "CreateAccountVC") as! CreateAccountViewController
           // next.modalPresentationStyle = .fullScreen
            self.present(next, animated: true, completion: nil)
        }
        
        
        
//        ProgressHUD.show("Loading...")
//        FirebaseStorageHelper.asyncDownloadToFilesystem(relativePath: "models/Field_Painting_by_Jasper_Johns1.usdz") { localUrl in
//            self.cancellable = ModelEntity.loadModelAsync(contentsOf: localUrl).sink(receiveCompletion: { loadCompletion in
//                switch loadCompletion {
//                case.failure(let error): print("Unable to load modelEntity for Air Jordan 1s. Error: \(error.localizedDescription)")
//                case.finished:
//                    break
//                }
//            }, receiveValue: { modelEntity in
//                self.currentEntity = modelEntity
//               // self.currentEntity.name = "Air Jordan 1s"
//                self.currentEntity.name = "Cave Painting"
//                print(self.currentEntity)
//                self.currentEntity.generateCollisionShapes(recursive: true)
//                self.sceneView.installGestures([.translation, .rotation, .scale], for: self.currentEntity)
//                let anchor =  self.focusEntity?.anchor
//                print(anchor)
//                anchor?.addChild(self.currentEntity)
//             //   self.currentEntity.scale = [0.08,0.08,0.08]
//                self.sceneView.scene.addAnchor(anchor!)
//                print("modelEntity for Air Jordan 1s has been loaded.")
//                self.removeCloseButton()
//                ProgressHUD.dismiss()
//                self.modelPlacementUI()
//            })
//        }
    }
    
    var scanView = UIView()
    var progressView1 = UIProgressView()
    var progressLabel = UILabel()
    var scanningLabel = UILabel()
    
    func scanningUI(){
        buttonStackView.isHidden = true
        networkBtn.isHidden = true
        wordsBtn.isHidden = true
        videoBtn.isHidden = true
        self.libraryImageView.isHidden = true
        networksNearImg.isHidden = true
        scanView = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 95))
        scanView.backgroundColor = UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 0.9)
        
        progressLabel = UILabel(frame: CGRect(x: 20, y: 45, width: 52.5, height: 23))
        progressLabel.textColor = .systemGreen
        progressLabel.font = UIFont.systemFont(ofSize: 19, weight: .semibold)
       // progressLabel.text = "\(progressView1.progress)%"
        scanningLabel = UILabel(frame: CGRect(x: 72.5, y: 52, width: 70, height: 16))
        scanningLabel.textColor = UIColor(red: 73/255, green: 73/255, blue: 73/255, alpha: 1.0)
        scanningLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        scanningLabel.text = "Scanning..."
        progressView1 = UIProgressView(frame: CGRect(x: 20, y: 75, width: UIScreen.main.bounds.width - 40, height: 16))
        progressView1.progressTintColor = .systemGreen
        scanView.addSubview(progressLabel)
        scanView.addSubview(scanningLabel)
        scanView.addSubview(progressView1)
        view.addSubview(scanView)
    }
    
    func removeScanUI(){
        scanView.removeFromSuperview()
    }

    
    @IBAction func cancelWalkthroughAction(_ sender: Any) {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "finishedCreateWalkthrough") == false {
            let alert = UIAlertController(title: "Skip Tutorial", message: "Skip Blueprint's tutorial? If you already know how to use Blueprint, feel free to skip this part.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Skip", style: .default) { action in
                
                defaults.set(true, forKey: "finishedWalkthrough")
                self.walkthroughView.isHidden = true
                self.circle.isHidden = true
                self.walkthroughLabel.isHidden = true
                self.buttonStackView.isUserInteractionEnabled = true
                self.videoBtn.isUserInteractionEnabled = true
                self.wordsBtn.isUserInteractionEnabled = true
                self.networkBtn.isUserInteractionEnabled = true
                self.buttonStackViewBottomConstraint.constant = -87
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { action in
                //completionHandler(false)
                return
            })
            present(alert, animated: true)
        } else if defaults.bool(forKey: "finishedCreateWalkthrough") == true {
            let alert = UIAlertController(title: "Skip Tutorial", message: "Skip Network tutorial? If you already know how to create a Blueprint Network, feel free to skip this part.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Skip", style: .default) { action in
                defaults.set(true, forKey: "finishedNetworkWalkthrough")
                self.walkthroughView.removeFromSuperview()
                self.circle.removeFromSuperview()
                self.circle2.removeFromSuperview()
                self.walkthroughLabel.removeFromSuperview()
                self.buttonStackView.isUserInteractionEnabled = true
                self.videoBtn.isUserInteractionEnabled = true
                self.wordsBtn.isUserInteractionEnabled = true
                self.networkBtn.isUserInteractionEnabled = true
                self.buttonStackViewBottomConstraint.constant = -87
                self.buttonStackView.isHidden = false
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { action in
                //completionHandler(false)
                return
            })
            present(alert, animated: true)
        }
    }

    
    @objc func removeModels(_ sender: UITapGestureRecognizer){
      //  sceneView.scene.rem
    }
    
    @objc func applyFilter(_ sender: UITapGestureRecognizer){
    }
    
    @objc func hideMesh(_ sender: UITapGestureRecognizer){
        touches += 1
        if touches % 2 == 0 {
            sceneView.debugOptions.remove(.showSceneUnderstanding)
        } else {
        sceneView.debugOptions.insert(.showSceneUnderstanding) //.insert(.showSceneUnderstanding)
        }}
    
    @objc func textSettings(){
        
    }
    
    var wordsTaps = 0
    
    @IBAction func wordsAction(_ sender: Any) {
        self.uploadMessage()
//        wordsTaps += 1
//        videoTaps = 0
//        if wordsTaps % 2 == 1 {
//            isTextMode = true
//            isVideoMode = false
//            isObjectMode = false
//            scanBtn.isHidden = true
//            isScanMode = false
//    //        shareImg.image = UIImage(systemName: "gearshape.fill")
//    //        toggleBtn.setImage(UIImage(systemName: "arrow.clockwise"), for: .normal)
//            shareImg.removeGestureRecognizer(shareRecognizer)
//          //  inputContainerView.isHidden = false
//          //  networksNearImg.isHidden = true
//          //
//    //        textSettingsRecognizer = UITapGestureRecognizer(target: self, action: #selector(textSettings(_:)))
//    //        textSettingsRecognizer.delegate = self
//    //        shareImg.addGestureRecognizer(textSettingsRecognizer)
//    //
//    //        undoTextRecognizer = UITapGestureRecognizer(target: self, action: #selector(undoText(_:)))
//    //        undoTextRecognizer.delegate = self
//    //        toggleBtn.addGestureRecognizer(undoTextRecognizer)
//
//            subscription = sceneView.scene.subscribe(to: SceneEvents.Update.self) { [unowned self] in
//                self.updateSceneView(on: $0)
//            }
//
//            arViewGestureSetup()
//            overlayUISetup()
//
//            let notificationName = UIResponder.keyboardWillShowNotification
//            let selector = #selector(keyboardIsPoppingUp(notification:))
//            NotificationCenter.default.addObserver(self, selector: selector, name: notificationName, object: nil)
//
//            UIView.animate(withDuration: 0.6,
//                animations: {
//                   // self.wordsBtn.transform = CGAffineTransform(scaleX: 1.6, y: 1.6)
//                    self.wordsBtn.tintColor = UIColor.systemYellow
//                    self.videoBtn.tintColor = UIColor.white
//                },
//                completion: { _ in
//    //                UIView.animate(withDuration: 0.6) {
//    //                    self.wordsBtn.transform = CGAffineTransform.identity
//    //                }
//                })
//        } else {
//            isTextMode = false
//            isVideoMode = false
//            isObjectMode = false
//            scanBtn.isHidden = true
//            isScanMode = false
//    //        shareImg.image = UIImage(systemName: "gearshape.fill")
//    //        toggleBtn.setImage(UIImage(systemName: "arrow.clockwise"), for: .normal)
//            shareImg.removeGestureRecognizer(shareRecognizer)
//          //  inputContainerView.isHidden = false
//          //  networksNearImg.isHidden = true
//          //
//    //        textSettingsRecognizer = UITapGestureRecognizer(target: self, action: #selector(textSettings(_:)))
//    //        textSettingsRecognizer.delegate = self
//    //        shareImg.addGestureRecognizer(textSettingsRecognizer)
//    //
//    //        undoTextRecognizer = UITapGestureRecognizer(target: self, action: #selector(undoText(_:)))
//    //        undoTextRecognizer.delegate = self
//    //        toggleBtn.addGestureRecognizer(undoTextRecognizer)
//
//            //subscription.cancel()
//            sceneView.removeGestureRecognizer(swipeGesture)
//            sceneView.removeGestureRecognizer(wordsTapGesture)
//
//            UIView.animate(withDuration: 0.6,
//                animations: {
//                   // self.wordsBtn.transform = CGAffineTransform(scaleX: 1.6, y: 1.6)
//                    self.wordsBtn.tintColor = UIColor.white
//                    self.videoBtn.tintColor = UIColor.white
//                },
//                completion: { _ in
//                })
//        }
    }
    
    
    func updateSceneView(on event: SceneEvents.Update) {
        let notesToUpdate = stickyNotes.compactMap { !$0.isEditing && !$0.isDragging ? $0 : nil }
        for note in notesToUpdate {
            // Gets the 2D screen point of the 3D world point.
            guard let projectedPoint = sceneView.project(note.position) else { return }
            
            // Calculates whether the note can be currently visible by the camera.
            let cameraForward = sceneView.cameraTransform.matrix.columns.2.xyz
            let cameraToWorldPointDirection = normalize(note.transform.translation - sceneView.cameraTransform.translation)
            let dotProduct = dot(cameraForward, cameraToWorldPointDirection)
            let isVisible = dotProduct < 0

            // Updates the screen position of the note based on its visibility
            note.projection = Projection(projectedPoint: projectedPoint, isVisible: isVisible)
            note.updateScreenPosition()
        }
        
//        if let cloudSession = cloudSession {
//            cloudSession.processFrame(sceneView.session.currentFrame)
//
//            if (currentlyPlacingAnchor && enoughDataForSaving && localAnchor != nil) {
//                createCloudAnchor()
//            }
//        }
    }
    
    func reset() {
        guard let configuration = sceneView.session.configuration else { return }
        sceneView.session.run(configuration, options: .removeExistingAnchors)
        for note in stickyNotes {
            deleteStickyNote(note)
        }
    }
    
    private var videoLooper: AVPlayerLooper!
    private var player: AVQueuePlayer!
    
    @IBAction func duplicateAction(_ sender: Any) {
//        print(selectedAnchor)
//        selectedEntity?.clone(recursive: true)
        showPicker()
        
        
    }
    
    
    func showPicker() {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
       // picker.mediaTypes = ["public.movie"]
        picker.delegate = self
        present(picker, animated: true) {
            self.didTap = false
        }
    }
    
    func heightForView(text:String, font:UIFont, width:CGFloat) -> CGFloat{
        let label:UILabel = UILabel(frame: CGRect(x: 0, y: 0, width: width, height: CGFloat.greatestFiniteMagnitude))// CGRectMake(0, 0, width, CGFloat.greatestFiniteMagnitude))
        label.numberOfLines = 0
        label.lineBreakMode = NSLineBreakMode.byWordWrapping
        label.font = font
        label.text = text

        label.sizeToFit()
        return label.frame.height
    }
    
    var messageText = "Select to Edit"
    
    var documentsUrl: URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    private func saveImage(image: UIImage) -> String? {
        let fileName = "messageView.png"
        let fileURL = documentsUrl.appendingPathComponent(fileName)
        if let imageData = image.jpegData(compressionQuality: 1.0) {
           try? imageData.write(to: fileURL, options: .atomic)
            print("\(fileURL) is fileURL")
           return fileName // ----> Save fileName
        }
        print("Error saving image")
        return nil
    }
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    @objc func dismissMessageView(){
        dismissKeyboard()
        messageView.animateHide()
     //   isMessage = false
    }
    
//    func textViewDidBeginEditing(_ textView: UITextView) {
//        if textView.textColor == UIColor.lightGray {
//            textView.text = nil
//            textView.textColor = UIColor.black
//        }
//    }
//
//    func textViewDidEndEditing(_ textView: UITextView) {
//        if textView.text.isEmpty {
//            textView.text = "Type message here"
//            textView.textColor = UIColor.lightGray
//        } // disable the post button
//        //messageText = messageTextView.text
//    }
//
//    func textViewDidChange(_ textView: UITextView) { //Handle the text changes here
//        if textView.text == nil || textView.text == "" || textView.text.isEmpty {
//            postMessageButton.backgroundColor = UIColor(red: 66/255, green: 126/255, blue: 251/255, alpha: 0.5)
//            postMessageButton.isUserInteractionEnabled = false
//        } else {
//            postMessageButton.backgroundColor = UIColor(red: 66/255, green: 126/255, blue: 251/255, alpha: 1.0)
//            postMessageButton.isUserInteractionEnabled = true
//        }
//    }
    
    var messageViewURL : URL?
    var messageView = UIView()
    var messageButtonView = UIView()
    var messageTextView = UITextView()
    var postMessageButton = UIButton()
    
    func uploadMessage(){
        let messageButtonUnderline = UIView(frame: CGRect(x: 0, y: 183.5, width: self.view.frame.size.width, height: 0.5))
        messageButtonUnderline.backgroundColor = UIColor(red: 229/255, green: 229/255, blue: 234/255, alpha: 1.0)
        messageButtonView = UIView(frame: CGRect(x: 0, y: 184, width: self.view.frame.size.width, height: 50))
        messageButtonView.backgroundColor = UIColor.white
        let audioBtn = UIButton(frame: CGRect(x: 16, y: 11, width: 28, height: 28))
        audioBtn.tintColor = .link
        
       let img1 = UIImage(systemName: "airplayaudio", withConfiguration: UIImage.SymbolConfiguration(scale: .large))
        audioBtn.setImage(img1, for: .normal) //.imageView?.image =
        let photoBtn = UIButton(frame: CGRect(x: 70, y: 11, width: 28, height: 28))
        photoBtn.tintColor = .link
        let img2 = UIImage(systemName: "photo.fill.on.rectangle.fill", withConfiguration: UIImage.SymbolConfiguration(scale: .large))
        photoBtn.setImage(img2, for: .normal)
     //   photoBtn.addTarget(self, action: #selector(presentImagePicker), for: .touchUpInside)
        let addBtn = UIButton(frame: CGRect(x: 342, y: 11, width: 28, height: 28))
        addBtn.tintColor = .white
        addBtn.backgroundColor = .link
        addBtn.layer.cornerRadius = 14
        let img3 = UIImage(systemName: "plus", withConfiguration: UIImage.SymbolConfiguration(scale: .small))
        addBtn.setImage(img3, for: .normal)
        //addBtn.setImage(UIImage(systemName: "plus"), for: .normal) //.imageView?.image =
        messageButtonView.addSubview(audioBtn)
        messageButtonView.addSubview(photoBtn)
        messageButtonView.addSubview(addBtn)
        messageButtonView.layer.zPosition = CGFloat(Float.greatestFiniteMagnitude)
        messageView = UIView(frame: CGRect(x: 0, y: 274, width: UIScreen.main.bounds.width, height: 500))
        messageView.backgroundColor = .white
        messageView.clipsToBounds = true
        messageView.layer.cornerRadius = 18
        messageView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        messageView.addGestureRecognizer(tap)
//        let profilePicImageView = UIImageView(frame: CGRect(x: 20, y: 79, width: 40, height: 40))
//        profilePicImageView.layer.cornerRadius = 20
//        profilePicImageView.clipsToBounds = true
//        StorageManager.getProPic(Auth.auth().currentUser!.uid) { image in
//            profilePicImageView.image = image
//            profilePicImageView.layer.cornerRadius = 20
//        }
        let cancel = UIButton(frame: CGRect(x: 20, y: 21, width: 63, height: 53))
        cancel.titleLabel?.textColor = .black
        cancel.setTitle("Cancel", for: .normal)
        cancel.setTitleColor(.black, for: .normal)// .titleLabel?.font = UIFont.systemFont(ofSize: 17)
        cancel.addTarget(self, action: #selector(dismissMessageView), for: .touchUpInside)

        messageTextView = UITextView(frame: CGRect(x: 68, y: 79, width: 302, height: 100))
        messageTextView.delegate = self //autocorrect
        messageTextView.text = "Type message here"
        messageTextView.becomeFirstResponder()
        messageTextView.textColor = UIColor.lightGray
//        messageTextView.autocorrectionType = .no
//        messageTextView.inputAssistantItem.leadingBarButtonGroups = []
//        messageTextView.inputAssistantItem.trailingBarButtonGroups = []
//        messageTextView.inputAccessoryView = nil
        messageTextView.font = UIFont.systemFont(ofSize: 18)
        messageTextView.backgroundColor = .white
        postMessageButton = UIButton(frame: CGRect(x: 299, y: 25.67, width: 71, height: 32))
        postMessageButton.backgroundColor = UIColor(red: 66/255, green: 126/255, blue: 251/255, alpha: 0.5)
        postMessageButton.isUserInteractionEnabled = false
       // postMessageButton.isEnabled = false
        postMessageButton.setTitle("Post", for: .normal) //.titleLabel?.text = "Post"
        postMessageButton.setTitleColor(.white, for: .normal)//.titleLabel?.textColor = .white
        postMessageButton.layer.cornerRadius = 16
        postMessageButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
     //   postMessageButton.addTarget(self, action: #selector(postMessage), for: .touchUpInside)
        
      //  messageView.addSubview(profilePicImageView)
        messageView.addSubview(messageTextView)
        messageView.addSubview(messageButtonUnderline)
        messageView.addSubview(postMessageButton)
        messageView.addSubview(cancel)
        messageView.addSubview(messageButtonView)
        view.addSubview(messageView)
        
        
        
        let message = self.messageText
            let font = UIFont.systemFont(ofSize: 17, weight: .semibold) // UIFont(name: "Helvetica", size: 20.0)

            let height = self.heightForView(text: message, font: font, width: 200.0)
            print("\(height) is height")
            let messageLabel = UILabel(frame: CGRect(x: 10, y: 44, width: 200, height: height))
     //       messageLabel.sizeToFit()
        messageLabel.textAlignment = .center
        messageLabel.textColor = .white// .black
            messageLabel.text = message
        messageLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
            messageLabel.numberOfLines = 0
    //        messageLabel.backgroundColor = .white
            let anchorView = UIView(frame: CGRect(x: 0, y: 0, width: 220, height: height + 60))
        anchorView.backgroundColor = UIColor(red: 21/255, green: 31/255, blue: 43/255, alpha: 0.5) // .systemPink
        
        let profilePicImageView = UIImageView(frame: CGRect(x: 10, y: 10, width: 30, height: 30))
        profilePicImageView.layer.cornerRadius = 15
        profilePicImageView.clipsToBounds = true
        let uid = Auth.auth().currentUser?.uid ?? ""
        if Auth.auth().currentUser != nil {
           
            StorageManager.getProPic(uid) { image in
                // self.anchorUserImg.image = image
                profilePicImageView.image = image
            }
        } else {
            profilePicImageView.image = UIImage(named: "nouser")
        }
        let messageHostNameLabel = UILabel(frame: CGRect(x: 46, y: 11.5, width: 150, height: 14))
        messageHostNameLabel.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        messageHostNameLabel.textColor = .white
        let messageHostUsernameLabel = UILabel(frame: CGRect(x: 46, y: 25, width: 150, height: 11))
        messageHostUsernameLabel.font = UIFont.systemFont(ofSize: 10, weight: .regular)
        messageHostUsernameLabel.textColor = .lightGray
        if Auth.auth().currentUser != nil {
            FirestoreManager.getUser(uid) { user in
        //            if user?.name != "" {
        //              //  self.hostName = user?.name ?? ""
                    messageHostNameLabel.text = user?.name ?? ""
              //  } else {
               // self.hostName = user?.username ?? ""
                    messageHostUsernameLabel.text = "@\(user?.username ?? "[deleted]")"

                }
            
        }
            anchorView.addSubview(messageLabel)
        anchorView.addSubview(profilePicImageView)
        anchorView.addSubview(messageHostNameLabel)
        anchorView.addSubview(messageHostUsernameLabel)
        
           // anchorNode.geometry?.firstMaterial?.diffuse.contents = anchorView
          //  anchorNode.geometry?.firstMaterial?.isDoubleSided = true
        
        let imageOfMessage = anchorView.snapshot() //else { return }
        if let image = imageOfMessage {
            if let data = image.pngData() {
                let filename = getDocumentsDirectory().appendingPathComponent("messageView.png")
                print("\(filename) is filename")
                self.messageViewURL = filename
                try? data.write(to: filename)
            }
        }
        let success = saveImage(image: imageOfMessage!)
        
        
        var material = SimpleMaterial()// VideoMaterial(avPlayer: avPlayer) //UIImageView(image: pickedImageView.image) //pickedImageView.image
        material.baseColor = try! .texture(.load(contentsOf: (messageViewURL ?? URL(string: "www.google.com"))!)) //img
        
        let mesh = MeshResource.generateBox(width: 1.2, height: 0.6, depth: 0.005)   //.generatePlane(width: 2, depth: 1)
        let planeModel = ModelEntity(mesh: mesh, materials: [material])
        
        self.currentEntity = planeModel
        self.currentEntity.name = "Message by __"
      //  planeModel.setOrientation(simd_quatf(ix: 0, iy: 0, iz: 90, r: 0), relativeTo: self.currentEntity)
        print(self.currentEntity)
        self.currentEntity.generateCollisionShapes(recursive: true)
        let physics = PhysicsBodyComponent(massProperties: .default,
                                                    material: .default,
                                                        mode: .dynamic)
       // modelEntity.components.set(physics)
        self.sceneView.installGestures([.translation, .rotation, .scale], for: self.currentEntity)
        let anchor = AnchorEntity(world: [0,0.04,-1.2]) // self.focusEntity?.anchor //AnchorEntity(plane: .any)// //
        print(anchor)
      //  anchor.setOrientation(simd_quatf(ix: 90, iy: 0, iz: 0, r: 0), relativeTo: self.currentEntity) //setOrientation(simd_quatf(ix: 0, iy: 90, iz: 0, r: 0)
       // let random = self.generateRandomPhotoID(length: 20)
       // self.imageAnchorID = random
    //    self.currentAnchor = anchor!
       // anchor?.scale = [1.2,1.0,1.0]
        anchor.addChild(self.currentEntity)
        self.sceneView.scene.addAnchor(anchor)
       // self.currentEntity?.scale *= self.scale
        self.removeCloseButton()
        ProgressHUD.dismiss()
       // print("modelEntity for \(self.name) has been loaded.")
      //  self.modelPlacementUI()
//        if !connectedToNetwork {
//            self.uploadSessionPhotoAnchor()
//            self.currentSessionAnchorIDs.append(self.imageAnchorID)
//        }
        sceneView.removeGestureRecognizer(placeVideoRecognizer)
        UIView.animate(withDuration: 0.6,
            animations: {
                self.wordsBtn.tintColor = UIColor.white
                self.videoBtn.tintColor = UIColor.white
            },
            completion: { _ in
            })
    }
    
    
   
    
    @IBAction func removeAction(_ sender: Any) {
        if selectedAnchor == nil {
            sceneView.scene.removeAnchor(currentAnchor)
            
            currentEntity.removeFromParent()
            detailAnchor.removeFromParent()
//            let id = String(self.currentAnchor.id)
//            if !connectedToNetwork {
//                let docRef = self.db.collection("sessionAnchors").document(id)
//                docRef.delete()
//            }
             //.removeLast()
            if self.selectedAnchorID != "" {
                let id = self.selectedAnchorID
                if let index = self.currentSessionAnchorIDs.firstIndex(of: self.selectedAnchorID) {
                    self.currentSessionAnchorIDs.removeAll(where: { $0 == self.selectedAnchorID })
                    self.sceneManager.anchorEntities.remove(at: index)
                }
    //            let index = self.currentSessionAnchorIDs.firstIndex(of: self.selectedAnchorID)!
    //            self.currentSessionAnchorIDs.removeAll(where: { $0 == id })
    //
    //            //HAS PROBLEM AT INDEX: 0
    //
    //            self.sceneManager.anchorEntities.remove(at: index)
            }
            selectedEntity?.removeFromParent()
            placementStackView.isHidden = true
            duplicateBtn.isHidden = true
            entityName.isHidden = true
            //sceneManager.anchorEntities.remo
//            searchBtn.setImage(UIImage(systemName: "magnifyingglass"), for: .normal)
//            searchBtn.isHidden = false
            entityProfileBtn.isHidden = true
            //networksNearImg.isHidden = false
            self.networksNear()
            self.buttonStackView.isHidden = false
            anchorSettingsImg.isHidden = true
            anchorUserImg.isHidden = true
            self.optionsScrollView.isHidden = true
            self.removeOptionImages()
            self.skipBtn.isHidden = true
            self.optionTwoBtn.layer.borderColor = UIColor.clear.cgColor
            self.optionThreeBtn.layer.borderColor = UIColor.clear.cgColor
            self.optionFourBtn.layer.borderColor = UIColor.clear.cgColor
            self.optionFiveBtn.layer.borderColor = UIColor.clear.cgColor
            wordsBtn.isHidden = false
            videoBtn.isHidden = false
           // copilotBtn.isHidden = false
            self.libraryImageView.isHidden = false
//            saveButton.isHidden = true
//            numberOfEditsImg.isHidden = true
        } else {
            sceneView.scene.removeAnchor(currentAnchor)
            
            currentEntity.removeFromParent()
            sceneView.scene.removeAnchor(selectedAnchor!)
            selectedEntity?.removeFromParent()
          //  currentEntity.removeFromParent()
            detailAnchor.removeFromParent()
            if self.selectedAnchorID != "" {
                let id = self.selectedAnchorID
                if self.currentSessionAnchorIDs.count != 0 {
                  //  let index = self.currentSessionAnchorIDs.firstIndex(of: self.selectedAnchorID)!

                }
                self.currentSessionAnchorIDs.removeAll(where: { $0 == id })
                
//                if index == 0 {
//                    self.sceneManager.anchorEntities.removeFirst()
//                } else {
                //HAS PROBLEM AT INDEX: 0
                 //   self.sceneManager.anchorEntities.remove(at: index)
              // }
            }
//            if !connectedToNetwork && self.currentEntity.name != "" {
//                let id = self.selectedAnchorID// String(self.currentEntity.id)
//                let docRef = self.db.collection("sessionAnchors").document(id)
//                docRef.delete()
//            } else if !connectedToNetwork && currentEntity.name == "" || currentEntity.name == .none  {
//                let id = self.selectedAnchorID// String(self.currentAnchor.id)
//                let docRef = self.db.collection("sessionAnchors").document(id)
//                docRef.delete()
//            }
            placementStackView.isHidden = true
            duplicateBtn.isHidden = true
            entityName.isHidden = true
            anchorSettingsImg.isHidden = true
            anchorInfoStackView.isHidden = true
            anchorUserImg.isHidden = true
//            searchBtn.setImage(UIImage(systemName: "magnifyingglass"), for: .normal)
//            searchBtn.isHidden = false
            entityProfileBtn.isHidden = true
           // networksNearImg.isHidden = false
            self.networksNear()
            self.optionsScrollView.isHidden = true
            wordsBtn.isHidden = false
            videoBtn.isHidden = false
            self.libraryImageView.isHidden = false
            self.buttonStackView.isHidden = false
            self.optionsScrollView.isHidden = true
            self.removeOptionImages()
            self.optionTwoBtn.layer.borderColor = UIColor.clear.cgColor
            self.optionThreeBtn.layer.borderColor = UIColor.clear.cgColor
            self.optionFourBtn.layer.borderColor = UIColor.clear.cgColor
            self.optionFiveBtn.layer.borderColor = UIColor.clear.cgColor
    //        self.copilotBtn.isHidden = false
        }
      //  }
            
        placementStackView.isHidden = true
       //
       // shareImg.isHidden = false
    //    scanBtn.isHidden = true
        
     //   toggleBtn.isHidden = false
        
           
            networkBtn.isHidden = false
       //
        duplicateBtn.isHidden = true
        removeBtn.isHidden = true
        entityName.removeFromSuperview()
//        entityName.text = ""
//        entityName.textColor = .clear
        entityProfileBtn.isHidden = true
        entityProfileBtn.removeFromSuperview()
        
     
        
        if sceneManager.anchorEntities.count > 0 {
            sceneManager.anchorEntities.removeLast()
        }
        
        if sceneManager.anchorEntities.count >= 1 {
            print("\(sceneManager.anchorEntities.count) is the count")
         //   saveButton.isHidden = false
            undoButton.isHidden = false
         //   wordsBtnTopConstraint.constant = 60
         //   numberOfEditsImg.isHidden = false
  //          sceneInfoButton.isHidden = false
        } else {
            print("\(sceneManager.anchorEntities.count) is the count")
            saveButton.isHidden = true
            undoButton.isHidden = true
            numberOfEditsImg.isHidden = true
            sceneInfoButton.isHidden = true
        //    wordsBtnTopConstraint.constant = 11
        }
        
        updateEditCount()

        //sceneView.removeSubview(entityName)
//        entityName.removeFromSuperview()
//        entityProfileBtn.removeFromSuperview()
        networkBtn.setImage(UIImage(systemName: "network"), for: .normal)
      //  networksNearImg.isHidden = false
      //  self.networksNear()
   // }
    }
    
    func removeOptionImages(){
        self.optionOneBtn.setImage(nil, for: .normal)
        self.optionTwoBtn.setImage(nil, for: .normal)
        self.optionThreeBtn.setImage(nil, for: .normal)
        self.optionFourBtn.setImage(nil, for: .normal)
        self.optionFiveBtn.setImage(nil, for: .normal)
    }
    
    @objc func rotateEntity(){
        selectedAnchor?.setOrientation(simd_quatf(ix: 0, iy: 0, iz: 90, r: 0), relativeTo: selectedEntity)
    }
    
    var videoPlayer: AVPlayer!
    
//    var heightInPoints = CGFloat()
//    var widthInPoints = CGFloat()
    
    @objc func anchorVideo(_ sender: UITapGestureRecognizer){
        // pressing button brings up photo library
        // once selecting photo/video --> thumbnail for selection shows up in bottom right/left
        // prompt telling user to tap to place content appears
        // once user taps, then video/photo appears where tapped - if video, starts playing
        
        if self.imageAnchorChanged {
            toggleBtn.isHidden = true
            self.undoButton.isHidden = true
            self.sceneInfoButton.isHidden = true
            dismissKeyboard()
            ProgressHUD.show("Loading...")
           
         //   browseTableView.isHidden = true
          //  self.addCloseButton()
            
            let img = photoAnchorImageView.image
            
            heightInPoints = photoAnchorImageView.image?.size.height ?? 200
            let heightInPixels = heightInPoints * (photoAnchorImageView.image?.scale ?? 1)
            widthInPoints = photoAnchorImageView.image?.size.width ?? 200
            let widthInPixels = widthInPoints * (photoAnchorImageView.image?.scale ?? 1)
            print("\(heightInPixels) is height in pixels")
            print("\(widthInPixels) is width in pixels")
            var material = SimpleMaterial()// VideoMaterial(avPlayer: avPlayer) //UIImageView(image: pickedImageView.image) //pickedImageView.image
            material.baseColor = try! .texture(.load(contentsOf: imageAnchorURL!)) //img
            
            let mesh = MeshResource.generateBox(width: Float(widthInPixels) / 2000, height: Float((widthInPixels) / 2000) / 50, depth: Float(heightInPixels) / 2000)   //.generatePlane(width: 1.5, depth: 1)
           // let imgPlane = ModelEntity(mesh: mesh, materials: [material])

    //        material.baseColor = try! .texture(.load(named: "chanceposter"))
            let planeModel = ModelEntity(mesh: mesh, materials: [material])
            
            self.currentEntity = planeModel
            self.currentEntity.name = "Photo by __"
            print(self.currentEntity)
            self.currentEntity.generateCollisionShapes(recursive: true)
            let physics = PhysicsBodyComponent(massProperties: .default,
                                                        material: .default,
                                                            mode: .dynamic)
           // modelEntity.components.set(physics)
            self.sceneView.installGestures([.translation, .rotation, .scale], for: self.currentEntity)
            let anchor =  self.focusEntity?.anchor //AnchorEntity(plane: .any)// // AnchorEntity(world: [0,-0.2,0])
            print(anchor)
           // anchor?.scale = [1.2,1.0,1.0]
            anchor?.addChild(self.currentEntity)
            self.sceneView.scene.addAnchor(anchor!)
           // self.currentEntity?.scale *= self.scale
            self.removeCloseButton()
            ProgressHUD.dismiss()
           // print("modelEntity for \(self.name) has been loaded.")
            self.modelPlacementUI()
            if !connectedToNetwork {
                self.uploadSessionPhotoAnchor()
                self.currentSessionAnchorIDs.append(self.imageAnchorID)
            }
            sceneView.removeGestureRecognizer(placeVideoRecognizer)
            UIView.animate(withDuration: 0.6,
                animations: {
                    self.wordsBtn.tintColor = UIColor.white
                    self.videoBtn.tintColor = UIColor.white
                },
                completion: { _ in
                })
        } else if self.videoAnchorChanged {
           // guard let path = Bundle.main.path(forResource: "Giannis Highlights", ofType: "mp4") else { return }
            let videoUrl = self.videoAnchorURL
            let playerItem = AVPlayerItem(url: self.videoAnchorURL!)
            
            let videoPlayer = AVPlayer(playerItem: playerItem)
            self.videoPlayer = videoPlayer

            let videoMaterial = VideoMaterial(avPlayer: videoPlayer)
            let mesh = MeshResource.generateBox(width: 1.6, height: 0.2, depth: 1.0)   //.generatePlane(width: 1.5, depth: 1)
            let videoPlane = ModelEntity(mesh: mesh, materials: [videoMaterial])
           // videoPlane.name = "Giannis"

            // let anchor = AnchorEntity(anchor: focusEntity?.currentPlaneAnchor as! ARAnchor)
            let anchor = AnchorEntity(plane: .any) // AnchorEntity(anchor: focusEntity?.currentPlaneAnchor as! ARAnchor) // focusEntity?.currentPlaneAnchor//
            print(anchor)
            anchor.addChild(videoPlane)
            
            
            videoPlane.generateCollisionShapes(recursive: true)
            
           // videoPlane.
            //
            sceneView.installGestures([.translation, .rotation, .scale], for: videoPlane)
            
           // sceneView.scene.addAnchor(anchor!)
            sceneView.scene.anchors.append(anchor)
            
            videoPlayer.play()
            
            NotificationCenter.default.addObserver(self, selector: #selector(loopVideo), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: playerItem)
            sceneView.removeGestureRecognizer(placeVideoRecognizer)
            UIView.animate(withDuration: 0.6,
                animations: {
                    self.wordsBtn.tintColor = UIColor.white
                    self.videoBtn.tintColor = UIColor.white
                },
                completion: { _ in
                })
        }
        
        
    }
    
    @objc func loopVideo(notification: Notification) {
            guard let playerItem = notification.object as? AVPlayerItem else { return }
            playerItem.seek(to: CMTime.zero, completionHandler: nil)
            videoPlayer.play()
        }
    
    @objc func pauseVideo(_ sender: UITapGestureRecognizer){
        videoPlayer.pause()
    }
    
    var placeVid = UITapGestureRecognizer()
    
    var placeVideoRecognizer = UITapGestureRecognizer()
    var pauseVideoRecognizer = UITapGestureRecognizer()
    var wordsTapGesture = UITapGestureRecognizer()
    var swipeGesture = UISwipeGestureRecognizer()
    
    var videoWidth = CGFloat()
    var videoHeight = CGFloat()
    
        func generateRandomModelID(length: Int) -> String {
            let letters = "abcdefghijklmnopqrstuvwxyABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
            return String((0..<length).map{ _ in letters.randomElement()! })
        }
    
    func generateRandomPhotoID(length: Int) -> String {
        let letters = "0123456789"
        return String((0..<length).map{ _ in letters.randomElement()! })
    }
    
    func resolutionSizeForLocalVideo(url:NSURL) -> CGSize? {
        guard let track = AVAsset(url: url as URL).tracks(withMediaType: AVMediaType.video).first else { return nil }
        let size = track.naturalSize.applying(track.preferredTransform)
        print("\(CGSize(width: fabs(size.width), height: fabs(size.height))) is video size ")
        self.videoWidth = fabs(size.width)
        self.videoHeight = fabs(size.height)
        return CGSize(width: fabs(size.width), height: fabs(size.height))
    }
    
    @objc func videoAnchorURLChosen(){
        toggleBtn.isHidden = true
        self.undoButton.isHidden = true
        self.sceneInfoButton.isHidden = true
        dismissKeyboard()
        ProgressHUD.show("Loading...")
       
   //     browseTableView.isHidden = true
      //  self.addCloseButton()
        
        
        let videoUrl = self.videoAnchorURL
        let playerItem = AVPlayerItem(url: self.videoAnchorURL!)
        resolutionSizeForLocalVideo(url: self.videoAnchorURL! as NSURL)
        let videoPlayer = AVPlayer(playerItem: playerItem)
//        print("\(videoPlayer.accessibilityFrame.height) is playerItem height")
//        print("\(videoPlayer.accessibilityFrame.width) is playerItem width")
        self.videoPlayer = videoPlayer

        let videoMaterial = VideoMaterial(avPlayer: videoPlayer)
        let mesh = MeshResource.generateBox(width: Float(videoHeight) / 850, height: 0.025, depth: Float(videoWidth) / 850)   //.generatePlane(width: 1.5, depth: 1)
        let videoPlane = ModelEntity(mesh: mesh, materials: [videoMaterial])
        
        self.currentEntity = videoPlane
        self.currentEntity.name = "Video by __"
       
        print(self.currentEntity)
        self.currentEntity.generateCollisionShapes(recursive: true)
        let physics = PhysicsBodyComponent(massProperties: .default,
                                                    material: .default,
                                                        mode: .dynamic)
       // modelEntity.components.set(physics)
        self.sceneView.installGestures([.translation, .rotation, .scale], for: self.currentEntity)
        
      //  sceneView.installGestures([.translation, .rotation, .scale], for: videoPlane)
        
        let anchor =  self.focusEntity?.anchor //AnchorEntity(plane: .any)// // AnchorEntity(world: [0,-0.2,0])
       // anchor?.orientation = SIMD3(x: 0, y: 90, z: 0)
        print(anchor)
        let random = self.generateRandomPhotoID(length: 20)
        self.videoAnchorID = random
    //    self.currentAnchor = anchor!
       // anchor?.scale = [1.2,1.0,1.0]
        anchor?.addChild(self.currentEntity)
        self.sceneView.scene.addAnchor(anchor!)
        
      //  sceneView.scene.anchors.append(anchor)
        
        videoPlayer.play()
        self.removeCloseButton()
        ProgressHUD.dismiss()
       // print("modelEntity for \(self.name) has been loaded.")
        self.modelPlacementUI()
        if !connectedToNetwork {
            self.uploadSessionVideoAnchor()
            self.currentSessionAnchorIDs.append(self.videoAnchorID)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(loopVideo), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: playerItem)
        sceneView.removeGestureRecognizer(placeVideoRecognizer)
        UIView.animate(withDuration: 0.6,
            animations: {
                self.wordsBtn.tintColor = UIColor.white
                self.videoBtn.tintColor = UIColor.white
            },
            completion: { _ in
            })
    
    }
    
    @objc func playerItemDidReachEnd(notification: NSNotification) {
            if let playerItem: AVPlayerItem = notification.object as? AVPlayerItem {
                playerItem.seek(to: CMTime.zero)
            }
        }
    
    @objc func photoAnchorImageChosen() {
        // This button will be hidden if n?ot cur?rently tracking, so this can't be nil.
        
       print("\(photoAnchorImageView.image?.size.height) is photo anchor image view height")
        print("\(photoAnchorImageView.image?.size.width) is photo anchor image view width")
        
        print("\(photoAnchorImageView.image?.scale) is photo anchor image view scale")
        
        
        heightInPoints = photoAnchorImageView.image?.size.height ?? 200
        let heightInPixels = heightInPoints * (photoAnchorImageView.image?.scale ?? 1)
        widthInPoints = photoAnchorImageView.image?.size.width ?? 200
        let widthInPixels = widthInPoints * (photoAnchorImageView.image?.scale ?? 1)
        
        
        toggleBtn.isHidden = true
        self.undoButton.isHidden = true
        self.sceneInfoButton.isHidden = true
        dismissKeyboard()
        ProgressHUD.show("Loading...")
       
   //     browseTableView.isHidden = true
        //self.addCloseButton()
        
        let img = photoAnchorImageView.image
        print("\(heightInPixels) is height in pixels")
        print("\(widthInPixels) is width in pixels")
        var material = SimpleMaterial()// VideoMaterial(avPlayer: avPlayer) //UIImageView(image: pickedImageView.image) //pickedImageView.image
        material.baseColor = try! .texture(.load(contentsOf: imageAnchorURL!)) //img
        
        let mesh = MeshResource.generateBox(width: Float(widthInPixels) / 2000, height: Float((widthInPixels) / 2000) / 50, depth: Float(heightInPixels) / 2000)   //.generatePlane(width: 1.5, depth: 1)
       // let imgPlane = ModelEntity(mesh: mesh, materials: [material])

//        material.baseColor = try! .texture(.load(named: "chanceposter"))
        let planeModel = ModelEntity(mesh: mesh, materials: [material])
        
        self.currentEntity = planeModel
        self.currentEntity.name = "Photo by __"
       
        print(self.currentEntity)
        self.currentEntity.generateCollisionShapes(recursive: true)
        let physics = PhysicsBodyComponent(massProperties: .default,
                                                    material: .default,
                                                        mode: .dynamic)
       // modelEntity.components.set(physics)
        self.sceneView.installGestures([.translation, .rotation, .scale], for: self.currentEntity)
        let anchor =  self.focusEntity?.anchor //AnchorEntity(plane: .any)// // AnchorEntity(world: [0,-0.2,0])
        print(anchor)
        let random = self.generateRandomPhotoID(length: 20)
        self.imageAnchorID = random
    //    self.currentAnchor = anchor!
       // anchor?.scale = [1.2,1.0,1.0]
        anchor?.addChild(self.currentEntity)
        self.sceneView.scene.addAnchor(anchor!)
       // self.currentEntity?.scale *= self.scale
        self.removeCloseButton()
        ProgressHUD.dismiss()
       // print("modelEntity for \(self.name) has been loaded.")
        self.modelPlacementUI()
        if !connectedToNetwork {
            self.uploadSessionPhotoAnchor()
            self.currentSessionAnchorIDs.append(self.imageAnchorID)
        }
        sceneView.removeGestureRecognizer(placeVideoRecognizer)
        UIView.animate(withDuration: 0.6,
            animations: {
                self.wordsBtn.tintColor = UIColor.white
                self.videoBtn.tintColor = UIColor.white
            },
            completion: { _ in
            })
        
    }
    
    private func checkPermissions() {
        if PHPhotoLibrary.authorizationStatus() != PHAuthorizationStatus.authorized {
            PHPhotoLibrary.requestAuthorization({ (status: PHAuthorizationStatus) -> Void in () })
        }
        
        if PHPhotoLibrary.authorizationStatus() == PHAuthorizationStatus.authorized {
        } else {
            PHPhotoLibrary.requestAuthorization(requestAuthroizationHandler)
        }
    }
    
    private func requestAuthroizationHandler(status: PHAuthorizationStatus) {
        if PHPhotoLibrary.authorizationStatus() == PHAuthorizationStatus.authorized {
            print("We have access to photos")
        } else {
            print("We dont have access to photos")
        }
    }
    
    @IBAction func videoAction(_ sender: Any) {
       // videoTaps += 1
        wordsTaps = 0
       // if videoTaps % 2 == 1 {
            isVideoMode = true
            isTextMode = false
            isObjectMode = false
     //       sceneView.addGestureRecognizer(placeVid)
           // shareImg.image = UIImage(systemName: "gearshape.fill")
            toggleBtn.setImage(UIImage(systemName: "arrow.clockwise"), for: .normal)
         //   shareImg.removeGestureRecognizer(shareRecognizer)
        //    inputContainerView.isHidden = true
        self.networksNear()
           
            textSettingsRecognizer = UITapGestureRecognizer(target: self, action: #selector(textSettings(_:)))
            textSettingsRecognizer.delegate = self
      //      shareImg.addGestureRecognizer(textSettingsRecognizer)
            
    //        undoTextRecognizer = UITapGestureRecognizer(target: self, action: #selector(undoText(_:)))
    //        undoTextRecognizer.delegate = self
    //        toggleBtn.addGestureRecognizer(undoTextRecognizer)
            
            print("place video where focus node is")
            
            self.checkPermissions()
            self.imagePicker.sourceType = .photoLibrary
            self.imagePicker.mediaTypes = ["public.image", "public.movie"] //maybe just images at first
            self.imagePicker.videoQuality = .typeHigh
            self.imagePicker.videoExportPreset = AVAssetExportPresetHEVC1920x1080
       //     self.imagePicker.allowsEditing = true
            self.present(self.imagePicker, animated:  true, completion:  nil)
            
            placeVideoRecognizer = UITapGestureRecognizer(target: self, action: #selector(anchorVideo(_:)))
            placeVideoRecognizer.delegate = self
            placeVid = placeVideoRecognizer
          //  sceneView.addGestureRecognizer(placeVideoRecognizer)
            
            pauseVideoRecognizer = UITapGestureRecognizer(target: self, action: #selector(pauseVideo(_:)))
            pauseVideoRecognizer.numberOfTapsRequired = 2
            pauseVideoRecognizer.delegate = self
        //    sceneView.addGestureRecognizer(pauseVideoRecognizer)
    //
    //        let scaleGesture = UIPinchGestureRecognizer(target: self, action: #selector(scaleVideoPlayer(_:)))
    //        self.sceneView.addGestureRecognizer(scaleGesture)
            
            UIView.animate(withDuration: 0.6,
                animations: {
                   // self.wordsBtn.transform = CGAffineTransform(scaleX: 1.6, y: 1.6)
                    self.wordsBtn.tintColor = UIColor.white
                    self.videoBtn.tintColor = UIColor.systemYellow
                },
                completion: { _ in
    //                UIView.animate(withDuration: 0.6) {
    //                    self.wordsBtn.transform = CGAffineTransform.identity
    //                }
                })
        }
//        else {
//            isVideoMode = false
//            isTextMode = false
//            isObjectMode = false
//            sceneView.addGestureRecognizer(placeVid)
//           // shareImg.image = UIImage(systemName: "gearshape.fill")
//            toggleBtn.setImage(UIImage(systemName: "arrow.clockwise"), for: .normal)
//         //   shareImg.removeGestureRecognizer(shareRecognizer)
//        //    inputContainerView.isHidden = true
//            networksNearImg.isHidden = false
//
////            textSettingsRecognizer = UITapGestureRecognizer(target: self, action: #selector(textSettings(_:)))
////            textSettingsRecognizer.delegate = self
//            shareImg.removeGestureRecognizer(textSettingsRecognizer)
//
//    //        undoTextRecognizer = UITapGestureRecognizer(target: self, action: #selector(undoText(_:)))
//    //        undoTextRecognizer.delegate = self
//    //        toggleBtn.addGestureRecognizer(undoTextRecognizer)
//
//            print("place video where focus node is")
//
////            placeVideoRecognizer = UITapGestureRecognizer(target: self, action: #selector(anchorVideo(_:)))
////            placeVideoRecognizer.delegate = self
////            placeVid = placeVideoRecognizer
//            sceneView.removeGestureRecognizer(placeVideoRecognizer)
//
//            sceneView.removeGestureRecognizer(pauseVideoRecognizer)
//    //
//    //        let scaleGesture = UIPinchGestureRecognizer(target: self, action: #selector(scaleVideoPlayer(_:)))
//    //        self.sceneView.addGestureRecognizer(scaleGesture)
//
//            UIView.animate(withDuration: 0.6,
//                animations: {
//                   // self.wordsBtn.transform = CGAffineTransform(scaleX: 1.6, y: 1.6)
//                    self.wordsBtn.tintColor = UIColor.white
//                    self.videoBtn.tintColor = UIColor.white
//                },
//                completion: { _ in
//    //                UIView.animate(withDuration: 0.6) {
//    //                    self.wordsBtn.transform = CGAffineTransform.identity
//    //                }
//                })
//        }
        
  //  }
    
    var likeTaps = 0
    
    @IBAction func likeAction(_ sender: Any) {
        likeTaps += 1
        if likeTaps % 2 == 0 {
            likeBtn.setImage(UIImage(systemName: "heart"), for: .normal)
           // likeBtn.tintColor = .systemYellow
        } else {
            likeBtn.setImage(UIImage(systemName: "heart.fill"), for: .normal)
        }
    }
    
    @objc func removeAllModels(_ sender: UITapGestureRecognizer){
        if sceneManager.anchorEntities.count != 0{
            let last = self.sceneManager.anchorEntities.last
            last?.removeFromParent()
            sceneManager.anchorEntities.removeLast()
            let lastID = self.currentSessionAnchorIDs.last
            print("\(lastID) is last ID")
//            let docRef = self.db.collection("sessionAnchors").document(lastID ?? "")
//            docRef.delete()
            self.currentSessionAnchorIDs.removeLast()
            if self.entityName.isHidden == false {
                self.networkBtn.isHidden = false
                self.wordsBtn.isHidden = false
                self.videoBtn.isHidden = false
                self.libraryImageView.isHidden = false
                self.buttonStackView.isHidden = false
               // self.networksNearImg.isHidden = false
                self.networksNear()
                self.placementStackView.isHidden = true
                self.anchorInfoStackView.isHidden = true
                self.anchorSettingsImg.isHidden = true
                self.entityName.isHidden = true
                self.entityProfileBtn.isHidden = true
                self.anchorUserImg.isHidden = true
            }
            updateEditCount()
        } else {
            return
        }
       
    }
    
    @objc func undoText(_ sender: UITapGestureRecognizer){
//        sceneView.scene.rootNode.enumerateChildNodes { (node, stop) -> Void in
//            node.removeFromParentNode()
//        }
    }
    
    @objc func textSettings(_ sender: UITapGestureRecognizer){
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let settingsViewController = storyboard.instantiateViewController(withIdentifier: "TextSettingsViewController") as? TextSettingsViewController else {
            return
        }
        
        let barButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissSettings))
        settingsViewController.navigationItem.rightBarButtonItem = barButtonItem
        settingsViewController.title = "Text Settings"
        
        let navigationController = UINavigationController(rootViewController: settingsViewController)
        navigationController.modalPresentationStyle = .popover
        navigationController.popoverPresentationController?.delegate = self
        navigationController.preferredContentSize = CGSize(width: sceneView.bounds.size.width - 20, height: sceneView.bounds.size.height - 400)
        self.present(navigationController, animated: true, completion: nil)
        
//        navigationController.popoverPresentationController?.sourceView = shareImg
//        navigationController.popoverPresentationController?.sourceRect = shareImg.bounds
    }
    
    @objc func dismissSettings() {
        self.dismiss(animated: true, completion: nil)
       // updateSettings()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
      //  checkCameraAccess()
       // networkBtn.setImage(networkBtnImg, for: .normal)// .imageView?.image = networkBtnImg
        if defaults.bool(forKey: "isCreatingNetwork") == false {
            
            progressView?.isHidden = true
           // feedbackControl?.isHidden = true
            anchorUserImg.isHidden = true
            anchorInfoStackView.isHidden = true
   //         anchorSettingsImg.isHidden = true
            
        } else {
            progressView?.isHidden = false
          //  feedbackControl?.isHidden = false
            videoBtn.tintColor = .white
            scanningUI()
            
        }
       
        if (self.isMovingToParent || self.isBeingPresented){
                // Controller is being pushed on or presented.
            }
            else{
                // Controller is being shown as result of pop/dismiss/unwind.
                let defaults = UserDefaults.standard
                self.modelUid = defaults.value(forKey: "modelUid") as! String
                self.blueprintId = defaults.value(forKey: "blueprintId") as! String
                if defaults.bool(forKey: "downloadContent") == true{
                    if self.modelUid != "" {
                        self.downloadContentFromMarketplace()
                        defaults.set(false, forKey: "downloadContent")
                    }
                } else if defaults.bool(forKey: "flowerBoy") == true {
                    self.addFlowerBoy()
                    defaults.set(false, forKey: "flowerBoy")
                } else if defaults.bool(forKey: "downloadImage") == true {
                    self.downloadImageFromMarketplace()
                    defaults.set(false, forKey: "downloadImage")
                } else if defaults.bool(forKey: "showCreationSuccess") == true {
                    self.showCreationSuccessAlert()
                    defaults.set(false, forKey: "showCreationSuccess")
                } else if defaults.bool(forKey: "showContentDeleted") == true {
                    self.showContentDeletedAlert()
                    defaults.set(false, forKey: "showContentDeleted")
                }
                else if defaults.bool(forKey: "showDesignWalkthrough") == true {
                    self.userGuideAction((Any).self)
                  //  defaults.set(false, forKey: "createBlueprint")
                }
                else if defaults.bool(forKey: "connectToBlueprint") == true {
                    if self.blueprintId != "" {
                        self.connectToBlueprint()
                        defaults.set(false, forKey: "connectToBlueprint")
                    }
                }
            }
        
    }
    
    
    var currentEntity = ModelEntity()
    
    var selectedModel : Model?
    var currentAnchor = AnchorEntity()
    
    func updateEditCount(){
        if sceneManager.anchorEntities.count == 0{
           // numberOfEditsImg.image = UIImage(systemName: "1.circle.fill")
            numberOfEditsImg.isHidden = true
            saveButton.isHidden = true
      //      addButton.isHidden = false
            sceneInfoButton.isHidden = true
        } else if sceneManager.anchorEntities.count == 1{
            numberOfEditsImg.image = UIImage(systemName: "1.circle.fill")
         //   numberOfEditsImg.isHidden = false
          //  saveButton.isHidden = false
            addButton.isHidden = true
    //        sceneInfoButton.isHidden = false
        } else if sceneManager.anchorEntities.count == 2 {
            numberOfEditsImg.image = UIImage(systemName: "2.circle.fill")
        } else if sceneManager.anchorEntities.count == 3 {
            numberOfEditsImg.image = UIImage(systemName: "3.circle.fill")
        } else if sceneManager.anchorEntities.count == 4 {
            numberOfEditsImg.image = UIImage(systemName: "4.circle.fill")
        } else if sceneManager.anchorEntities.count == 5 {
            numberOfEditsImg.image = UIImage(systemName: "5.circle.fill")
        } else if sceneManager.anchorEntities.count == 6 {
            numberOfEditsImg.image = UIImage(systemName: "6.circle.fill")
        } else if sceneManager.anchorEntities.count == 7 {
            numberOfEditsImg.image = UIImage(systemName: "7.circle.fill")
        } else if sceneManager.anchorEntities.count == 8 {
            numberOfEditsImg.image = UIImage(systemName: "8.circle.fill")
        } else if sceneManager.anchorEntities.count == 9 {
            numberOfEditsImg.image = UIImage(systemName: "9.circle.fill")
        } else {
            return
        }
    }
    
    var connectedToNetwork = false
    var showedUI = false
    
    var changedOptions = false
    
    func checkScale(){
        walkthroughLabel.removeFromSuperview()
        if currentEntity.scale != SIMD3<Float>(0.85,0.75,0.75) {
            let defaults = UserDefaults.standard
            defaults.set(true, forKey: "fifth")
            self.walkthroughLabel.frame = CGRect(x: 45, y: 540, width: UIScreen.main.bounds.width - 90, height: 70)
            self.walkthroughLabel.text = "Great, now tap and hold on the asset until the asset’s name appears"
            self.sceneView.addSubview(self.walkthroughLabel)
            self.walkthroughViewLabel.text = "6 of 18"
            self.currentEntity.generateCollisionShapes(recursive: false)
         //   self.sceneView.installGestures([.scale], for: self.currentEntity)
        }
    }
    
    @objc func connectToBlueprint(){
        ProgressHUD.show("Loading...")
        view.isUserInteractionEnabled = false
  //      self.addCloseButton()
    print("\(self.modelName) is modelName")
        
        let group = DispatchGroup()

        // Enter the dispatch group before starting the first async task
        group.enter()
        FirestoreManager.getBlueprint(self.blueprintId) { blueprint in
            let modelName = blueprint?.storagePath
            print("\(modelName ?? "") is blueprint name")
            // Enter the dispatch group before starting the second async task
            group.enter()
            FirebaseStorageHelper.asyncDownloadToFilesystem(relativePath: "blueprints/\(modelName ?? "")")  { localUrl in
                self.cancellable = ModelEntity.loadModelAsync(contentsOf: localUrl).sink(receiveCompletion: { loadCompletion in
                    switch loadCompletion {
                    case.failure(let error): print("Unable to load modelEntity for Mayflower Ship Model. Error: \(error.localizedDescription)")
                        ProgressHUD.dismiss()
                    case.finished:
                        break
                    }
                    // Leave the dispatch group after finishing the second async task
                    group.leave()
                }, receiveValue: { modelEntity in
                    self.currentEntity = modelEntity
                
                    self.sceneView.installGestures([.translation, .rotation, .scale], for: self.currentEntity)
                    let anchor =  self.focusEntity?.anchor //AnchorEntity(plane: .any)// // AnchorEntity(world: [0,-0.2,0])
                    print(anchor)
                    // anchor?.scale = [1.2,1.0,1.0]
                    anchor?.addChild(self.currentEntity)
//                    let scale = model?.scale
//                    print("\(scale) is scale")
//                    self.currentEntity.scale = [Float(scale ?? 0.01), Float(scale ?? 0.01), Float(scale ?? 0.01)]
                    self.sceneView.scene.addAnchor(anchor!)
                    // self.currentEntity?.scale *= self.scale
                    print("modelEntity for Mayflower Ship Model has been loaded.")
                    ProgressHUD.dismiss()
                    self.removeCloseButton()
                    // print("modelEntity for \(self.name) has been loaded.")
                    self.modelPlacementUI()
                })
                    // Leave the dispatch group after finishing the first async task
                    group.leave()
                }
            }
        
        // Wait for all async tasks to finish and call the completion closure
        group.notify(queue: .main) {
            // Do something after all async tasks are finished
            self.view.isUserInteractionEnabled = true
        }

    }
    
    func loadCapturedRoom() -> CapturedRoom? {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let archiveURL = documentsDirectory.appendingPathComponent("capturedRoom").appendingPathExtension("plist")

        guard let data = try? Data(contentsOf: archiveURL) else { return nil }
        let propertyListDecoder = PropertyListDecoder()
        return try? propertyListDecoder.decode(CapturedRoom.self, from: data)
    }
    
    var capturedRoom: CapturedRoom?
    
    // Load the destinationURL from UserDefaults
    func loadDestinationURL() -> URL? {
        if let url = UserDefaults.standard.url(forKey: "capturedRoomDestinationURL") {
            return url
        }
        return nil
    }
    
    var destinationURL = "file:///private/var/mobile/Containers/Data/Application/DDBF6F11-ED75-44F5-95E7-60E233EDDBCF/tmp/-Mass.usdz"
    
    
    @objc func goToCapturedRoom(){
        let defaults = UserDefaults.standard
        
        let vc = ARRoomModelView(nibName: "ARRoomModelView", bundle: nil)
        //save in userdefaults for later use?
        
        if let data = defaults.object(forKey: "capturedRoom") as? Data,
           let capturedRoom = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? CapturedRoom,
           let destinationURL = defaults.url(forKey: "destinationURL") {
            vc.capturedRoom = capturedRoom
            vc.modelURL = destinationURL
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    @IBAction func confirmAction(_ sender: Any) {
        let defaults = UserDefaults.standard
        
        if optionsScrollView.isHidden == false && skipBtn.isHidden == false && anchorSettingsImg.isHidden == true {
            entityName.isHidden = true
            entityProfileBtn.isHidden = true
            promptLabel.isHidden = false
            cancelImg.isHidden = false
            placementStackBottomConstraint.constant = 15
            self.speechLabelBottomConstraint.constant = 128
            self.placementStackView.isHidden = true
            
            let anchor = AnchorEntity(plane: .any)// self.focusEntity?.anchor // AnchorEntity(world: [0,-0.2,0])
            
          //  self.currentlyPlacingAnchor = true
            print(anchor)
            print("\(anchor.position) is anchor posi")
            anchor.addChild(currentEntity)
            
            print("\(anchor.orientation) is the anchor orientation")
            print("\(currentEntity.scale) is the entity scale")
            
            self.sceneView.scene.addAnchor(anchor)
            
            anchor.setOrientation(simd_quatf(ix: 0, iy: 0, iz: 0, r: 0), relativeTo: focusEntity)
            let anchorLocation = anchor.transform.matrix // anchor.transform // focusEntity?.position
           // self.createLocalAnchor(anchorLocation: anchorLocation)
            self.sceneManager.anchorEntities.append(anchor)
//
//            self.sceneView.addGestureRecognizer(doubleTap)
//            self.sceneView.addGestureRecognizer(holdGesture)
            return
        }
        
        if self.promptCount == 6 {
            entityName.isHidden = true
            entityProfileBtn.isHidden = true
            placementStackBottomConstraint.constant = 15
            //      //topview.isHidden = false
           
            networkBtn.isHidden = false
            
            wordsBtn.isHidden = false
            videoBtn.isHidden = false
            self.libraryImageView.isHidden = false
            self.buttonStackView.isHidden = false
           // networksNearImg.isHidden = false
            self.searchImgView.isUserInteractionEnabled = true
            wordsBtn.isHidden = false
            videoBtn.isHidden = false
       //     self.copilotBtn.isHidden = false
            self.speechLabelBottomConstraint.constant = 128
//            self.promptLabel.isHidden = true
//            self.cancelImg.isHidden = true
            self.buttonStackView.isHidden = false
           // networksNearImg.isHidden = false
            self.networksNear()
            self.optionsScrollView.isHidden = true
            self.removeOptionImages()
            self.optionTwoBtn.layer.borderColor = UIColor.clear.cgColor
            self.optionThreeBtn.layer.borderColor = UIColor.clear.cgColor
            self.optionFourBtn.layer.borderColor = UIColor.clear.cgColor
            self.optionFiveBtn.layer.borderColor = UIColor.clear.cgColor
            duplicateBtn.isHidden = true
            //  shareImg.isHidden = false
            placementStackView.isHidden = true
            //  searchBtn.setImage(UIImage(systemName: "magnifyingglass"), for: .normal)
            //  toggleBtn.isHidden = false
          
            self.sceneView.addGestureRecognizer(doubleTap)
            self.sceneView.addGestureRecognizer(holdGesture)
            return
        }
        if anchorSettingsImg.isHidden != false {
            let anchor = AnchorEntity(plane: .any)// self.focusEntity?.anchor // AnchorEntity(world: [0,-0.2,0])
            
          //  self.currentlyPlacingAnchor = true
            print(anchor)
            print("\(anchor.position) is anchor posi")
            anchor.addChild(currentEntity)
            
            print("\(anchor.orientation) is the anchor orientation")
            print("\(currentEntity.scale) is the entity scale")
            
            self.sceneView.scene.addAnchor(anchor)
            
            anchor.setOrientation(simd_quatf(ix: 0, iy: 0, iz: 0, r: 0), relativeTo: focusEntity)
            let anchorLocation = anchor.transform.matrix // anchor.transform // focusEntity?.position
           // self.createLocalAnchor(anchorLocation: anchorLocation)
            self.sceneManager.anchorEntities.append(anchor)
            
            print("\(anchor.orientation) is the new anchor orientation")
            print("\(currentEntity.scale) is the search entity scale")
      
            
            //   currentEntity.components.set(mass)
            
            //  currentEntity.physicsBody = physics
            
            // let modelAnchor = ModelAnchor(model: selectedModel!, anchor: nil)
            let modelAnchor = ModelAnchor(model: currentEntity, anchor: nil)
            
            self.modelsConfirmedForPlacement.append(modelAnchor)
            print("\(modelsConfirmedForPlacement.count) is the count of count of models placed")
            print("\(modelsConfirmedForPlacement.description) is the description of models placed")
            updateEditCount()
            undoButton.image = UIImage(systemName: "arrow.counterclockwise")
            undoButton.isHidden = false
            undoButton.tintColor = .white
            //    sceneView.addSubview(undoButton)
            let id = String(self.currentEntity.id)
            if !connectedToNetwork {
                self.uploadSessionModelAnchor()
                self.currentSessionAnchorIDs.append(id)
            }
            
            if undoButton.isHidden == false {
                //    wordsBtnTopConstraint.constant = 60
   //             self.sceneInfoButton.isHidden = false
            } else {
                //   wordsBtnTopConstraint.constant = 11
                self.sceneInfoButton.isHidden = true
            }
            
         
            
            let component = ModelDebugOptionsComponent(visualizationMode: .none)
            selectedEntity?.modelDebugOptions = component
            
          //  self.updatePersistanceAvailability(for: sceneView)
           
            entityName.isHidden = true
            entityProfileBtn.isHidden = true
            placementStackBottomConstraint.constant = 15
            //      //topview.isHidden = false
           
            networkBtn.isHidden = false
            
            wordsBtn.isHidden = false
            videoBtn.isHidden = false
            self.libraryImageView.isHidden = false
            self.buttonStackView.isHidden = false
           // networksNearImg.isHidden = false
            self.searchImgView.isUserInteractionEnabled = true
            wordsBtn.isHidden = false
            videoBtn.isHidden = false
            self.editInstructions.removeFromSuperview()
            self.circle.removeFromSuperview()
     //       self.copilotBtn.isHidden = false
            self.speechLabelBottomConstraint.constant = 128
//            self.promptLabel.isHidden = true
//            self.cancelImg.isHidden = true
            self.buttonStackView.isHidden = false
           // networksNearImg.isHidden = false
            self.networksNear()
            self.optionsScrollView.isHidden = true
//            self.networksNearImg.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
//            // make the button grow to twice its original size
//            self.networkBtn.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
            self.removeOptionImages()
            self.optionTwoBtn.layer.borderColor = UIColor.clear.cgColor
            self.optionThreeBtn.layer.borderColor = UIColor.clear.cgColor
            self.optionFourBtn.layer.borderColor = UIColor.clear.cgColor
            self.optionFiveBtn.layer.borderColor = UIColor.clear.cgColor
            duplicateBtn.isHidden = true
            //  shareImg.isHidden = false
            placementStackView.isHidden = true
            //  searchBtn.setImage(UIImage(systemName: "magnifyingglass"), for: .normal)
            //  toggleBtn.isHidden = false
          
            self.sceneView.addGestureRecognizer(doubleTap)
            self.sceneView.addGestureRecognizer(holdGesture)
        } else {
            if changedOptions {
                let anchor = AnchorEntity(plane: .any)// self.focusEntity?.anchor // AnchorEntity(world: [0,-0.2,0])
                
              //  self.currentlyPlacingAnchor = true
                print(anchor)
                print("\(anchor.position) is anchor posi")
                anchor.addChild(currentEntity)
                
                print("\(anchor.orientation) is the anchor orientation")
                print("\(currentEntity.scale) is the entity scale")
                
                self.sceneView.scene.addAnchor(anchor)
                
                anchor.setOrientation(simd_quatf(ix: 0, iy: 0, iz: 0, r: 0), relativeTo: focusEntity)
                let anchorLocation = anchor.transform.matrix // anchor.transform // focusEntity?.position
               // self.createLocalAnchor(anchorLocation: anchorLocation)
                self.sceneManager.anchorEntities.append(anchor)
                
                print("\(anchor.orientation) is the new anchor orientation")
                print("\(currentEntity.scale) is the search entity scale")
          
                
                //   currentEntity.components.set(mass)
                
                //  currentEntity.physicsBody = physics
                
                // let modelAnchor = ModelAnchor(model: selectedModel!, anchor: nil)
                let modelAnchor = ModelAnchor(model: currentEntity, anchor: nil)
                
                self.modelsConfirmedForPlacement.append(modelAnchor)
                print("\(modelsConfirmedForPlacement.count) is the count of count of models placed")
                print("\(modelsConfirmedForPlacement.description) is the description of models placed")
            }
            networkBtn.isHidden = false
            wordsBtn.isHidden = false
            videoBtn.isHidden = false
            self.libraryImageView.isHidden = false
            self.buttonStackView.isHidden = false
            self.optionsScrollView.isHidden = true
            self.removeOptionImages()
            self.optionTwoBtn.layer.borderColor = UIColor.clear.cgColor
            self.optionThreeBtn.layer.borderColor = UIColor.clear.cgColor
            self.optionFourBtn.layer.borderColor = UIColor.clear.cgColor
            self.optionFiveBtn.layer.borderColor = UIColor.clear.cgColor
            self.networksNear()
            placementStackView.isHidden = true
            anchorInfoStackView.isHidden = true
            anchorSettingsImg.isHidden = true
            entityName.isHidden = true
            entityProfileBtn.isHidden = true
            anchorUserImg.isHidden = true
            self.sceneView.addGestureRecognizer(doubleTap)
            self.sceneView.addGestureRecognizer(holdGesture)
            self.changedOptions = false
        }
        }
    
    
    
    func updateNetworkImg() {
        networkBtn.setImage(networkBtnImg, for: .normal)
    }
    
    @objc func viewNetworks(){
        let storyboard = UIStoryboard(name: "Networks", bundle: nil)
        var next = storyboard.instantiateViewController(withIdentifier: "NetworksNearVC") as! NetworksNearTableViewController
       // next.modalPresentationStyle = .fullScreen
        self.present(next, animated: true, completion: nil)
        
//        let storyboard = UIStoryboard(name: "Main", bundle: nil)
//        var next = storyboard.instantiateViewController(withIdentifier: "NewUIVC") as! NewUIViewController
//        next.modalPresentationStyle = .fullScreen
//        self.present(next, animated: true, completion: nil)
    }
    
    @IBAction func networkAction(_ sender: Any) {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "finishedWalkthrough")
        walkthroughLabel.removeFromSuperview()
        circle.removeFromSuperview()
        self.circle2.removeFromSuperview()

        walkthroughView.isHidden = true
        walkthroughViewLabel.isHidden = true
        UIView.animate(withDuration: 0.6,
            animations: {
               // self.wordsBtn.transform = CGAffineTransform(scaleX: 1.6, y: 1.6)
                self.wordsBtn.tintColor = UIColor.white
                self.videoBtn.tintColor = UIColor.white
            },
            completion: { _ in
                self.isTextMode = false
                self.isVideoMode = false
                self.isObjectMode = false
            })
        viewNetworks()
        
        }
    
    var overView = UIView()
    
    var editInstructions = UILabel()
    
    @objc func showCategories(){
        self.overView = UIView(frame: CGRect(x: 0, y: categoryTableView.frame.minY - 20, width: UIScreen.main.bounds.width, height: 20))
        
        self.overView.clipsToBounds = true
        self.overView.layer.cornerRadius = 12
        self.networkBtn.isHidden = true
        self.networksNearImg.isHidden = true
        self.alertView.isHidden = true
        self.xImageView.isHidden = true
        self.overView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        scanImgView.isHidden = true
        buttonStackView.isHidden = true
        promptLabel = UILabel(frame: CGRect(x: (view.frame.width - 250) / 2, y: 70, width: 250, height: 80))
        promptLabel.numberOfLines = 2
        promptLabel.textColor = .white
        promptLabel.tintColor = .white
        promptLabel.text = "Choose a category to design your space with"
        promptLabel.textAlignment = .center
        promptLabel.font = UIFont.systemFont(ofSize: 21, weight: .semibold)
        view.addSubview(promptLabel)

        cancelImg = UIImageView(frame: CGRect(x: 22, y: 58, width: 22, height: 22))
        cancelImg.tintColor = .white
        cancelImg.isUserInteractionEnabled = true
        cancelImg.clipsToBounds = true
        cancelImg.contentMode = .scaleAspectFit
        let smallConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold, scale: .medium)
        let smallBoldDoc = UIImage(systemName: "xmark", withConfiguration: smallConfig)
        cancelImg.image = smallBoldDoc
        let tap = UITapGestureRecognizer(target: self, action: #selector(cancelAIAction))
        cancelImg.addGestureRecognizer(tap)
        view.addSubview(cancelImg)
        overView.backgroundColor = .white
        view.addSubview(overView)
        
        if selectedAnchor == nil {
            sceneView.scene.removeAnchor(currentAnchor)
            
            currentEntity.removeFromParent()
            selectedEntity?.removeFromParent()

        }
        
        
        self.editInstructions.removeFromSuperview()
        
        backArrowImg.isHidden = true
        
        self.removeOptionImages()
        self.optionTwoBtn.layer.borderColor = UIColor.clear.cgColor
        self.optionThreeBtn.layer.borderColor = UIColor.clear.cgColor
        self.optionFourBtn.layer.borderColor = UIColor.clear.cgColor
        self.optionFiveBtn.layer.borderColor = UIColor.clear.cgColor
        optionsScrollView.isHidden = true
        entityName.removeFromSuperview()
        placementStackView.isHidden = true
        entityProfileBtn.removeFromSuperview()
        
        categoryTableView.isHidden = false
        
        view.addSubview(self.categoryTableView)
    }
   
    @objc func showStyles(){
        self.overView = UIView(frame: CGRect(x: 0, y: styleTableView.frame.minY - 20, width: UIScreen.main.bounds.width, height: 20))
        
        self.overView.clipsToBounds = true
        self.overView.layer.cornerRadius = 12
        self.networkBtn.isHidden = true
        self.networksNearImg.isHidden = true
        self.alertView.isHidden = true
        self.userGuideBtn.isHidden = true
        self.closeUserGuideImgView.isHidden = true
        self.xImageView.isHidden = true
        self.videoBtn.isHidden = true
        self.wordsBtn.isHidden = true
        self.libraryImageView.isHidden = true
        self.overView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        styleTableView.isHidden = false
        scanImgView.isHidden = true
        buttonStackView.isHidden = true
        promptLabel = UILabel(frame: CGRect(x: (view.frame.width - 250) / 2, y: 70, width: 250, height: 80))
        promptLabel.numberOfLines = 2
        promptLabel.textColor = .white
        promptLabel.tintColor = .white
        promptLabel.text = "Choose a style to design your space"
        promptLabel.textAlignment = .center
        promptLabel.font = UIFont.systemFont(ofSize: 21, weight: .semibold)
        view.addSubview(promptLabel)

        cancelImg = UIImageView(frame: CGRect(x: 22, y: 58, width: 22, height: 22))
        cancelImg.tintColor = .white
        cancelImg.isUserInteractionEnabled = true
        cancelImg.clipsToBounds = true
        cancelImg.contentMode = .scaleAspectFit
        let smallConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold, scale: .medium)
        let smallBoldDoc = UIImage(systemName: "xmark", withConfiguration: smallConfig)
        cancelImg.image = smallBoldDoc
        let tap = UITapGestureRecognizer(target: self, action: #selector(cancelAIAction))
        cancelImg.addGestureRecognizer(tap)
        view.addSubview(cancelImg)
        overView.backgroundColor = .white
        view.addSubview(overView)
        
        
        self.editInstructions.removeFromSuperview()
        
        self.editInstructions = UILabel(frame: CGRect(x: 15, y: overView.frame.minY - 67, width: UIScreen.main.bounds.width - 30, height: 63))
        self.editInstructions.text = "Think of each style as a starting template. You can further design your space using Blueprint's library of 3D content after choosing the style of your choice."
        self.editInstructions.textColor = .white
        self.editInstructions.numberOfLines = 3
        self.editInstructions.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        view.addSubview(editInstructions)
            }
    
    var stylesArray = ["Minimalist Haven", "Modern Fusion", "Japanese Zen", "Art Deco Glamour", "Bohemian Oasis", "Coastal Breeze", "Scandinavian Sanctuary", "Cyberpunk", "French Countryside"]

    var categoryArray = ["Colors", "Materials", "Designs"]
    
    var styleName = ""
    
    var categoryName = ""
    
    var selectedIndexPath: IndexPath?
    
    var nextTaps = 0
    
    var skipBtn = UIButton()
    
    func addSkipButton(){
        
        skipBtn = UIButton(frame: CGRect(x: view.frame.width - 85, y: optionsScrollView.frame.minY - 50, width: 65, height: 30))
        skipBtn.backgroundColor = .systemBlue
        skipBtn.titleLabel?.textColor = .white
        skipBtn.titleLabel?.textAlignment = .center
        skipBtn.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        skipBtn.tintColor = .white
        skipBtn.clipsToBounds = true
        skipBtn.layer.cornerRadius = 6
        skipBtn.setTitle("Next", for: .normal)
        let tap = UITapGestureRecognizer(target: self, action: #selector(nextDesignStep))
        skipBtn.addGestureRecognizer(tap)
        //gestureRecognizer
        view.addSubview(skipBtn)
    }
    
    @objc func nextDesignStep(){
        nextTaps += 1
        if nextTaps == 1 {
            self.promptLabel.text = "Choose lighting to place in your space"
           // self.cancelImg
            self.overView.isHidden = true
            self.styleTableView.isHidden = true
            self.editInstructions.isHidden = true
            self.optionsScrollView.isHidden = false
          //  self.modelUid = "2mG9Q1zMR6Avye5JZHFX"
           // self.downloadOption()
        }
        if nextTaps == 2 {
            self.promptLabel.text = "Choose plants to place in your space"
           // self.cancelImg
            self.overView.isHidden = true
            self.styleTableView.isHidden = true
            self.editInstructions.isHidden = true
            self.optionsScrollView.isHidden = false
         //   self.modelUid = "2mG9Q1zMR6Avye5JZHFX"
          //  self.downloadOption()
        }
        if nextTaps == 3 {
            self.promptLabel.text = "Choose any extras to place in your space"
           // self.cancelImg
            self.overView.isHidden = true
            self.styleTableView.isHidden = true
            self.editInstructions.isHidden = true
            self.optionsScrollView.isHidden = false
         //   self.modelUid = "2mG9Q1zMR6Avye5JZHFX"
         //   self.downloadOption()
            skipBtn.frame = CGRect(x: view.frame.width - 85, y: optionsScrollView.frame.minY - 50, width: 70, height: 30)
            skipBtn.setTitle("Finish", for: .normal)
        } else if nextTaps == 4 {
                self.promptLabel.isHidden = true
               // self.cancelImg
                self.overView.isHidden = true
                self.styleTableView.isHidden = true
                self.editInstructions.isHidden = true
                self.optionsScrollView.isHidden = true
            skipBtn.removeFromSuperview()
            searchImgView.isUserInteractionEnabled = true
            placementStackView.isHidden = true
            buttonStackView.isHidden = false
            //  searchBtn.setImage(UIImage(systemName: "magnifyingglass"), for: .normal)
            //  toggleBtn.isHidden = false
            nextTaps = 0
            self.networksNear()
            cancelImg.isHidden = true
            networkBtn.isHidden = false
            networksNearImg.isHidden = false
            libraryImageView.isHidden = false
            wordsBtn.isHidden = false
            videoBtn.isHidden = false
            self.sceneView.addGestureRecognizer(doubleTap)
            self.sceneView.addGestureRecognizer(holdGesture)
            }
        
    }

    
    @objc func useStyleAlert(){
        if isLocked == true {
            let alertController = UIAlertController(title: "Create Account", message: "To use the \(self.styleName) style, create a Blueprint account.", preferredStyle: .alert)
            let saveAction = UIAlertAction(title: "Sign Up", style: .default, handler: { (_) in
                self.goToSignUp()
                
            })
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: { (_) in
             //   self.cancelAIAction()
            })
            alertController.addAction(saveAction)
            alertController.addAction(cancelAction)
            self.present(alertController, animated: true, completion: nil)
            return
        }
        let alertController = UIAlertController(title: "\(self.styleName)", message: "Use the \(self.styleName) style to design your space?", preferredStyle: .alert)
        let saveAction = UIAlertAction(title: "Design", style: .default, handler: { (_) in
            //change textures/colors of walls, floor and ceiling planes
            
            self.cancelAIAction()
            
            self.showArtwork { error in
                if let error = error {
                    // Handle the error
                    print("Error: \(error.localizedDescription)")
                } else {
                    // Artwork is shown successfully
                    print("Artwork is shown")
                }
            }

        })
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: { (_) in

        })

        alertController.addAction(saveAction)
        alertController.addAction(cancelAction)
        self.present(alertController, animated: true, completion: nil)
        
    }
    
    func showArtwork(completion: @escaping (Error?) -> Void) {
        let db = Firestore.firestore()

        // Step 1: Retrieve the style document from Firestore
        let styleRef = db.collection("styles").document("Minimalist Haven")
        styleRef.getDocument { (snapshot, error) in
            guard let document = snapshot, document.exists else {
                completion(error) // Pass the error to the completion handler
                return
            }

            // Step 2: Retrieve the texture IDs from the style document
            guard let textureIDs = document.data()?["artworkModelIds"] as? [String] else {
                completion(nil) // No texture IDs found for the style
                return
            }

            // Step 3: Set optionsIDArray to artworkModelIds array from Firebase
            self.optionsIDArray = textureIDs

            ProgressHUD.show("Loading...")

            // Create a dispatch group
            let dispatchGroup = DispatchGroup()

            // Enter the dispatch group
            dispatchGroup.enter()

            for i in 0..<self.optionsIDArray.count {
                self.updateOptionsCompletion(index: i) {
                    if i == self.optionsIDArray.count - 1 {
                        // Leave the dispatch group after the last iteration
                        dispatchGroup.leave()
                    }
                }
            }

            // Notify when all updateOptions calls have finished
            dispatchGroup.notify(queue: .main) {
                self.categoryTableView.isHidden = true
                self.overView.isHidden = true
                self.promptLabel.text = "Choose artwork to design your space"

                self.addSkipButton()
                self.optionsScrollView.isHidden = false
                self.modelUid = self.optionsIDArray.first ?? ""
                self.downloadOption()

                completion(nil) // Notify the caller that artwork is shown successfully
            }
        }
    }

    
    var isLocked = false

    
    @objc func styleImageTapped(_ gesture: UITapGestureRecognizer) {
        guard let imageView = gesture.view as? UIImageView,
              let cell = imageView.superview?.superview as? StyleTableViewCell,
              let tableView = cell.superview as? UITableView,
              let indexPath = tableView.indexPath(for: cell) else { return }

        // Remove border from all image views in the table view
        for case let visibleCell as StyleTableViewCell in tableView.visibleCells {
            for subview in visibleCell.contentView.subviews {
                if let imageView = subview as? UIImageView {
                    imageView.layer.borderWidth = 0
                }
            }
        }

        // Add border to the tapped image view
        imageView.layer.borderColor = UIColor.systemYellow.cgColor
        imageView.layer.borderWidth = 3.5

        // Get the selected style name
        if let selectedStyleName = getSelectedStyleName(for: indexPath, tag: imageView.tag) {
            print("\(selectedStyleName) is the selected style")
            self.styleName = selectedStyleName
            self.useStyleAlert()
        }
    }

    func getSelectedStyleName(for indexPath: IndexPath, tag: Int) -> String? {
        let index = indexPath.row * 3 + tag
        guard index < stylesArray.count else { return nil }

        let selectedStyle = stylesArray[index]
        
        let isFirstFiveUnlocked = index < 5 // Adjust the condition based on the desired range of unlocked styles
        let isStyleLocked = !isFirstFiveUnlocked && Auth.auth().currentUser == nil
            
            if isStyleLocked {
                print("Selected style is locked.")
                // Perform any additional actions for locked styles, such as showing an alert
                isLocked = true
            } else {
                print("Selected style is unlocked.")
                // Perform any additional actions for unlocked styles
                isLocked = false
            }
        
        return selectedStyle
    }

    @objc func categoryImageTapped(_ gesture: UITapGestureRecognizer) {
        guard let imageView = gesture.view as? UIImageView,
              let cell = imageView.superview?.superview as? CategoryTableViewCell,
              let tableView = cell.superview as? UITableView,
              let indexPath = tableView.indexPath(for: cell) else { return }

        // Remove border from all image views in the table view
        for case let visibleCell as CategoryTableViewCell in tableView.visibleCells {
            for subview in visibleCell.contentView.subviews {
                if let imageView = subview as? UIImageView {
                    imageView.layer.borderWidth = 0
                }
            }
        }

        // Add border to the tapped image view
        imageView.layer.borderColor = UIColor.systemYellow.cgColor
        imageView.layer.borderWidth = 3.5
        
        if let selectedCategoryName = getSelectedCategoryName(for: indexPath, tag: imageView.tag) {
            print("\(selectedCategoryName) is the selected style")
            self.categoryName = selectedCategoryName
            ProgressHUD.show("Loading...")
            
            // Create a dispatch group
            let dispatchGroup = DispatchGroup()
            
            // Enter the dispatch group
            dispatchGroup.enter()
            
            for i in 0..<self.optionsIDArray.count {
                self.updateOptionsCompletion(index: i) {
                    if i == self.optionsIDArray.count - 1 {
                        // Leave the dispatch group after the last iteration
                        dispatchGroup.leave()
                    }
                }
            }
            
            // Notify when all updateOptions calls have finished
            dispatchGroup.notify(queue: .main) {
                self.categoryTableView.isHidden = true
                self.overView.isHidden = true
                self.optionsScrollView.isHidden = false
                self.addBackArrow()
                self.modelUid = "2mG9Q1zMR6Avye5JZHFX"
                self.downloadOption()
            }
        }

//        // Get the selected style name
//        if let selectedCategoryName = getSelectedCategoryName(for: indexPath, tag: imageView.tag) {
//            print("\(selectedCategoryName) is the selected style")
//            self.categoryName = selectedCategoryName
//            ProgressHUD.show("Loading...")
//            for i in 0..<self.optionsIDArray.count {
//                self.updateOptions(index: i)
//            }
//            self.categoryTableView.isHidden = true
//            self.overView.isHidden = true
//            self.optionsScrollView.isHidden = false
//            self.addBackArrow()
//            self.modelUid = "2mG9Q1zMR6Avye5JZHFX"
//            self.downloadOption()
//        }
    }
    
    var backArrowImg = UIImageView()
    
    func addBackArrow(){
        backArrowImg.frame = CGRect(x: 24, y: optionsScrollView.frame.minY - 50, width: 39, height: 30)
        backArrowImg.image = UIImage(systemName: "arrowshape.backward.fill")
        backArrowImg.backgroundColor = .clear
        backArrowImg.tintColor = .white
        backArrowImg.isUserInteractionEnabled = true
        backArrowImg.isHidden = false

        let tap = UITapGestureRecognizer(target: self, action: #selector(showCategories))
        backArrowImg.addGestureRecognizer(tap)
        //gestureRecognizer
        view.addSubview(backArrowImg)
    }
    
    func getSelectedCategoryName(for indexPath: IndexPath, tag: Int) -> String? {
        let index = indexPath.row * 3 + tag
        guard index < categoryArray.count else { return nil }

        let selectedCategory = categoryArray[index]
        
        return selectedCategory
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableView == styleTableView {
            let cell = tableView.dequeueReusableCell(withIdentifier: StyleTableViewCell.identifier, for: indexPath) as! StyleTableViewCell
            
            tableView.rowHeight = 130
            // Determine the index in the styles array based on the row
            let index = indexPath.row * 3
            
            let isFirstFiveUnlocked = index < 5  // Adjust the condition based on the desired range of unlocked styles
                
                cell.configure(with: stylesArray[index], isFirstFiveUnlocked: isFirstFiveUnlocked)
                cell.configure2(with: stylesArray[index + 1], isFirstFiveUnlocked: isFirstFiveUnlocked)
                cell.configure3(with: stylesArray[index + 2], isFirstFiveUnlocked: isFirstFiveUnlocked)
            
            // Add a tap gesture recognizer to each image view
            cell.styleImageView1.tag = 0
            cell.styleImageView1.isUserInteractionEnabled = true
            let tapGesture1 = UITapGestureRecognizer(target: self, action: #selector(styleImageTapped(_:)))
            cell.styleImageView1.addGestureRecognizer(tapGesture1)
            
            cell.styleImageView2.tag = 1
            cell.styleImageView2.isUserInteractionEnabled = true
            let tapGesture2 = UITapGestureRecognizer(target: self, action: #selector(styleImageTapped(_:)))
            cell.styleImageView2.addGestureRecognizer(tapGesture2)
            
            cell.styleImageView3.tag = 2
            cell.styleImageView3.isUserInteractionEnabled = true
            let tapGesture3 = UITapGestureRecognizer(target: self, action: #selector(styleImageTapped(_:)))
            cell.styleImageView3.addGestureRecognizer(tapGesture3)
            return cell
        } else if tableView == categoryTableView {
            let cell = tableView.dequeueReusableCell(withIdentifier: CategoryTableViewCell.identifier, for: indexPath) as! CategoryTableViewCell
            tableView.rowHeight = 130
            
            // Determine the index in the styles array based on the row
            let index = indexPath.row * 3
            
            // Configure the cell with the corresponding styles
            cell.configure()
            
            cell.configure2()
            cell.configure3()
            
            // Add a tap gesture recognizer to each image view
            cell.categoryImageView1.tag = 0
            cell.categoryImageView1.isUserInteractionEnabled = true
            let tapGesture1 = UITapGestureRecognizer(target: self, action: #selector(categoryImageTapped(_:)))
            cell.categoryImageView1.addGestureRecognizer(tapGesture1)
            
            cell.categoryImageView2.tag = 1
            cell.categoryImageView2.isUserInteractionEnabled = true
            let tapGesture2 = UITapGestureRecognizer(target: self, action: #selector(categoryImageTapped(_:)))
            cell.categoryImageView2.addGestureRecognizer(tapGesture2)
            
            cell.categoryImageView3.tag = 2
            cell.categoryImageView3.isUserInteractionEnabled = true
            let tapGesture3 = UITapGestureRecognizer(target: self, action: #selector(categoryImageTapped(_:)))
            cell.categoryImageView3.addGestureRecognizer(tapGesture3)
            return cell
        }
        return UITableViewCell()
    }

//    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
//        return 3
//    }
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == styleTableView {
            return stylesArray.count / 3
        } else if tableView == categoryTableView {
            return 1
        }

        fatalError("Unexpected tableView")
    }
    
    
    let cameraImg = UIImageView(frame: CGRect(x: 280, y: 738, width: 50, height: 50))
    let recordView = UIView(frame: CGRect(x: (UIScreen.main.bounds.width * 0.5) - 40, y: 723, width: 80, height: 80))
    let recordAroundView = UIView(frame: CGRect(x: (UIScreen.main.bounds.width * 0.5) - 46, y: 717, width: 92, height: 92))
    
    
    @objc func takePhoto(_ sender: UITapGestureRecognizer){
        sceneView.snapshot(saveToHDR: false) { (image) in
          
          // Compress the image
          let compressedImage = UIImage(data: (image?.pngData())!)
          // Save in the photo album
          UIImageWriteToSavedPhotosAlbum(compressedImage!, nil, nil, nil)
        }}
    
    @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {

        if let error = error {
            print("Error Saving ARKit Scene \(error)")
        } else {
            print("ARKit Scene Successfully Saved")
        }
    }
    
    
    
    var creatorUid = ""
    
    @objc func anchorUserProfile(){
        let user = self.creatorUid
        
        let vc = UserProfileViewController.instantiate(with: user) //(user:user)
        let navVC = UINavigationController(rootViewController: vc)
       // var next = UserProfileViewController.instantiate(with: user)
       //  navVC.modalPresentationStyle = .fullScreen
      //  self.navigationController?.pushViewController(next, animated: true)
        present(navVC, animated: true)
    }
    
    @objc func goToProfile(_ sender: UITapGestureRecognizer){
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
      //  let modelUid = "6CwMVBiRJob46q4gR5VV" // modelId1
        var next = ObjectProfileViewController.instantiate(with: modelUid)
        next.modalPresentationStyle = .fullScreen
   //     self.navigationController?.pushViewController(ObjectProfileViewController.instantiate(with: modelUid), animated: true)
        self.present(next, animated: true, completion: nil)

    }
    
    var mapProvider: MCPeerID?
    var scanProgress = 0.0
    
    @objc func share(_ sender: UITapGestureRecognizer){
//        let storyboard = UIStoryboard(name: "Networks", bundle: nil)
//        var next = storyboard.instantiateViewController(withIdentifier: "ShareVC") as! ShareViewController
//        // next.modalPresentationStyle = .fullScreen
//        self.present(next, animated: true, completion: nil)
        
        sceneView.session.getCurrentWorldMap { worldMap, error in
            guard let map = worldMap
                else { print("Error: \(error!.localizedDescription)"); return }
            guard let data = try? NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true)
                else { fatalError("can't encode map") }
          //  let dataIsCritical = data.priority == .critical
            //self.multipeerSession.sendToAllPeers(data)
           // self.multipeerSession.sendToAllPeers(data, reliably: dataIsCritical)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Prevent the screen from being dimmed to avoid interrupting the AR experience.
        UIApplication.shared.isIdleTimerDisabled = true
        locationManager = CLLocationManager()
        // This will cause either |locationManager:didChangeAuthorizationStatus:| or
        // |locationManagerDidChangeAuthorization:| (depending on iOS version) to be called asynchronously
        // on the main thread. After obtaining location permission, we will set up the ARCore session.
        locationManager?.delegate = self
        // locationManager?.distanceFilter = 20
        locationManager?.allowsBackgroundLocationUpdates = true
        locationManager?.startUpdatingLocation()
       // checkCameraAccess()
//        self.checkWalkthrough()

    }
    
    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
    
    func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
        
    }

    
    
    /// Adds The Video Labels To The VideoNodeSK
    func addDataToVideoNode(){
//
//        videoNode?.addVideoDataLabels()
//        videoPlayerCreated = true
    }
    
//    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
//        for anchor in anchors {
//            guard let planeAnchor = anchor as? ARPlaneAnchor else { continue }
//
//            var material = SimpleMaterial()
//            material.baseColor = try! .texture(.load(named: "wildtextures_mossed-tree-bark-seamless-2k-texture"))
//            let plane = createPlane(for: planeAnchor, material: material)
//        //    sceneView.scene.addAnchor(plane)
//        }
//    }
    

    func session(_ session: ARSession, didFailWithError error: Error) {
        guard error is ARError else { return }
        let errorWithInfo = error as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        let errorMessage = messages.compactMap({ $0 }).joined(separator: "\n")
        DispatchQueue.main.async {
            // Present an alert informing about the error that has occurred.
            let alertController = UIAlertController(title: "The AR session failed.", message: errorMessage, preferredStyle: .alert)
            let restartAction = UIAlertAction(title: "Restart Session", style: .default) { _ in
                alertController.dismiss(animated: true, completion: nil)
                //self.resetButtonPressed(self)
            }
            alertController.addAction(restartAction)
            self.present(alertController, animated: true, completion: nil)
        }
        
        
    }
    
    @IBAction func saveAction(_ sender: Any) {
        //saveAlert()
//        self.updatePersistanceAvailability(for: sceneView)
//        self.handlePersistence(for: sceneView)
        
        if sceneManager.isPersistenceAvailable {
            sceneManager.shouldSaveSceneToSystem = true
            print("should save scene to system is true")
            print("\(sceneManager.persistenceURL) is persist url")
            print("\(String(describing: sceneManager.scenePersistenceData)) is persist data")
        }
        
    }
    
    
    @objc func saveAlert(){
        let defaults = UserDefaults.standard
       
        
        
        let alertController = UIAlertController(title: "Save Network", message: "Create a name for this Blueprint Network.", preferredStyle: .alert)
        let saveAction = UIAlertAction(title: "Save", style: .default, handler: { (_) in
            let nameTextField = alertController.textFields![0]
            let name = (nameTextField.text ?? "").isEmpty ? "My Room" : nameTextField.text!
            if name == "" || name == " " || name == "My Room" {
                return
            } else {
                self.saveMap()
            }
            
        })
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: { (_) in
            self.wordsBtn.isHidden = false
            self.videoBtn.isHidden = false
            self.libraryImageView.isHidden = false
            self.buttonStackView.isHidden = false
            self.networkBtn.isHidden = false
            self.networksNearImg.isHidden = false
            //self.showAllUI()
        })
        alertController.addTextField { (textField) in
            textField.placeholder = "My Room"
            textField.autocapitalizationType = .sentences
            //textField.placeholder = "Network Name"
        }
        alertController.addAction(saveAction)
        alertController.addAction(cancelAction)
        self.present(alertController, animated: true, completion: nil)
    }
    
 
    
    var pickedImageView = UIImageView()
    
    private func getTransformForPlacement(in arView: CustomARView) -> simd_float4x4? {
        guard let query = arView.makeRaycastQuery(from: arView.center, allowing: .estimatedPlane, alignment: .any) else {
            return nil
        }
        
        guard let raycastResult = arView.session.raycast(query).first else {return nil}
        
        return raycastResult.worldTransform
    }
    
    var searchTaps = 0
    
    private var allModels       = [Model]()
    private var searchedModels  = [Model]()

    let addButton = UIButton(frame: CGRect(x: 38, y: 728, width: 52, height: 52))
  
    
    @objc func editAlert(){
        if let viewController = self.storyboard?.instantiateViewController(
            withIdentifier: "BlueprintViewController") {
            viewController.modalPresentationStyle = .fullScreen
            self.present(viewController, animated: true)
        }
    }
    
    @objc func searchUI(){
    let defaults = UserDefaults.standard
    
        isVideoMode = false
        isTextMode = false
        isObjectMode = false
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
       // print("\(LaunchViewController.auth.currentUser?.uid) is the current user id")
        
        var next = storyboard.instantiateViewController(withIdentifier: "SearchVC") as! SearchViewController
      
        next.modalPresentationStyle = .fullScreen
        present(next, animated: true, completion: nil)
        
     
        
        UIView.animate(withDuration: 0.6,
            animations: {
               // self.wordsBtn.transform = CGAffineTransform(scaleX: 1.6, y: 1.6)
                self.wordsBtn.tintColor = UIColor.white
                self.videoBtn.tintColor = UIColor.white
            },
            completion: { _ in
//                UIView.animate(withDuration: 0.6) {
//                    self.wordsBtn.transform = CGAffineTransform.identity
//                }
            })

    }
    
    
   
    
    let storedData = UserDefaults.standard
    let mapKey = "ar.worldmap"
    var heightInPoints = CGFloat()
    var widthInPoints = CGFloat()
    var imageAnchorURL : URL?
    var videoAnchorURL : URL?
    private var imageAnchorChanged = false
    private var videoAnchorChanged = false
    private let imagePicker        = UIImagePickerController()
    var photoAnchorImageView = UIImageView()
    
//    var worldMapData: Data? = {
//        storedData.data(forKey: mapKey)
//    }()
    
    func saveMap(){
        let defaults = UserDefaults.standard
        
//        if defaults.bool(forKey: "finishedWalkthrough") == false {
//            defaults.set(true, forKey: "sixteenth")
//            walkthroughLabel.removeFromSuperview()
//            circle.removeFromSuperview()
//
//            circle.frame = CGRect(x: 294, y: 50, width: 40, height: 40)
//            circle.backgroundColor = .clear
//            circle.layer.cornerRadius = 20
//            circle.clipsToBounds = true
//            circle.layer.borderColor = UIColor.systemBlue.cgColor
//            circle.layer.borderWidth = 4
//            circle.isUserInteractionEnabled = false
//            circle.alpha = 1.0
//                // sceneView.addSubview(circle)
//            self.walkthroughLabel.numberOfLines = 6
//            self.walkthroughLabel.frame = CGRect(x: 20, y: 530, width: UIScreen.main.bounds.width - 40, height: 130)
//            self.walkthroughLabel.text = "Great! You’ve created your first Blueprint Network. Now you can connect to that Network any time you are back at this location by clicking the Network button and selecting your Network. This will download all digital assets back into place of where you saved them."
//            self.sceneView.addSubview(self.walkthroughLabel)
//            self.walkthroughViewLabel.text = "17 of 18"
//
//            let delay = 1
//            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(Int(delay))) {
//                //self.topView.addSubview(self.circle)
//                UIView.animate(withDuration: 0.85, delay: 0, options: [.curveEaseInOut, .repeat, .autoreverse], animations: {
//                    self.circle.alpha = 0.1
//                    defaults.set(true, forKey: "seventeenth")
//                       })
//
//            }
//        }
        
      
        sceneView.session.getCurrentWorldMap { (worldMap, _) in
               
               if let map: ARWorldMap = worldMap {
                   
                   let data = try! NSKeyedArchiver.archivedData(withRootObject: map,
                                                         requiringSecureCoding: true)
                   
                   let savedMap = UserDefaults.standard
                   savedMap.set(data, forKey: "WorldMap")
                   //worldMap?.anchors
                   savedMap.synchronize()
                   print("world map saved")
                   ProgressHUD.show("Saving Network")
                   let delay = 1.5
                   DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(Int(delay))) {
                       ProgressHUD.dismiss()
                       SCLAlertView().showSuccess("Network Saved", subTitle: "Users can now connect to your Blueprint Network")
                       self.saveButton.isHidden = true
                       self.undoButton.isHidden = true
                       self.numberOfEditsImg.isHidden = true
                   }
               }
           }
    }
    
    @objc func showCreationSuccessAlert(){
        SCLAlertView().showSuccess("Success!", subTitle: "Your work was successfully uploaded to the Marketplace and saved to your Profile! Check it out in your Library or on your Profile.")
    }
    
    @objc func showContentDeletedAlert() {
        SCLAlertView().showSuccess("Content Deleted", subTitle: "Your work was successfully removed from the Marketplace and your Profile.")
    }
    
    @objc func dismissKeyboard() {
       // searchBar.isHidden = true
        view.endEditing(true)
    }
    
    
    
    //MARK: --- Public Functions ---
    public func reloadData() {
        
        /// reset
        allModels = [Model]()
        searchedModels = [Model]()

        /// Suggested Users
        FirestoreManager.getAllModels { [self] models in
            allModels = models.shuffled()
            searchedModels = models.shuffled()
            updateUI()
        }}

        //MARK: --- MainFunctions ---
        private func updateUI() {
          //  browseTableView.reloadData()
        }

    func printModels(){
        FirestoreManager.getAllModels { [self] models in
            allModels = models.shuffled()
            // searchedModels = models.shuffled()
            //updateUI()
            print("\(allModels.count) is the all models count")
            print("\(allModels.capacity) is the all models capacity")
        }//}
        
    }
    
    var networkName = ""
    var networkModel = "" //maybe modelEntity or something else?
  //  var photoAnchorImageView = UIImageView()
    
    func uploadNetwork(){
        let lat = self.currentLocation?.coordinate.latitude
        let long = self.currentLocation?.coordinate.longitude
        self.db.collection("networks").addDocument(data: [
            "latitude" : NSNumber(value: lat!),
            "longitude" : NSNumber(value: long!),
            "host" : Auth.auth().currentUser?.uid,
            "geohash" : GFUtils.geoHash(forLocation: CLLocationCoordinate2D(latitude: lat!, longitude: long!)),
         //   "hostUsername" : Auth.auth().currentUser?.uid,
            "rating" : "",
            "likes" : 0,
            "comments" : 0,
            "name" : self.networkName,
            "dislikes" : 0,
            "contentType" : "network",
            "id" : "",
            "isPublic" : true,
            "password" : "",
            "timeStamp" : Date(),
            "placeId" : "",
            "interactionCount" : 0,
            "amountEarned" : 0,
            "description" : "",
            "anchorIDs" : [""],
            "historyUsers" : [""],
            "currentUsers" : [""],
            "size" : 0,
            ], completion: { err in
            if let err = err {
                print("Error adding document for loser notification: \(err)")
            } else {
                print("added anchor to firestore")
             //   self.addPoints()
                let host = Auth.auth().currentUser?.uid ?? ""
                FirestoreManager.getUser(host) { user in
                    let hostPointsRef = self.db.collection("users").document(host)
                    hostPointsRef.updateData([
                         "points": FieldValue.increment(Int64(20))
                        ])
            }
        }
            })
        
    }
    
    var imageAnchorID = ""
    
    var videoAnchorID = ""
    
    func uploadSessionPhotoAnchor(){
        let lat = self.currentLocation?.coordinate.latitude
        let long = self.currentLocation?.coordinate.longitude
        print("\(self.currentEntity.id) is current entity id")
        print("\(self.currentEntity.scale.x) is current entity scale")
        let id = self.imageAnchorID //NSUUID().uuidString //uuid
        var userName = ""
//        if Auth.auth().currentUser?.uid ?? "" != nil {
//            let host = Auth.auth().currentUser?.uid ?? ""
//            FirestoreManager.getUser(host) { user in
//                if user?.name != nil && user?.name != ""{
//                    userName = user?.name ?? ""
//                } else {
//                    userName = user?.username ?? ""
//                }
//            }
//        }
        self.db.collection("sessionAnchors").document(id).setData([
            "latitude" : NSNumber(value: lat!),
            "longitude" : NSNumber(value: long!),
            "host" : Auth.auth().currentUser?.uid ?? "",
            "geohash" : GFUtils.geoHash(forLocation: CLLocationCoordinate2D(latitude: lat!, longitude: long!)),
         //   "hostUsername" : Auth.auth().currentUser?.uid,
            "likes" : 0,
            "comments" : 0,
            "name" : "Photo by \(Auth.auth().currentUser?.uid ?? "")", //"Photo by \(userName)",
            "dislikes" : 0,
            "contentType" : "sessionPhotoAnchor",
            "id" : id,
            "isPublic" : true,
            "timeStamp" : Date(),
            "placeId" : "",
            "interactionCount" : 0,
            "scale" : 1,
            "description" : "",
            "size" : 0,
        ])
    }
    
    func uploadSessionVideoAnchor(){
        let lat = self.currentLocation?.coordinate.latitude
        let long = self.currentLocation?.coordinate.longitude
        print("\(self.currentEntity.id) is current entity id")
        print("\(self.currentEntity.scale.x) is current entity scale")
        let id = self.videoAnchorID //NSUUID().uuidString //uuid
        var userName = ""
//        if Auth.auth().currentUser?.uid ?? "" != nil {
//            let host = Auth.auth().currentUser?.uid ?? ""
//            FirestoreManager.getUser(host) { user in
//                if user?.name != nil && user?.name != ""{
//                    userName = user?.name ?? ""
//                } else {
//                    userName = user?.username ?? ""
//                }
//            }
//        }
        self.db.collection("sessionAnchors").document(id).setData([
            "latitude" : NSNumber(value: lat!),
            "longitude" : NSNumber(value: long!),
            "host" : Auth.auth().currentUser?.uid ?? "",
            "geohash" : GFUtils.geoHash(forLocation: CLLocationCoordinate2D(latitude: lat!, longitude: long!)),
         //   "hostUsername" : Auth.auth().currentUser?.uid,
            "likes" : 0,
            "comments" : 0,
            "name" : "Photo by \(Auth.auth().currentUser?.uid ?? "")", //"Photo by \(userName)",
            "dislikes" : 0,
            "contentType" : "sessionVideoAnchor",
            "id" : id,
            "isPublic" : true,
            "timeStamp" : Date(),
            "placeId" : "",
            "interactionCount" : 0,
            "scale" : 1,
            "description" : "",
            "size" : 0,
        ])
    }
    
    func uploadSessionModelAnchor(){
        let lat = self.currentLocation?.coordinate.latitude
        let long = self.currentLocation?.coordinate.longitude
        print("\(self.currentEntity.id) is current entity id")
        print("\(self.currentEntity.scale.x) is current entity scale")
        let id = String(self.currentEntity.id)
        self.db.collection("sessionAnchors").document(id).setData([
            "latitude" : NSNumber(value: lat!),
            "longitude" : NSNumber(value: long!),
            "host" : Auth.auth().currentUser?.uid ?? "",
            "geohash" : GFUtils.geoHash(forLocation: CLLocationCoordinate2D(latitude: lat!, longitude: long!)),
         //   "hostUsername" : Auth.auth().currentUser?.uid,
            "likes" : 0,
            "comments" : 0,
            "name" : self.currentEntity.name,
            "dislikes" : 0,
            "contentType" : "sessionModelAnchor",
            "id" : id,
            "modelId" : self.modelUid,
            "isPublic" : true,
            "timeStamp" : Date(),
            "placeId" : "",
            "interactionCount" : 0,
            "scale" : self.currentEntity.scale.x,
            "description" : "",
            "size" : 0,
        ])
    }
    
   
    func loadMap(){
        let storedData = UserDefaults.standard

            if let data = storedData.data(forKey: "WorldMap") {

                if let unarchiver = try? NSKeyedUnarchiver.unarchivedObject(
                                       ofClasses: [ARWorldMap.classForKeyedUnarchiver()],
                                            from: data),
                   let worldMap = unarchiver as? ARWorldMap {

                        config.initialWorldMap = worldMap
                        sceneView.session.run(config)
                    print("world map loaded")
                }
            }
    }
    
    func addFlowerBoy() {
        toggleBtn.isHidden = true
        self.undoButton.isHidden = true
        self.sceneInfoButton.isHidden = true
        dismissKeyboard()
        ProgressHUD.show("Loading...")
      //  self.addCloseButton()
      //  view.endEditing(true)
        let mesh = MeshResource.generatePlane(width: 1.05, depth: 1.5)// .generatePlane(width: 1.5, height: 0.9)    // 16:9 video

        var material = SimpleMaterial()// VideoMaterial(avPlayer: avPlayer) //UIImageView(image: pickedImageView.image) //pickedImageView.image
        material.baseColor = try! .texture(.load(named: "flowerboy"))

//        material.baseColor = try! .texture(.load(named: "chanceposter"))
        let planeModel = ModelEntity(mesh: mesh, materials: [material])
        
        self.currentEntity = planeModel
        self.currentEntity.name = "Flower Boy Poster"
        print(self.currentEntity)
        self.currentEntity.generateCollisionShapes(recursive: true)
        let physics = PhysicsBodyComponent(massProperties: .default,
                                                    material: .default,
                                                        mode: .dynamic)
       // modelEntity.components.set(physics)
        self.sceneView.installGestures([.translation, .rotation, .scale], for: self.currentEntity)
        let anchor =  self.focusEntity?.anchor //AnchorEntity(plane: .any)// // AnchorEntity(world: [0,-0.2,0])
        print(anchor)
       // anchor?.scale = [1.2,1.0,1.0]
        anchor?.addChild(self.currentEntity)
        self.sceneView.scene.addAnchor(anchor!)
       // self.currentEntity?.scale *= self.scale
        self.removeCloseButton()
        ProgressHUD.dismiss()
       // print("modelEntity for \(self.name) has been loaded.")
        self.modelPlacementUI()
    }
    
     func addAsapPoster() {
        toggleBtn.isHidden = true
        self.undoButton.isHidden = true
        self.sceneInfoButton.isHidden = true
        dismissKeyboard()
        ProgressHUD.show("Loading...")
  //      self.addCloseButton()
      //  view.endEditing(true)
        let mesh = MeshResource.generatePlane(width: 0.88, depth: 1.33)// .generatePlane(width: 1.5, height: 0.9)    // 16:9 video

        var material = SimpleMaterial()// VideoMaterial(avPlayer: avPlayer) //UIImageView(image: pickedImageView.image) //pickedImageView.image
        material.baseColor = try! .texture(.load(named: "asapasap"))

//        material.baseColor = try! .texture(.load(named: "chanceposter"))
        let planeModel = ModelEntity(mesh: mesh, materials: [material])
        
        self.currentEntity = planeModel
        self.currentEntity.name = "A$AP Dior Poster"
        print(self.currentEntity)
        self.currentEntity.generateCollisionShapes(recursive: true)
        let physics = PhysicsBodyComponent(massProperties: .default,
                                                    material: .default,
                                                        mode: .dynamic)
       // modelEntity.components.set(physics)
        self.sceneView.installGestures([.translation, .rotation, .scale], for: self.currentEntity)
        let anchor =  self.focusEntity?.anchor //AnchorEntity(plane: .any)// // AnchorEntity(world: [0,-0.2,0])
        print(anchor)
       // anchor?.scale = [1.2,1.0,1.0]
        anchor?.addChild(self.currentEntity)
        self.sceneView.scene.addAnchor(anchor!)
       // self.currentEntity?.scale *= self.scale
        self.removeCloseButton()
        ProgressHUD.dismiss()
       // print("modelEntity for \(self.name) has been loaded.")
        self.modelPlacementUI()
    }
    
    func addChancePoster() {
        toggleBtn.isHidden = true
        self.undoButton.isHidden = true
        self.sceneInfoButton.isHidden = true
        dismissKeyboard()
        ProgressHUD.show("Loading...")
  //      self.addCloseButton()
      //  view.endEditing(true)
        let mesh = MeshResource.generatePlane(width: 1.5, depth: 1)// .generatePlane(width: 1.5, height: 0.9)    // 16:9 video

        var material = SimpleMaterial()// VideoMaterial(avPlayer: avPlayer) //UIImageView(image: pickedImageView.image) //pickedImageView.image
        material.baseColor = try! .texture(.load(named: "chanceposter"))

//        material.baseColor = try! .texture(.load(named: "chanceposter"))
        let planeModel = ModelEntity(mesh: mesh, materials: [material])
        
        self.currentEntity = planeModel
        self.currentEntity.name = "Chance the Rapper Poster"
        print(self.currentEntity)
        self.currentEntity.generateCollisionShapes(recursive: true)
        let physics = PhysicsBodyComponent(massProperties: .default,
                                                    material: .default,
                                                        mode: .dynamic)
       // modelEntity.components.set(physics)
        self.sceneView.installGestures([.translation, .rotation, .scale], for: self.currentEntity)
        let anchor =  self.focusEntity?.anchor //AnchorEntity(plane: .any)// // AnchorEntity(world: [0,-0.2,0])
        print(anchor)
       // anchor?.scale = [1.2,1.0,1.0]
        anchor?.addChild(self.currentEntity)
        self.sceneView.scene.addAnchor(anchor!)
       // self.currentEntity?.scale *= self.scale
        self.removeCloseButton()
        ProgressHUD.dismiss()
       // print("modelEntity for \(self.name) has been loaded.")
        self.modelPlacementUI()
        
    }
    
    
    var modelName = ""
    var imageURL : URL?
    
    func downloadImageFromMarketplace(){
        toggleBtn.isHidden = true
        self.sceneInfoButton.isHidden = true
        self.undoButton.isHidden = true
    self.anchorSettingsImg.isHidden = true
    self.entityName.removeFromSuperview()
    self.entityProfileBtn.removeFromSuperview()
        dismissKeyboard()
        ProgressHUD.show("Loading...")
    //    self.addCloseButton()
    print("\(self.modelName) is modelName")
    FirestoreManager.getModel(self.modelUid) { model in
        let modelName = model?.modelName
        print("\(modelName ?? "") is model name")
        let mesh = MeshResource.generateBox(width: 1.35, height: 0.001, depth: 0.85)
       // let mesh = MeshResource.generateBox(width: 0.85, height: 0.04, depth: 0.85)// .generatePlane(width: 1.0, depth: 1.0)// .generatePlane(width: 1.5, height: 0.9)    // 16:9 video

        var material = SimpleMaterial()// VideoMaterial(avPlayer: avPlayer) //UIImageView(image: pickedImageView.image) //pickedImageView.image
        let thumbnailName = model?.thumbnail
        self.imageURL = URL(string: "gs://blueprint-8c1ca.appspot.com/thumbnails/\(thumbnailName ?? "")")
        
    //    material.baseColor = try! .texture(.load(contentsOf: self.imageURL!))
         //info[UIImagePickerController.InfoKey.imageURL] as? URL
        
//        StorageManager.getModelThumbnail(thumbnailName ?? "") { image in
//            material.baseColor = image
//        }
       
        material.baseColor = try! .texture(.load(named: "wildtextures_mossed-tree-bark-seamless-2k-texture"))
        let planeModel = ModelEntity(mesh: mesh, materials: [material])
        
        self.currentEntity = planeModel
        self.currentEntity.name = model?.name ?? ""
        print(self.currentEntity)
        self.currentEntity.generateCollisionShapes(recursive: true)
        let physics = PhysicsBodyComponent(massProperties: .default,
                                                    material: .default,
                                                        mode: .dynamic)
       // modelEntity.components.set(physics)
        self.sceneView.installGestures([.translation, .rotation, .scale], for: self.currentEntity)
        let anchor =  self.focusEntity?.anchor //AnchorEntity(plane: .any)// // AnchorEntity(world: [0,-0.2,0])
        print(anchor)
       // anchor?.scale = [1.2,1.0,1.0]
        anchor?.addChild(self.currentEntity)
        self.sceneView.scene.addAnchor(anchor!)
       // self.currentEntity?.scale *= self.scale
        self.removeCloseButton()
        ProgressHUD.dismiss()
       // print("modelEntity for \(self.name) has been loaded.")
        self.modelPlacementUI()
        }
    }
    
    var tvStand : ModelEntity?
    
    func downloadOption(){
        ProgressHUD.show("Loading...")
        view.isUserInteractionEnabled = false
        optionsScrollView.isUserInteractionEnabled = true
        optionsScrollView.isScrollEnabled = true
  //      self.addCloseButton()
    print("\(self.modelName) is modelName")
       
        let group = DispatchGroup()

        // Enter the dispatch group before starting the first async task
        group.enter()
        FirestoreManager.getModel(self.modelUid) { model in
            let modelName = model?.modelName
            print("\(modelName ?? "") is model name")
            // Enter the dispatch group before starting the second async task
            group.enter()
            FirebaseStorageHelper.asyncDownloadToFilesystem(relativePath: "models/\(modelName ?? "")")  { localUrl in
                self.cancellable = ModelEntity.loadModelAsync(contentsOf: localUrl).sink(receiveCompletion: { loadCompletion in
                    switch loadCompletion {
                    case.failure(let error): print("Unable to load modelEntity for Mayflower Ship Model. Error: \(error.localizedDescription)")
                        ProgressHUD.dismiss()
                    case.finished:
                        break
                    }
                    // Leave the dispatch group after finishing the second async task
                    group.leave()
                }, receiveValue: { modelEntity in
                    self.currentEntity = modelEntity
                    if self.modelUid == "kUCg8YOdf4buiXMwmxm7" {
                        self.tvStand = modelEntity
                    }
                        self.currentEntity.name = model?.name ?? ""
                     //   self.modelUid =
                        print(self.currentEntity)
                        self.currentEntity.generateCollisionShapes(recursive: true)
                        let physics = PhysicsBodyComponent(massProperties: .default,
                                                                    material: .default,
                                                                        mode: .dynamic)
                        // modelEntity.components.set(physics)
                    if self.modelUid == "MbfjeiKYGfOFTw74eb33" {
                        self.sceneView.installGestures([.rotation, .scale], for: self.currentEntity) //.translation
                        let anchor =  self.focusEntity?.anchor
                        print(anchor)
                        anchor?.addChild(self.currentEntity)
                        let scale = model?.scale
                        print("\(scale) is scale")
                        self.currentEntity.scale = [Float(scale ?? 0.01), Float(scale ?? 0.01), Float(scale ?? 0.01)]
                        //create variable specifically for tvStand
                        self.tvStand?.addChild(modelEntity) // .addAnchor(anchor!) //maybe currentEntity, not anchor
                        modelEntity.setPosition(SIMD3(0.0, 0.78, 0.0), relativeTo: self.tvStand)
                       // self.sceneView.scene.addAnchor(anchor!)
                        print("modelEntity for Samsung 65' QLED 4K Curved Smart TV has been loaded.")
                        ProgressHUD.dismiss()
                        self.removeCloseButton()
                       // print("modelEntity for \(self.name) has been loaded.")
                        self.view.isUserInteractionEnabled = true
                        self.sceneView.isUserInteractionEnabled = true
                    } else {
                        self.sceneView.installGestures([.translation, .rotation, .scale], for: self.currentEntity)
                        let anchor =  self.focusEntity?.anchor //AnchorEntity(plane: .any)// // AnchorEntity(world: [0,-0.2,0])
                        print(anchor)
                        // anchor?.scale = [1.2,1.0,1.0]
                        anchor?.addChild(self.currentEntity)
                        let scale = model?.scale
                        print("\(scale) is scale")
                        self.currentEntity.scale = [Float(scale ?? 0.01), Float(scale ?? 0.01), Float(scale ?? 0.01)]
                        self.sceneView.scene.addAnchor(anchor!)
                        // self.currentEntity?.scale *= self.scale
                        print("modelEntity for Mayflower Ship Model has been loaded.")
                        ProgressHUD.dismiss()
                        self.removeCloseButton()
                        // print("modelEntity for \(self.name) has been loaded.")
                        
                        self.modelPlacementUI()
                    }
                    // Leave the dispatch group after finishing the first async task
                    group.leave()
                })
            }
        }
        // Wait for all async tasks to finish and call the completion closure
        group.notify(queue: .main) {
            // Do something after all async tasks are finished
            self.view.isUserInteractionEnabled = true
        }
    }
    
    func downloadContentFromMarketplace(){
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "finishedDesignWalkthrough")
        defaults.set(false, forKey: "showDesignWalkthrough")

        self.userGuideBtn.isHidden = true
        self.closeUserGuideImgView.isHidden = true
        self.editInstructions.removeFromSuperview()
        self.circle.removeFromSuperview()
        self.circle2.removeFromSuperview()

        toggleBtn.isHidden = true
        self.sceneInfoButton.isHidden = true
        self.undoButton.isHidden = true
    self.anchorSettingsImg.isHidden = true
    self.entityName.removeFromSuperview()
    self.entityProfileBtn.removeFromSuperview()
        dismissKeyboard()
        ProgressHUD.show("Loading...")
        view.isUserInteractionEnabled = false
  //      self.addCloseButton()
    print("\(self.modelName) is modelName")
        
        let group = DispatchGroup()

        // Enter the dispatch group before starting the first async task
        group.enter()
        FirestoreManager.getModel(self.modelUid) { model in
            let modelName = model?.modelName
            print("\(modelName ?? "") is model name")
            // Enter the dispatch group before starting the second async task
            group.enter()
            FirebaseStorageHelper.asyncDownloadToFilesystem(relativePath: "models/\(modelName ?? "")")  { localUrl in
                self.cancellable = ModelEntity.loadModelAsync(contentsOf: localUrl).sink(receiveCompletion: { loadCompletion in
                    switch loadCompletion {
                    case.failure(let error): print("Unable to load modelEntity for Mayflower Ship Model. Error: \(error.localizedDescription)")
                        ProgressHUD.dismiss()
                    case.finished:
                        break
                    }
                    // Leave the dispatch group after finishing the second async task
                    group.leave()
                }, receiveValue: { modelEntity in
                    self.currentEntity = modelEntity
//                    if self.modelUid == "kUCg8YOdf4buiXMwmxm7" {
//                        self.tvStand = modelEntity
//                    }
                        self.currentEntity.name = model?.name ?? ""
                     //   self.modelUid =
                        print(self.currentEntity)
//                    if self.modelUid == "MbfjeiKYGfOFTw74eb33" {
//                        self.sceneView.installGestures([.rotation, .scale], for: self.currentEntity) //.translation
//                        let anchor =  self.focusEntity?.anchor
//                        print(anchor)
//                        anchor?.addChild(self.currentEntity)
//                        let scale = model?.scale
//                        print("\(scale) is scale")
//                        self.currentEntity.scale = [Float(scale ?? 0.01), Float(scale ?? 0.01), Float(scale ?? 0.01)]
//                        //create variable specifically for tvStand
//                        self.tvStand?.addChild(modelEntity) // .addAnchor(anchor!) //maybe currentEntity, not anchor
//                        modelEntity.setPosition(SIMD3(0.0, 0.78, 0.0), relativeTo: self.tvStand)
//                       // self.sceneView.scene.addAnchor(anchor!)
//                        print("modelEntity for Samsung 65' QLED 4K Curved Smart TV has been loaded.")
//                        ProgressHUD.dismiss()
//                        self.removeCloseButton()
//                       // print("modelEntity for \(self.name) has been loaded.")
//                        self.view.isUserInteractionEnabled = true
//                        self.sceneView.isUserInteractionEnabled = true
//                    } else {
                    self.currentEntity.generateCollisionShapes(recursive: true)

                        self.sceneView.installGestures([.translation, .rotation, .scale], for: self.currentEntity)
                        let anchor =  self.focusEntity?.anchor //AnchorEntity(plane: .any)// // AnchorEntity(world: [0,-0.2,0])
                        print(anchor)
                        // anchor?.scale = [1.2,1.0,1.0]
                        anchor?.addChild(self.currentEntity)
                        let scale = model?.scale
                        print("\(scale) is scale")
                        self.currentEntity.scale = [Float(scale ?? 0.01), Float(scale ?? 0.01), Float(scale ?? 0.01)]
                        self.sceneView.scene.addAnchor(anchor!)
                        // self.currentEntity?.scale *= self.scale
                        print("modelEntity for Mayflower Ship Model has been loaded.")
                        ProgressHUD.dismiss()
                        self.removeCloseButton()
                        // print("modelEntity for \(self.name) has been loaded.")
                        self.modelPlacementUI()
                 //   }
                    // Leave the dispatch group after finishing the first async task
                    group.leave()
                })
            }
        }
        // Wait for all async tasks to finish and call the completion closure
        group.notify(queue: .main) {
            // Do something after all async tasks are finished
            self.view.isUserInteractionEnabled = true
        }

                
    }
    
    
    var modelId1 = ""
    var modelId2 = ""
    
    
    private var cancellable: AnyCancellable?
    
    let nftView = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 375))
    let searchStackUnderView = UIView(frame: CGRect(x: 0, y: 43, width: UIScreen.main.bounds.width / 2, height: 2))
    
    
    var num = 0
    
    var nearbyBlueprintName = ""
    
    func networksNear(){
        print("\(self.currentLocation?.coordinate.latitude) is lat")
        print("\(self.currentLocation?.coordinate.longitude) is long")
        print("\(self.originalLocation.coordinate.latitude) is orig lat")
        print("\(self.originalLocation.coordinate.longitude) is orig long")
        FirestoreManager.getBlueprintsInRange(centerCoord: CLLocationCoordinate2D(latitude: (self.originalLocation.coordinate.latitude), longitude: (self.originalLocation.coordinate.longitude)), withRadius: 20) { (blueprints) in
            
            self.num = blueprints.count
           
            if self.num == 0 {
                self.networksNearImg.isHidden = true
            } else if self.num >= 1 {
                let blueprint = blueprints[0]
                self.networksNearImg.image = UIImage(systemName: "\(self.num).circle.fill")
                self.networksNearImg.isHidden = false
                 
//                self.editInstructions = UILabel(frame: CGRect(x: 15, y: 135, width: UIScreen.main.bounds.width - 30, height: 50))
//
//
//                self.editInstructions.textAlignment = .center
//                self.editInstructions.text = "There is a Blueprint near your location. Explore and connect with it!" // "There is a Blueprint near your location. Do you want to connect?"
//                self.editInstructions.backgroundColor = .white
//                self.editInstructions.textColor = .black
//                self.editInstructions.clipsToBounds = true
//                self.editInstructions.layer.cornerRadius = 12
//               // self.editInstructions.padding = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
//                self.editInstructions.numberOfLines = 2
//                self.editInstructions.font = UIFont.systemFont(ofSize: 16, weight: .medium)
                self.checkWalkthrough()
                let blueprintId = blueprint.id
                FirestoreManager.getBlueprint(blueprintId) { (foundBlueprint) in
                    if let blueprint = foundBlueprint {
                        self.nearbyBlueprintName = blueprint.name
                        if self.userGuideBtn.isHidden == true {
            //                self.showNearbyBlueprintAlert()
                        }}
                }
              //  self.showNearbyBlueprintAlert()
            }
//            else {
//                self.networksNearImg.image = UIImage(systemName: "\(self.num).circle.fill")
//                self.networksNearImg.isHidden = false
//
//                self.editInstructions = UILabel(frame: CGRect(x: 15, y: 135, width: UIScreen.main.bounds.width - 30, height: 50))
//                self.editInstructions.textAlignment = .center
//                self.editInstructions.text = "Exciting news! There are Blueprints waiting for you just around the corner."
//                self.editInstructions.backgroundColor = .white
//                self.editInstructions.textColor = .black
//                self.editInstructions.clipsToBounds = true
//                self.editInstructions.layer.cornerRadius = 12
//               // self.editInstructions.padding = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
//                self.editInstructions.numberOfLines = 2
//                self.editInstructions.font = UIFont.systemFont(ofSize: 16, weight: .medium)
//                self.view.addSubview(self.editInstructions)
//            }
        }}
    
    var isPlacingModel = false
    
     func modelPlacementUI(){
        self.sceneView.removeGestureRecognizer(holdGesture)
        self.isPlacingModel = true
        self.networksNearImg.isHidden = true
        self.placementStackView.isHidden = false
        //searchStackUnderView.isHidden = true
        self.networkBtn.isHidden = true
         self.alertView.isHidden = true
         self.xImageView.isHidden = true
        self.networksNearImg.isHidden = true
        self.wordsBtn.isHidden = true
         self.libraryImageView.isHidden = true
        self.videoBtn.isHidden = true
         self.copilotBtn.isHidden = true
         self.scanImgView.isHidden = true
        self.buttonStackView.isHidden = true
//        searchBtn.isHidden = true
        addButton.isHidden = true
        self.progressView?.isHidden = true
        toggleBtn.isHidden = true
        self.sceneView.removeGestureRecognizer(doubleTap)
        if currentEntity.name == "Blank Canvas"{
            duplicateBtn.isHidden = false
        } else {
            duplicateBtn.isHidden = true

        }
        saveButton.isHidden = true
        undoButton.isHidden = true
        numberOfEditsImg.isHidden = true
     //   entityName = UILabel(frame: CGRect(x: 20, y: 140, width: 300, height: 30))
        entityName = UILabel(frame: CGRect(x: 20, y: 80, width: UIScreen.main.bounds.width - 85, height: 30))// UILabel(frame: CGRect(x: 35, y: 87, width: 340, height: 30))
//        entityName.trailingAnchor.constraint(equalTo: sceneView.trailingAnchor, constant: 45).isActive = true
        entityName.text = currentEntity.name
        entityName.textColor = .white
        entityName.font = UIFont(name: "Noto Sans Kannada Bold", size: 22) //UIFont.systemFont(ofSize: 22, weight: .bold)
//        entityProfileBtn = UIButton(frame: CGRect(x: 12, y: 173, width: 100, height: 20))
   //     entityName.textAlignment = .right
        entityProfileBtn = UIButton(frame: CGRect(x: 12, y: 113, width: 100, height: 20))// UIButton(frame: CGRect(x: 285, y: 120, width: 100, height: 20))
        
        
        entityProfileBtn.titleLabel?.font = UIFont(name: "Noto Sans Kannada", size: 15) //.systemFont(ofSize: 15)
        entityProfileBtn.setTitle("View Profile", for: .normal)
      //  entityProfileBtn.color = .red
        entityProfileBtn.setTitleColor(.systemYellow, for: .normal)// = .blue
        entityProfileBtn.isUserInteractionEnabled = true
      //  entityProfileBtn.addGestureRecognizer(profileRecognizer)
         promptLabel.isHidden = true
         cancelImg.isHidden = true
        entityName.isHidden = false
        entityProfileBtn.isHidden = false
        
        sceneView.addSubview(entityName)
        if entityName.text == "" || entityName.text == .none || ((entityName.text?.contains("Photo by")) == true){
            //self.selectedAnchorID = String(currentAnchor.id)
        } else {
            sceneView.addSubview(entityProfileBtn)
        }
        
        networksNearImg.isHidden = true
     //     networkBtn.setImage(UIImage(systemName: "icloud.and.arrow.up.fill"), for: .normal)
        
        self.view.isUserInteractionEnabled = true
        self.sceneView.isUserInteractionEnabled = true
         
         if defaults.bool(forKey: "hasDownloadedContent") != true {
             circle.frame = CGRect(x: (UIScreen.main.bounds.width / 2) - 35, y: scanImgView.frame.minY + 5.5, width: 70, height: 70)
             circle.backgroundColor = .clear
             circle.layer.cornerRadius = 35
             circle.clipsToBounds = true
             circle.layer.borderColor = UIColor.systemBlue.cgColor
             circle.layer.borderWidth = 4
             circle.isUserInteractionEnabled = false
             circle.alpha = 1.0
             sceneView.addSubview(circle)
             
             self.editInstructions = UILabel(frame: CGRect(x: 15, y: scanImgView.frame.minY - 110, width: UIScreen.main.bounds.width - 40, height: 92))
             self.editInstructions.textAlignment = .center
             self.editInstructions.text = "Move the content to your desired location, and click here to confirm the object's placement. You can modify the object's scale, orientation, and location by interacting with it." // "There is a Blueprint near your location. Do you want to connect?"
             self.editInstructions.backgroundColor = .white
             self.editInstructions.textColor = .black
             self.editInstructions.clipsToBounds = true
             self.editInstructions.layer.cornerRadius = 12
             // self.editInstructions.padding = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
             self.editInstructions.numberOfLines = 4
             self.editInstructions.font = UIFont.systemFont(ofSize: 16, weight: .medium)
             self.view.addSubview(self.editInstructions)
             defaults.set(true, forKey: "hasDownloadedContent")
             UIView.animate(withDuration: 0.85, delay: 0, options: [.curveEaseInOut, .repeat, .autoreverse], animations: {
                 self.circle.alpha = 0.1
             })
         }
    }
    
    var likeTouches = 0
    
            
    @objc func like(){
        if Auth.auth().currentUser != nil {
            
            likeTouches += 1
            var likeID = ""
            if currentEntity.name == "" || currentEntity.name == .none {
                likeID = String(self.currentAnchor.id)
                //            FirestoreManager.getUser(Auth.auth().currentUser?.uid ?? "") { user in
                //                if ((user?.likedAnchorIDs.contains(likeID)) == true) {
                //                    self.likeTouches += 1
                //                }
                //            }
            } else {
                likeID = String(self.currentEntity.id)
                //            FirestoreManager.getUser(Auth.auth().currentUser?.uid ?? "") { user in
                //                if ((user?.likedAnchorIDs.contains(likeID)) == true) {
                //                    self.likeTouches += 1
                //                }
                //            }
            }
            
            if likeTouches % 2 == 0 {
                heartImg.tintColor = .white
                heartImg.alpha = 0.70
                
                FirestoreManager.getSessionAnchor(likeID) { anchor in
                    //   let ID = self.selectedNodeAnchorID
                    
                    let docRef = self.db.collection("sessionAnchors").document(anchor?.id ?? "")
                    docRef.updateData([
                        "likes": FieldValue.increment(Int64(-1))
                    ])
                    
                    let docRef2 = self.db.collection("users").document(Auth.auth().currentUser?.uid ?? "")
                    docRef2.updateData([
                        "likedAnchorIDs": FieldValue.arrayRemove(["\(likeID)"])
                    ])
                    
                    self.anchorLikesLabel.text = "\(self.originalAnchorLikes)"
                    
                    let host = anchor?.host
                    FirestoreManager.getUser(host!) { user in
                        let hostPointsRef = self.db.collection("users").document(host!)
                        hostPointsRef.updateData([
                            "points": FieldValue.increment(Int64(-3))
                        ])
                    }
                }} else {
                    heartImg.tintColor = .systemRed
                    heartImg.alpha = 0.95
                    FirestoreManager.getSessionAnchor(likeID) { anchor in
                        //  let ID = self.selectedNodeAnchorID
                        
                        let docRef = self.db.collection("sessionAnchors").document(anchor?.id ?? "")
                        docRef.updateData([
                            "likes": FieldValue.increment(Int64(1))
                        ])
                        
                        let docRef2 = self.db.collection("users").document(Auth.auth().currentUser?.uid ?? "")
                        docRef2.updateData([
                            "likedAnchorIDs": FieldValue.arrayUnion(["\(likeID)"])
                        ])
                        
                        self.anchorLikesLabel.text = "\(self.originalAnchorLikes + 1)"
                        let host = anchor?.host
                        FirestoreManager.getUser(host!) { user in
                            let hostPointsRef = self.db.collection("users").document(host!)
                            hostPointsRef.updateData([
                                "points": FieldValue.increment(Int64(3))
                            ])
                        }
                    }
                }
        } else {
            let alert = UIAlertController(title: "Create Account", message: "When you create an account on Blueprint, you can interact with content.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Sign Up", style: .default) { action in
                
                self.goToSignUp()
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { action in
                //completionHandler(false)
                return
            })
            present(alert, animated: true)
        }
    }
    
     func goToSignUp(){
        let storyboard = UIStoryboard(name: "SignUp", bundle: nil)
        var next = storyboard.instantiateViewController(withIdentifier: "SignUpVC") as! SignUpViewController
         next.modalPresentationStyle = .fullScreen
        self.present(next, animated: true, completion: nil)
    }
    
    func updateUserLocation() {
        if self.currentLocation?.distance(from: self.originalLocation) ?? 0 >= 7 && self.currentLocation?.distance(from: self.originalLocation) ?? 0 < 200 {
          //  self.lookForAnchorsNearDevice()
         //   self.anchorsNear()
            print("updated anchor near")
            self.originalLocation = CLLocation(latitude: currentLocation?.coordinate.latitude ?? 42.3421531456477, longitude: currentLocation?.coordinate.longitude ?? -71.08596376738004)
            print("\(originalLocation) is og location")
        }
    }
    
    var closeButton = UIButton()
    
    
    func removeCloseButton(){
        closeButton.removeFromSuperview()
    }
    
     func exit(){
        ProgressHUD.dismiss()
    //    self.updatePersistanceAvailability(for: sceneView)
        entityName.isHidden = true
        entityProfileBtn.isHidden = true
        placementStackBottomConstraint.constant = 15
            networkBtn.isHidden = false
        wordsBtn.isHidden = false
        videoBtn.isHidden = false
         self.libraryImageView.isHidden = false
            networksNearImg.isHidden = false
       //
        placementStackView.isHidden = true
        duplicateBtn.isHidden = true
        return
    }
    var currentPlaneAnchor: ARPlaneAnchor?
    private var planeAnchors: [ARPlaneAnchor] = []
    // MARK: - ARSessionDelegate
    
//    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
//        for anchor in anchors {
//            if let planeAnchor = anchor as? ARPlaneAnchor {
//                // Store the most recently detected plane anchor
//                currentPlaneAnchor = planeAnchor
//            }
//        }
//    }
//
//    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
//        for anchor in anchors {
//            if let planeAnchor = anchor as? ARPlaneAnchor, planeAnchor == currentPlaneAnchor {
//                // Update the current plane anchor if it has been updated
//                currentPlaneAnchor = planeAnchor
//            }
//        }
//    }

//    func session(_ session: ARSession, didUpdate frame: ARFrame) {
//        if let planeAnchor = currentPlaneAnchor {
//            // Create a mesh resource for the plane anchor
//            let mesh = MeshResource.generatePlane(width: (planeAnchor.planeExtent.width),
//                                                  height: (planeAnchor.planeExtent.height))
//            // Create a material for the plane mesh
//            let material = SimpleMaterial(color: UIColor.red, isMetallic: true)
//            // Create a model entity for the plane mesh with the material
//            let modelEntity = ModelEntity(mesh: mesh, materials: [material])
//            // Set the model entity's position and orientation to match the plane anchor
//            modelEntity.transform = Transform(pitch: 0, yaw: planeAnchor.planeExtent.rotationOnYAxis, roll: 0)
//            modelEntity.transform.translation = planeAnchor.center
//            // Wrap the model entity in an AnchorEntity and add it to the scene
//            let anchorEntity = AnchorEntity(anchor: planeAnchor)
//            anchorEntity.addChild(modelEntity)
//            sceneView.scene.addAnchor(anchorEntity)
//        }
//    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        switch frame.worldMappingStatus {
        case .notAvailable, .limited:
            saveButton.isUserInteractionEnabled = false
        case .extending:
            saveButton.isUserInteractionEnabled = false// = !multipeerSession.connectedPeers.isEmpty
        case .mapped:
            saveButton.isUserInteractionEnabled = false// = !multipeerSession.connectedPeers.isEmpty
        @unknown default:
            saveButton.isUserInteractionEnabled = false
        }
            self.updateUserLocation()
    }
   
    var anchorHostID = ""
    var entityName = UILabel()
    var entityDetailsView = UIView()
    var entityProfileBtn = UIButton()
    var image: UIImage? = nil
    var detailAnchor = AnchorEntity()
    
    func goToNetworkSettings(_ sender: UITapGestureRecognizer){
        let storyboard = UIStoryboard(name: "Networks", bundle: nil)
        var next = storyboard.instantiateViewController(withIdentifier: "NetworkSettingsVC") as! NetworkSettingsTableViewController
        //next.modalPresentationStyle = .fullScreen
        self.present(next, animated: true, completion: nil)
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
                        //self.topView.isUserInteractionEnabled = false
                        self.addButton.isUserInteractionEnabled = false
                        self.videoBtn.isUserInteractionEnabled = false
                        self.wordsBtn.isUserInteractionEnabled = false
                        self.walkthroughView.isUserInteractionEnabled = false
                        self.sceneView.isUserInteractionEnabled = false
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
                    //self.topView.isUserInteractionEnabled = false
                    self.addButton.isUserInteractionEnabled = false
                    self.videoBtn.isUserInteractionEnabled = false
                    self.wordsBtn.isUserInteractionEnabled = false
                    self.walkthroughView.isUserInteractionEnabled = false
                    self.sceneView.isUserInteractionEnabled = false
                    self.buttonStackView.isUserInteractionEnabled = false
                    self.networkBtn.isUserInteractionEnabled = false
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
        if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
            if #available(iOS 14.0, *) {
                if locationManager?.accuracyAuthorization != .fullAccuracy {
                  //  self.statusLabel?.text = "Location permission not granted with full accuracy."
                   // self.addAnchorButton?.isHidden = true
                   // self.networkView.isHidden = true
                   // self.deleteAnchorButton?.isHidden = true
                    return
                }
            }
        } else if authorizationStatus == .notDetermined {
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
            //topview.isUserInteractionEnabled = false
            addButton.isUserInteractionEnabled = false
            videoBtn.isUserInteractionEnabled = false
            wordsBtn.isUserInteractionEnabled = false
            walkthroughView.isUserInteractionEnabled = false
            sceneView.isUserInteractionEnabled = false
            buttonStackView.isUserInteractionEnabled = false
            networkBtn.isUserInteractionEnabled = false
            scanImgView.isUserInteractionEnabled = false
           // self.statusLabel?.text = "Location permission denied or restricted."
           // self.addAnchorButton?.isHidden = true
            //self.networkView.isHidden = true
           // self.deleteAnchorButton?.isHidden = true
        }}
    
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

  //  var webScreenshot = UIImage?
    var videoTaps = 0
    var anchorSettingsImg = UIImageView()
    var selectedAnchorID = ""
    
    
    @objc func didLongPress(_ gesture: UILongPressGestureRecognizer) { //UILongPress
        if gesture.state == UIGestureRecognizer.State.began {
            //virtualTaps = 0
            let touchLocation = gesture.location(in: sceneView)
            let hits = self.sceneView.hitTest(touchLocation)
            if let tappedEntity = hits.first?.entity  {
                print("\(tappedEntity.name) is the name of the tapped enitity")
                print("\(tappedEntity.position(relativeTo: currentEntity)) is the position relative to the current entity")
                print("\(tappedEntity.position.y)) is the top y point of the tapped entity")
                print("\(tappedEntity.anchor?.position.y ?? 0)) is the top y point of the tapped entity's anchor")
          //      print("\(tappedEntity.size ?? 0)) is the tapped entity's size")
                print("\(tappedEntity.scale) is the tapped entity's scale")
                for i in 0..<optionsIDArray.count {
                    self.updateOptions(index: i)
                }
                let tappedName = tappedEntity.name
                
                if tappedName.contains("Mesh Entity") {
                    return
                } else if tappedName == self.entityName.text && self.entityName.isHidden == false{
                    return
                } else {
                    self.entityName.removeFromSuperview()
                    self.entityProfileBtn.removeFromSuperview()
                    self.anchorSettingsImg.removeFromSuperview()
                }
                
                selectedEntity = tappedEntity as? ModelEntity
                selectedAnchor = selectedEntity?.anchor as? AnchorEntity
//                    if selectedEntity?.name == "" || selectedEntity?.name == .none {
//                        return
//                    }
                let component = ModelDebugOptionsComponent(visualizationMode: .baseColor)
               // selectedEntity?.modelDebugOptions = component
                
                let physics = PhysicsBodyComponent(massProperties: .init(mass: 10),
                                                                material: .default,
                                                                    mode: .kinematic)
                if selectedEntity?.name == "" || selectedEntity?.name == .none {
                    self.selectedAnchorID = String(currentAnchor.id)
                } else {
                    self.selectedAnchorID = String(tappedEntity.id)
                }
                    
                print("\(tappedEntity.id) is tapped entity id")
                print("\(currentAnchor.id) is current anchor id")
                    let defaults = UserDefaults.standard
                    defaults.set(self.selectedAnchorID, forKey: "selectedAnchorID")
               // selectedEntity?.physicsBody = physics
                //topview.isHidden = true
                    addButton.isHidden = true
                    self.progressView?.isHidden = true
                    sceneInfoButton.isHidden = true
                    self.buttonStackView.isHidden = true
                saveButton.isHidden = true
                    undoButton.isHidden = true
                    print("\(currentEntity.physicsBody?.massProperties.mass)")
                numberOfEditsImg.isHidden = true
                networkBtn.isHidden = true
                    wordsBtn.isHidden = true
                    videoBtn.isHidden = true
                copilotBtn.isHidden = true
                self.optionsScrollView.isHidden = false
                self.libraryImageView.isHidden = true
                print(tappedEntity.name)
                print("is tapped entity name")
                placementStackView.isHidden = false
                    addButton.isHidden = true
                    self.progressView?.isHidden = true
                toggleBtn.isHidden = true
                    networksNearImg.isHidden = true
                    self.buttonStackView.isHidden = true
                entityDetailsView = UIView(frame: CGRect(x: 0, y: 675, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - 675))
                    entityDetailsView.backgroundColor = .black
                    entityDetailsView.alpha = 0.75
                    
                let entityPrice = UILabel(frame: CGRect(x: 20, y: 25, width: 150, height: 40))
                    entityPrice.font = UIFont.systemFont(ofSize: 30, weight: .semibold)
                    entityPrice.text = "$299.49"
                    entityPrice.textColor = .white
                    
                    anchorSettingsImg = UIImageView(frame: CGRect(x: UIScreen.main.bounds.width - 61, y: 81, width: 30, height: 30))
                    anchorSettingsImg.image = UIImage(systemName: "gearshape.fill")
                    anchorSettingsImg.tintColor = .white
                    anchorSettingsImg.contentMode = .scaleAspectFill
                    anchorSettingsImg.isUserInteractionEnabled = true
                    let tap = UITapGestureRecognizer(target: self, action: #selector(goToAnchorSettings))
                    anchorSettingsImg.addGestureRecognizer(tap)
                    view.addSubview(anchorSettingsImg)
                    
                entityName = UILabel(frame: CGRect(x: 20, y: 80, width: UIScreen.main.bounds.width - 85, height: 30))
//                entityName.text = selectedEntity?.name
                entityName.textColor = .white
                entityName.font = UIFont(name: "Noto Sans Kannada Bold", size: 22) //UIFont.systemFont(ofSize: 22, weight: .bold)
              //  entityName.adjustsFontSizeToFitWidth = true
                entityProfileBtn = UIButton(frame: CGRect(x: 12, y: 113, width: 100, height: 20))
                entityProfileBtn.titleLabel?.font = UIFont(name: "Noto Sans Kannada", size: 15) //.systemFont(ofSize: 15)
                entityProfileBtn.setTitle("View Profile", for: .normal)
              //  entityProfileBtn.color = .red
                entityProfileBtn.setTitleColor(.systemYellow, for: .normal)// = .blue
                entityProfileBtn.isUserInteractionEnabled = true
               
                entityProfileBtn.addGestureRecognizer(profileRecognizer)
//                if tappedName.contains("Photo by") {
//                    self.entityProfileBtn.removeFromSuperview()
//                }
                likeTouches = 0
                heartImg.tintColor = .white
                heartImg.alpha = 0.70
                
                    var anchorUserHostID = ""
                    
                    FirestoreManager.getSessionAnchor(self.selectedAnchorID) { anchor in
                        self.entityName.text = anchor?.name
                        if self.entityName.text == "Chance the Rapper Poster" || self.entityName.text == "A$AP Dior Poster" || self.entityName.text == "Flower Boy Poster" {
                            self.entityProfileBtn.removeFromSuperview()// nremoveFromSuperview()
                        }
                        let likes = anchor?.likes
                        self.modelUid = anchor?.modelId ?? ""
                        print("\(self.modelUid)is model ID")
                        self.originalAnchorLikes = likes ?? 123456
                        let comments = anchor?.comments
                        self.anchorLikesLabel.text = "\(likes ?? 123456)"
                        self.anchorCommentsLabel.text = "\(comments ?? 123456)"
                      //  self.anchorDescription = anchor?.description ?? ""
                        anchorUserHostID = anchor?.host as? String ?? "eUWpeKULDhN1gZEyaeKvzPNkMEk1"
                      //  anchorHostID = uid
                        print("\(anchorUserHostID) is host")
                        self.anchorSettingsImg.isHidden = false
                        self.anchorSettingsImg.isHidden = false
                  //      self.anchorInfoStackView.isHidden = false
                      //  anchorUserImg.isHidden = true
                       // FirestoreManager.getUser(anchorUserHostID) { user in
                           // let randUsername = self.randomString(length: 12)
                            let uid = anchorUserHostID
                        self.anchorHostID = uid
                        self.creatorUid = uid
//                            StorageManager.getProPic(uid) { image in
//                                self.anchorUserImg.isHidden = false
//                                self.anchorUserImg.image = image
//                                self.anchorUserImg.isUserInteractionEnabled = true
//                                let tap = UITapGestureRecognizer(target: self, action: #selector(self.anchorUserProfile))
//                                self.anchorUserImg.addGestureRecognizer(tap)
//                                if self.anchorUserImg.image == UIImage(named: "nouser") {
//                                    self.anchorUserImg.isUserInteractionEnabled = false
//                                }
//                            }
                        
                        
                    }
                    
//                    if selectedEntity?.name == "Wilson Basketball" {
//                        return
//                    } else {
                
                sceneView.addSubview(entityName)
                    print("added object here")
                    
                
                    entityDetailsView.addSubview(entityPrice)
               // sceneView.addSubview(entityDetailsView)
                if selectedEntity?.name == "" || selectedEntity?.name == .none || tappedName.contains("Photo by"){
                    //self.selectedAnchorID = String(currentAnchor.id)
                } else {
                    sceneView.addSubview(entityProfileBtn)
                }
                

               
            }
                }//}
       
       }
    
    func locationManager(_ locationManager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        checkLocationPermission()
    }

    /// Authorization callback for iOS 14.
    @available(iOS 14.0, *)
    func locationManagerDidChangeAuthorization(_ locationManager: CLLocationManager) {
        checkLocationPermission()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Error getting location: \(error.localizedDescription)")
        // You can also display an alert to the user or show a message on the screen to inform them that there was an error getting their location.
    }
    
    private let locationUpdateThreshold: CLLocationDistance = 50
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if self.currentLocation == nil {
            if let location = locations.first {
                //MAYBE LOCATIONMANAGER.COORDINATE.LAT
                let latitude = location.coordinate.latitude
                let longitude = location.coordinate.longitude
                self.originalLocation = CLLocation(latitude: latitude, longitude: longitude)
                self.networksNear()
               // self.lookForAnchorsNearDevice()
        //        self.checkWalkthrough()

                if Auth.auth().currentUser != nil {
                    let docRef = self.db.collection("users").document(Auth.auth().currentUser?.uid ?? "")
                    docRef.updateData([
                        "latitude": latitude,
                        "longitude": longitude,
                        "numSessions" : FieldValue.increment(Int64(1))
                    ]) { (error) in
                        if let error = error {
                            print("Error updating location: \(error.localizedDescription)")
                        } else {
                            print("Location updated successfully!")
                        }
                    }
                }
            }
        }
        if let location = locations.last {
            //MAYBE LOCATIONMANAGER.COORDINATE.LAT
            let latitude = location.coordinate.latitude
            let longitude = location.coordinate.longitude
            // Handle location update
            self.currentLocation = CLLocation(latitude: latitude, longitude: longitude)
            print("\(currentLocation?.verticalAccuracy ?? 0) is vert accuracy")
            if (currentLocation?.horizontalAccuracy ?? 0 < 0){
               // No Signal
                print("NO SIGNAL")
                //INSIDE --> SHOW GRAPHIC
           }
            else if (currentLocation?.horizontalAccuracy ?? 0 > 163){
               // Poor Signal
               print("POOR SIGNAL")
               //INSIDE --> SHOW GRAPHIC
           }
            else if (currentLocation?.horizontalAccuracy ?? 0 > 48){
               // Average Signal
               print("AVERAGE SIGNAL")
                
               //UNSURE --> SHOW UNSURE GRAPHIC
           }
           else{
               // Full Signal
               print("FULL SIGNAL")
               //OUTSIDE
           }
          //  let currentDistance = self.currentLocation?.distance(from: self.originalLocation)
            print("\(String(describing: currentLocation)) is current location updated")
//            self.networksNear()
            if defaults.bool(forKey: "connectToNetwork") == false {

            } else {
                FirestoreManager.getUser(Auth.auth().currentUser?.uid ?? "") { user in
                    self.currentConnectedNetwork = user?.currentConnectedNetworkID ?? ""
             //       self.connectToNetwork(with: self.currentConnectedNetwork)
                    let defaults = UserDefaults.standard
                    defaults.set(false, forKey: "connectToNetwork")

                }}
          //  print("\(originalLocation) is current original location")
           
        }
        
        
    }
    
    private func updateUserLocationInDatabase(_ location: CLLocation) {
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude
        let docRef = db.collection("users").document(Auth.auth().currentUser?.uid ?? "")
        docRef.updateData([
            "latitude": latitude,
            "longitude": longitude
        ]) { (error) in
            if let error = error {
                print("Error updating location: \(error.localizedDescription)")
            } else {
                print("Location updated successfully!")
            }
        }
    }


}

extension BlueprintViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
            imageAnchorChanged = true
           // profileImageView.image = image
            photoAnchorImageView.image = image //do same for video
            //call function that displays image in front of user
            
            
            imageAnchorURL = info[UIImagePickerController.InfoKey.imageURL] as? URL
            imagePicker.dismiss(animated: true, completion: nil)
            self.networkBtn.isHidden = true
            
            self.wordsBtn.isHidden = true
            self.videoBtn.isHidden = true
            self.libraryImageView.isHidden = true
            self.buttonStackView.isHidden = true
            photoAnchorImageChosen()
            }
        
//        guard let movieUrl = info[.mediaURL] as? URL else { return }
        
        if let video = info[UIImagePickerController.InfoKey.mediaURL] as? URL {
            videoAnchorChanged = true
           // profileImageView.image = image
            videoAnchorURL = video //do same for video
            //call function that displays image in front of user
            imagePicker.dismiss(animated: true, completion: nil)
            videoAnchorURLChosen()

        }
        imagePicker.dismiss(animated: true, completion: nil)
    }
    
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
}

class SceneManager: ObservableObject {
        @Published var isPersistenceAvailable: Bool = false
        @Published var anchorEntities: [AnchorEntity] = []

        var shouldSaveSceneToSystem: Bool = false
        var shouldLoadSceneToSystem: Bool = false

        lazy var persistenceURL: URL = {
            do {
                return try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("blueprint.persistence")
            } catch {
                fatalError("Unable to get persistence url: \(error.localizedDescription)")
            }
        }()

        var scenePersistenceData: Data? {
            return try? Data(contentsOf: persistenceURL)
        }
    }

extension BlueprintViewController {
    class Coordinator: NSObject, ARSessionDelegate {
        var parent : BlueprintViewController
        
        init(_ parent: BlueprintViewController) {
            self.parent = parent
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
}

extension UIButton {
    
    func centerVertically(padding: CGFloat = 6.0) {
        guard
            let imageViewSize = self.imageView?.frame.size,
            let titleLabelSize = self.titleLabel?.frame.size else {
            return
        }
        
        let totalHeight = imageViewSize.height + titleLabelSize.height + padding
        
        self.imageEdgeInsets = UIEdgeInsets(
            top: -(totalHeight - imageViewSize.height),
            left: 0.0,
            bottom: 0.0,
            right: -titleLabelSize.width
        )
        
        self.titleEdgeInsets = UIEdgeInsets(
            top: 0.0,
            left: -imageViewSize.width,
            bottom: -(totalHeight - titleLabelSize.height),
            right: 0.0
        )
        
        self.contentEdgeInsets = UIEdgeInsets(
            top: 0.0,
            left: 0.0,
            bottom: titleLabelSize.height,
            right: 0.0
        )
    }
    
}

extension UITextField {
  func setLeftView1(image: UIImage) {
      let iconView = UIImageView(frame: CGRect(x: 15, y: 6, width: 20, height: 20)) // set your Own size
    iconView.image = image
      iconView.contentMode = .scaleAspectFill
      
    let iconContainerView: UIView = UIView(frame: CGRect(x: 0, y: 0, width: 35, height: 35))
    iconContainerView.addSubview(iconView)
    leftView = iconContainerView
    leftViewMode = .always
    self.tintColor = .lightGray
  }
}

extension UIView {
    func snapshot() -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(self.bounds.size, true, UIScreen.main.scale)
        self.layer.render(in: UIGraphicsGetCurrentContext()!)
        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return img
    }
    
    func animateHide(){
        UIView.animate(withDuration: 0.7, delay: 0, options: [.curveLinear],
                       animations: {
                        self.center.y += self.bounds.height
                        self.layoutIfNeeded()

        },  completion: {(_ completed: Bool) -> Void in
        self.isHidden = true
            })
    }
}

extension BlueprintViewController: SFSpeechRecognizerDelegate {

    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
        //    self.btnStart.isEnabled = true
        } else {
         //   self.btnStart.isEnabled = false
        }
    }
}

//#Preview{
//    var controller = BlueprintViewController()
//    //can access variables here and set images
//    return controller
//}
