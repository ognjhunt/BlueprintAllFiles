//
//  ScanViewController.swift
//  Indoor Blueprint
//
//  Created by Nijel Hunt on 4/30/23.
//

import UIKit
import RealityKit
import ARKit

class ScanViewController: UIViewController, ARSessionDelegate {
    
        private var arView: CustomCaptureView!
        var currentPlaneAnchor: ARPlaneAnchor?
        
        override func viewDidLoad() {
            super.viewDidLoad()
            arView = CustomCaptureView(frame: view.bounds)
            
            view.addSubview(arView)
            
            arView.session.delegate = self
//            arView.automaticallyConfigureSession = false
//
//            // Enable automatic environment texturing
//            arView.environment.sceneUnderstanding.options.insert(.receivesLighting)
//            arView.environment.sceneUnderstanding.options.insert(.occlusion)
        }
        
//        // MARK: - ARSessionDelegate
//
//        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
//            for anchor in anchors {
//                if let planeAnchor = anchor as? ARPlaneAnchor {
//                    // Store the most recently detected plane anchor
//                    currentPlaneAnchor = planeAnchor
//                }
//            }
//        }
//
//        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
//            for anchor in anchors {
//                if let planeAnchor = anchor as? ARPlaneAnchor, planeAnchor == currentPlaneAnchor {
//                    // Update the current plane anchor if it has been updated
//                    currentPlaneAnchor = planeAnchor
//                }
//            }
//        }
//
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
//            arView.scene.addAnchor(anchorEntity)
//        }
//    }

    


}
