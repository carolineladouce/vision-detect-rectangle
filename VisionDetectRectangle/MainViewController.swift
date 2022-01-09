//
//  ViewController.swift
//  VisionDetectRectangle
//
//  Created by Caroline LaDouce on 1/8/22.
//

import UIKit
import AVFoundation
import Vision


class MainViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
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
    
    
    private lazy var previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
    
    
    private func showCameraFeed() {
        self.previewLayer.videoGravity = .resizeAspectFill
        self.view.layer.addSublayer(self.previewLayer)
        self.previewLayer.frame = self.view.frame
    }
    
    
    private let videoDataOutput = AVCaptureVideoDataOutput()
    
    private func setCameraOutput() {
        self.videoDataOutput.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as NSString) : NSNumber(value: kCVPixelFormatType_32BGRA)] as [String : Any]
        
        self.videoDataOutput.alwaysDiscardsLateVideoFrames = true
        self.videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera_frame_processing_queue"))
        
        self.captureSession.addOutput(self.videoDataOutput)
        
        guard let connection = self.videoDataOutput.connection(with: AVMediaType.video),
              connection.isVideoOrientationSupported else { return }
        connection.videoOrientation = .portrait
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        view.backgroundColor = .white
        
        self.setCameraInput()
        self.showCameraFeed()
        setCameraOutput()
        //self.captureSession.startRunning()
        
        viewDidAppear(true)
        viewDidDisappear(true)
    }
    
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.previewLayer.frame = self.view.bounds
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        // Session Start
        self.videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera_frame_processing_queue"))
        self.captureSession.startRunning()
    }
    
    
    override func viewDidDisappear(_ animated: Bool) {
        // Session Stop
        self.videoDataOutput.setSampleBufferDelegate(nil, queue: nil)
        self.captureSession.stopRunning()
    }
    
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let frame = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            debugPrint("Unable to get image from sample buffer")
            return
        }
        self.detectRectangle(in: frame)
    }
    
    
    private func detectRectangle(in image: CVPixelBuffer) {
        let request = VNDetectRectanglesRequest(completionHandler:  {(request: VNRequest, error: Error?) in
            DispatchQueue.main.async {
                guard let results = request.results as? [VNRectangleObservation] else { return }
                self.removeBoundingBoxLayer()
                
                // Retrieve the first observed rectangle
                guard let rect = results.first else { return }
                
                // Fuction used to draw the bounding box of the detected rectangle
                self.drawBoundingBox(rect: rect)
            }
        })
        
        // Set the values for the detected rectangle
        request.minimumAspectRatio = VNAspectRatio(0.3)
        request.maximumAspectRatio = VNAspectRatio(0.9)
        request.minimumSize = Float(0.3)
        request.maximumObservations = 1
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: image, options: [:])
        
        try? imageRequestHandler.perform([request])
    }
    
    
    func drawBoundingBox(rect : VNRectangleObservation) {
        let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -self.previewLayer.bounds.height)
        
        let scale = CGAffineTransform.identity.scaledBy(x: self.previewLayer.bounds.width, y: self.previewLayer.bounds.height)
        
        let bounds = rect.boundingBox.applying(scale).applying(transform)
        
        createLayer(in: bounds)
    }
    
    
    private var bBoxLayer = CAShapeLayer()
    
    private func createLayer(in rect: CGRect) {
        bBoxLayer = CAShapeLayer()
        bBoxLayer.frame = rect
        bBoxLayer.cornerRadius = 10
        bBoxLayer.opacity = 1
        bBoxLayer.borderColor = UIColor.systemBlue.cgColor
        bBoxLayer.borderWidth = 6.0
        previewLayer.insertSublayer(bBoxLayer, at: 1)
    }
    
    func removeBoundingBoxLayer() {
        bBoxLayer.removeFromSuperlayer()
    }
    
    
    func imageExtraction(_ observation: VNRectangleObservation, from buffer: CVImageBuffer) -> UIImage {
        var ciImage = CIImage(cvImageBuffer: buffer)
        
        let topLeft = observation.topLeft.scaled(to: ciImage.extent.size)
        let topRight = observation.topRight.scaled(to: ciImage.extent.size)
        let bottomLeft = observation.bottomLeft.scaled(to: ciImage.extent.size)
        let bottomRight = observation.bottomRight.scaled(to: ciImage.extent.size)
        
        // pass filters to extract/rectify the image
        ciImage = ciImage.applyingFilter("CIPerscpectiveCorrection", parameters: [
            "inputTopLeft": CIVector(cgPoint: topLeft),
            "inputTopRight": CIVector(cgPoint: topRight),
            "inputBottomLeft": CIVector(cgPoint: bottomLeft),
            "inputBottomRight": CIVector(cgPoint: bottomRight)
        ])
        
        let context = CIContext()
        let cgImage = context.createCGImage(ciImage, from: ciImage.extent)
        let output = UIImage(cgImage: cgImage!)
        
        // Return image
        return output
    }
    
    
    
    
}



extension CGPoint {
    func scaled(to size: CGSize) -> CGPoint {
        return CGPoint(x: self.x * size.width, y: self.y * size.height)
    }
}
