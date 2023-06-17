//
//  DepthMapViewController.swift
//  Indoor Blueprint
//
//  Created by Nijel Hunt on 4/25/23.
//

import UIKit
import ARKit
import RealityKit

class DepthMapViewController: UIViewController, ARSessionDelegate {
    
    // MARK: - Properties
    
    private var arView: ARView!
    private var depthMaps: [ARDepthData] = []
    private let captureQueue = DispatchQueue(label: "depthMapCaptureQueue")
    
    // MARK: - Lifecycle Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        arView = ARView(frame: view.bounds)
        arView.session.delegate = self
        view.addSubview(arView)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let configuration = ARWorldTrackingConfiguration()
        configuration.sceneReconstruction = .meshWithClassification
        arView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        arView.session.pause()
    }
    
    // MARK: - ARSessionDelegate Methods
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard let depthData = frame.sceneDepth else { return }
        captureQueue.async {
            self.depthMaps.append(depthData)
        }
    }
    
    // MARK: - Helper Methods
    
    private func generateCombinedDepthMap() -> CVPixelBuffer? {
        var combinedDepthMap: CVPixelBuffer?
        captureQueue.sync {
            let pixelBuffers = depthMaps.compactMap { $0.depthMap }
            combinedDepthMap = pixelBuffers.combine()
        }
        return combinedDepthMap
    }
    
}

extension Array where Element == CVPixelBuffer {
    
    func combine() -> CVPixelBuffer? {
        guard !isEmpty else { return nil }
        let width = CVPixelBufferGetWidth(self[0])
        let height = CVPixelBufferGetHeight(self[0])
        let pixelFormat = CVPixelBufferGetPixelFormatType(self[0])
        var combinedPixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, width, height, pixelFormat, nil, &combinedPixelBuffer)
        guard let outputPixelBuffer = combinedPixelBuffer else { return nil }
        CVPixelBufferLockBaseAddress(outputPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        for inputPixelBuffer in self {
            guard let inputBaseAddress = CVPixelBufferGetBaseAddress(inputPixelBuffer),
                  let outputBaseAddress = CVPixelBufferGetBaseAddress(outputPixelBuffer) else { continue }
            let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(inputPixelBuffer, 0)
            let inputBufferLength = CVPixelBufferGetDataSize(inputPixelBuffer)
            memcpy(outputBaseAddress, inputBaseAddress, inputBufferLength)
            outputBaseAddress.advanced(by: bytesPerRow * height)
        }
        CVPixelBufferUnlockBaseAddress(outputPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        return outputPixelBuffer
    }
    
}
