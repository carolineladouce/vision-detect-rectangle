//
//  ViewController.swift
//  VisionDetectRectangle
//
//  Created by Caroline LaDouce on 1/8/22.
//

import UIKit
import AVFoundation


class MainViewController: UIViewController {
    
    private let captureSession = AVCaptureSession()
    
    private func setCameraInput() {
        guard let device = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera,
                          .builtInDualCamera,
                          .builtInTrueDepthCamera],
            mediaType: .video,
            position: .back
        ).devices.first else {
            fatalError("No back camera device found.")
        }
        
        let cameraInput = try! AVCaptureDeviceInput(device: device)
        self.captureSession.addInput(cameraInput)
    }
    
    

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        view.backgroundColor = .white
    }


}

