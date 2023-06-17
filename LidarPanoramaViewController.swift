//
//  LidarPanoramaViewController.swift
//  Indoor Blueprint
//
//  Created by Nijel Hunt on 4/25/23.
//

import UIKit
import RealityKit
import ARKit

class LidarPanoramaViewController: UIViewController, ARSessionDelegate {
    
    private var arView: ARView!
    var depthDataFrames: [ARFrame] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        arView = ARView(frame: view.bounds)
        arView.session.delegate = self
        view.addSubview(arView)
        
        arView.session.delegate = self
        arView.automaticallyConfigureSession = false
        let configuration = ARWorldTrackingConfiguration()
        configuration.frameSemantics = .sceneDepth
        arView.session.run(configuration)
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Add each frame to the list of depth data frames
        depthDataFrames.append(frame)
    }

//    func capturePanorama() -> UIImage? {
//        // Create an array to hold the captured images
//        var images: [UIImage] = []
//        
//        // Iterate through each depth frame and create an image from it
//        for frame in depthDataFrames {
//            guard let image = frame.sceneDepth?.depthMap.normalizedImage else { continue }
//            images.append(image)
//        }
//
//        // Combine the captured images into a single panorama
//        guard let panorama = images.stitchedImage() else { return nil }
//
//        return panorama
//    }
}

extension ARFrame {
//    var sceneDepth: ARDepthData? {
//        return capturedDepthData?.depthData
//    }
//
//    var capturedDepthData: (depthData: ARDepthData, timestamp: TimeInterval)? {
//        guard let depthData = capturedDepth?.depthData else { return nil }
//        return (depthData, timestamp)
//    }
}

extension CVPixelBuffer {
    var normalizedImage: UIImage? {
        let ciImage = CIImage(cvPixelBuffer: self)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

extension Array where Element: UIImage {
//    func stitchedImage() -> UIImage? {
//        let stitcher = OpenCVWrapper()
//        return stitcher?.stitchImages(self)
//    }
}
