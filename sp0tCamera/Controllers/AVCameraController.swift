//
//  AVCameraController.swift
//  Spot
//
//  Created by kbarone on 3/23/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation
import Photos
import CoreData

protocol AVCameraDelegate {
    func finishPassing(image: UIImage)
}

class AVCameraController: UIViewController {
    
    var cameraController: AVSpotCamera!
    
    var cameraButton: UIButton!
    var flashButton: UIButton!
    var cancelButton: UIButton!
    var cameraRotateButton: UIButton!
    var gifText: UIButton!
    var stillText: UIButton!
    
    var gifMode = true
    
    var delegate: AVCameraDelegate?
    
    lazy var animationImages: [UIImage] = []
    var dotView: UIView!
    
    var lastZoomFactor: CGFloat = 1.0
    var initialBrightness: CGFloat = 0.0

    var tapIndicator: UIImageView!
    var frontFlashView: UIView!
    
    var start: CFAbsoluteTime!
    
    var cameraHeight: CGFloat!
    
    
    override func viewWillAppear(_ animated: Bool) {

        super.viewWillAppear(animated)
        
        self.navigationController?.navigationBar.isHidden = true
        self.navigationController?.navigationBar.isTranslucent = false
        self.navigationController?.navigationBar.barTintColor = UIColor(named: "SpotBlack")
        self.navigationController?.navigationBar.tintColor = .white

        ///set up camera view if not already loaded
        if self.cameraController == nil {
            cameraController = AVSpotCamera()
            configureCameraController()
        }
    }
    
    deinit {
        print("deinit cam")
    }
        
    override func viewDidLoad() {
        self.view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        self.view.backgroundColor = UIColor(named: "SpotBlack")
        
        /// camera height will be 600 for iphone 6-10, 662.4 for XR + 11
        let cameraAspect: CGFloat = 1.6
        cameraHeight = UIScreen.main.bounds.width * cameraAspect
                
        let minY : CGFloat = UIScreen.main.bounds.height > 800 ? (UIScreen.main.bounds.height - 710) / 2 : 39
        
        /// offset the camera to appear in the center of the screen
        let cameraOffset: CGFloat = cameraHeight > 600 ? 621 : 600
        let cameraY = minY == 39 ? UIScreen.main.bounds.height - 126 : minY + cameraOffset + 40
        
        /// camera button will change from the green "Alive" button to the white "Still" button depending on which camera mode the user changes
        cameraButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width/2 - 46, y: cameraY, width: 92, height: 92))
        cameraButton.imageEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        cameraButton.setImage(UIImage(named: "GIFCameraButton"), for: .normal)
        cameraButton.addTarget(self, action: #selector(captureImage(_:)), for: .touchUpInside)
        cameraButton.imageView?.contentMode = .scaleAspectFill
        self.view.addSubview(cameraButton)
        
        /// GIFs are known to the user as "Alives"
        gifText = UIButton(frame: CGRect(x: cameraButton.frame.minX, y: cameraButton.frame.minY - 30, width: 92, height: 30))
        gifText.titleEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        gifText.setTitle("Alive", for: .normal)
        gifText.setTitleColor(.white, for: .normal)
        gifText.titleLabel?.textAlignment = .center
        gifText.titleLabel?.font = UIFont(name: "SFCamera-Semibold", size: 14)
        gifText.titleLabel!.layer.shadowColor = UIColor.black.cgColor
        gifText.titleLabel!.layer.shadowRadius = 1.0
        gifText.titleLabel!.layer.shadowOpacity = 0.8
        gifText.titleLabel!.layer.shadowOffset = CGSize(width: 1, height: 1)
        gifText.titleLabel!.layer.masksToBounds = false
        gifText.addTarget(self, action: #selector(transitionToGIF(_:)), for: .touchUpInside)
        self.view.addSubview(gifText)
        
        /// dot view will show progress dots as each GIF image is captured
        dotView = UIView(frame: CGRect(x: UIScreen.main.bounds.width/2 - 30, y: gifText.frame.minY - 5.5, width: 60, height: 10))
        dotView.backgroundColor = nil
        view.addSubview(dotView)
        
        /// regular images are known as "Stills" to the user
        stillText = UIButton(frame: CGRect(x: gifText.frame.maxX, y: gifText.frame.minY, width: 92, height: 30))
        stillText.titleEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        stillText.setTitle("Still", for: .normal)
        stillText.titleLabel?.font = UIFont(name: "SFCamera-Regular", size: 14)
        stillText.setTitleColor(UIColor.white.withAlphaComponent(0.7), for: .normal)
        stillText.titleLabel!.layer.shadowColor = UIColor.black.cgColor
        stillText.titleLabel!.layer.shadowRadius = 1.0
        stillText.titleLabel!.layer.shadowOpacity = 0.8
        stillText.titleLabel!.layer.shadowOffset = CGSize(width: 1, height: 1)
        stillText.titleLabel!.layer.masksToBounds = false
        stillText.addTarget(self, action: #selector(transitionToStill(_:)), for: .touchUpInside)
        self.view.addSubview(stillText)
        
        /// toggle flash on tap
        flashButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 54, y: minY + 18, width: 41.5, height: 41.5))
        flashButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        flashButton.setImage(UIImage(named: "FlashOff"), for: .normal)
        flashButton.addTarget(self, action: #selector(switchFlash(_:)), for: .touchUpInside)
        flashButton.imageView?.contentMode = .scaleAspectFit
        self.view.addSubview(flashButton)
        
        /// rotate camera on tap
        cameraRotateButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 53, y: flashButton.frame.maxY + 17, width: 41.725, height: 37))
        cameraRotateButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        cameraRotateButton.imageView?.contentMode = .scaleAspectFit
        cameraRotateButton.setImage(UIImage(named: "CameraRotateAlt"), for: .normal)
        cameraRotateButton.addTarget(self, action: #selector(switchCameras(_:)), for: .touchUpInside)
        self.view.addSubview(cameraRotateButton)
        
        /// pan gesture will allow for switching between still and GIF camera
        let pan = UIPanGestureRecognizer.init(target: self, action: #selector(panGesture))
        self.view.addGestureRecognizer(pan)
                
        /// pinchGesture to zoom in.out
        let zoom = UIPinchGestureRecognizer(target: self, action: #selector(pinch(_:)))
        self.view.addGestureRecognizer(zoom)
        
        /// tapGesture to set focus / exposure
        let tap = UITapGestureRecognizer(target: self, action: #selector(tap(_:)))
        self.view.addGestureRecognizer(tap)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.setAutoExposure(_:)),
                                               name: NSNotification.Name.AVCaptureDeviceSubjectAreaDidChange,
                                               object: nil)
        
        /// tapIndicator will give visual indicator to show that the camera is focusing where the user tapped
        tapIndicator = UIImageView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        tapIndicator.image = UIImage(named: "TapFocusIndicator")
        tapIndicator.isHidden = true
        self.view.addSubview(tapIndicator)
        
        /// "front flash" is just a white screen that will be used to imitate a front-facing flash for when the user takes a selfie
        frontFlashView = UIView(frame: view.frame)
        frontFlashView.backgroundColor = .white
        frontFlashView.isHidden = true
        self.view.addSubview(frontFlashView)
    }
    
    @objc func switchFlash(_ sender: UIButton) {
        /// toggle flash on flashButton tap
        
        if flashButton.image(for: .normal) == UIImage(named: "FlashOff")! {
            flashButton.setImage(UIImage(named: "FlashOn"), for: .normal)
            if !gifMode { cameraController.flashMode = .on }
            
        } else {
            flashButton.setImage(UIImage(named: "FlashOff"), for: .normal)
            if !gifMode { cameraController.flashMode = .off }
        }
    }
    
    @objc func switchCameras(_ sender: UIButton) {
        /// switch between front-facing and rear-facing camera on cameraRotateButton tap
        do {
            try cameraController.switchCameras()
            self.resetZoom()
        }
            
        catch {
            print(error)
        }
    }
    
    func setStillFlash() {
        /// still flash uses the standard camera flash
        if flashButton.image(for: .normal) == UIImage(named: "FlashOff")! {
            cameraController.flashMode = .off
        } else {
            cameraController.flashMode = .on
        }
    }
    
    func setGifFlash() {
        /// gif flash manually triggers the users flashlight because it needs to stay enabled for the entirety of the capture
        cameraController.flashMode = .off
    }
    
    @objc func captureImage(_ sender: UIButton) {
        
        if !gifMode {
            /// capture a still image if GifMode is not enabled
            self.captureImage()
            
        } else {
            /// if the gif camera is enabled, capture 5 images in rapid succession
            
            let flash = flashButton.image(for: .normal) == UIImage(named: "FlashOn")
            let selfie = cameraController.currentCameraPosition == .front
            
            addDots(count: 0) /// add the first dot to show the user that the gif is being captured
            cameraButton.isUserInteractionEnabled = false
            
            if flash {
                if selfie {
                    /// toggle front flash for front-facing camera
                    initialBrightness = UIScreen.main.brightness
                    frontFlashView.isHidden = false
                    view.bringSubviewToFront(frontFlashView)
                    UIScreen.main.brightness = 1.0
                    
                } else {
                    /// toggle rear flash for rear-facing camera
                    let device = cameraController.rearCamera
                    device?.toggleFlashlight()
                }
                
                /// flash takes a fraction of a second to trigger so delay the capture call to allow the flash to turn on
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    guard let self = self else { return }
                    self.captureGIF(count: 0)
                }

            } else {
                /// capture gif with no flash
                DispatchQueue.main.async {
                    self.captureGIF(count: 0)
                }
            }
        }
    }
    
    func captureImage() {
        /// capture a still image
        
        cameraController.captureImage {(image, error) in
            guard var image = image else {
                return
            }
            
            let selfie = self.cameraController.currentCameraPosition == .front

            if selfie {
                /// flip the images orientation to show a more natural selfie image
                image = UIImage(cgImage: image.cgImage!, scale: image.scale, orientation: UIImage.Orientation.leftMirrored)
            }
            
            let resizedImage = self.ResizeImage(with: image, scaledToFill:  CGSize(width: UIScreen.main.bounds.width, height: self.cameraHeight))!
            
            if let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "GIFPreview") as? GIFPreviewController {
                
                vc.photos = [resizedImage]
                
                if let navController = self.navigationController { navController.pushViewController(vc, animated: true) }
            }
        }
    }
    
    func addDots(count: Int) {
        
        /// dots show progress with each successive gif image capture
        
        if count < 5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { [weak self] in
                guard let self = self else { return }
                self.addDot(count: count)
                self.addDots(count: count + 1)
            }

        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self = self else { return }
                for sub in self.dotView.subviews {
                    sub.removeFromSuperview()
                }
            }
        }
    }
        
    func captureGIF(count: Int) {
        self.start = CFAbsoluteTimeGetCurrent()
        
        cameraController.captureImage {(image, error) in
            guard var image = image else {
                return
            }
            
            /// completion block is called with the captured image, diff represents the time it took for the capture image block to complete
            let diff = CFAbsoluteTimeGetCurrent() - self.start

            /// timing on GIFs is  off by a bit so sometimes captureGIF is called in intervals of  > 0.25 in which case we want to capture the next image immediately
            print("diff", diff)
            if diff > 0.25 && count < 4 {
                DispatchQueue.main.async {
                    self.captureGIF(count: count + 1)
                }
            } else if count < 4 {
                /// ensure time between images is 0.25 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + (0.25 - diff)) { [weak self] in
                    guard let self = self else { return }
                    self.captureGIF(count: count + 1)
                }
            }
            
            if self.cameraController.currentCameraPosition ==  .front {
                image = UIImage(cgImage: image.cgImage!, scale: image.scale, orientation: UIImage.Orientation.leftMirrored)
            }
            
            /// resize image to fit size of camera preview
            let im2 = self.ResizeImage(with: image, scaledToFill:  CGSize(width: UIScreen.main.bounds.width, height: self.cameraHeight))!
            self.animationImages.append(im2)

            if count == 4 {
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    
                    /// reset front flash brightness after blasting it for fron flash
                    if self.frontFlashView.isHidden == false {
                        UIScreen.main.brightness = self.initialBrightness
                        self.frontFlashView.isHidden = true
                    } else if self.cameraController.currentCameraPosition == .rear && self.flashButton.image(for: .normal) == UIImage(named: "FlashOn")! && self.gifMode {
                        
                        /// manual flashlight used for gif mode so reset this on the final image
                        let device = self.cameraController.rearCamera
                        device?.toggleFlashlight()
                    }
                    
                    self.cameraButton.isUserInteractionEnabled = true
                    
                    if let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "GIFPreview") as? GIFPreviewController {
                        vc.photos = self.animationImages
                        vc.gif = true
                        
                        if let navController = self.navigationController { navController.pushViewController(vc, animated: true) }
                    }
                }
            }
        }
    }
    
    func addDot(count: Int) {
        let offset = CGFloat(count * 11) + 4.5
        let view = UIImageView(frame: CGRect(x: offset, y: 1, width: 7, height: 7))
        view.layer.cornerRadius = 3.5
        view.backgroundColor = .white
        dotView.addSubview(view)
    }
    

    // set up camera preview on screen if we have user permission
    func configureCameraController() {
        cameraController.prepare {(error) in
            if let error = error {
                print(error)
            }
            
            if (AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined) {
                AVCaptureDevice.requestAccess(for: .video) { response in
                    DispatchQueue.main.async { // 4
                        self.configureCameraController()
                    }
                }
            }
            
            else if AVCaptureDevice.authorizationStatus(for: .video) == .denied || AVCaptureDevice.authorizationStatus(for: .video) == .restricted {
                let alert = UIAlertController(title: "Allow camera access to take a picture", message: nil, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Settings", style: .default, handler: { action in
                    switch action.style{
                    case .default:
                        
                        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)! as URL, options: [:], completionHandler: nil)
                        
                    case .cancel:
                        print("cancel")
                    case .destructive:
                        print("destruct")
                    @unknown default:
                        fatalError()
                    }}))
                alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
                    switch action.style{
                    case .default:
                        break
                    case .cancel:
                        print("cancel")
                    case .destructive:
                        print("destruct")
                    @unknown default:
                        fatalError()
                    }}))
                
                self.present(alert, animated: false, completion: nil)
                
            } else {
                if !self.cameraController.previewShown {
                    try? self.cameraController.displayPreview(on: self.view)
                 //   self.setAutoExposure()
                }
            }
        }
    }
    
    @objc func setAutoExposure(_ sender: NSNotification) {
        self.setAutoExposure()
    }
    
    func setAutoExposure() {
        
        var device: AVCaptureDevice!
        if cameraController.currentCameraPosition == .rear {
            device = cameraController.rearCamera
        } else {
            device = cameraController.frontCamera
        }
        try? device.lockForConfiguration()
        device.isSubjectAreaChangeMonitoringEnabled = true
        if device.isFocusModeSupported(AVCaptureDevice.FocusMode.continuousAutoFocus) {
            device.focusMode = AVCaptureDevice.FocusMode.continuousAutoFocus
        }
        if device.isExposureModeSupported(AVCaptureDevice.ExposureMode.continuousAutoExposure) {
            device.exposureMode = AVCaptureDevice.ExposureMode.continuousAutoExposure
        }
        device.unlockForConfiguration()
    }
    
    func ResizeImage(with image: UIImage?, scaledToFill size: CGSize) -> UIImage? {
        
        let scale: CGFloat = max(size.width / (image?.size.width ?? 0.0), size.height / (image?.size.height ?? 0.0))
        let width: CGFloat = (image?.size.width ?? 0.0) * scale
        let height: CGFloat = (image?.size.height ?? 0.0) * scale
        let imageRect = CGRect(x: (size.width - width) / 2.0, y: (size.height - height) / 2.0, width: width, height: height)
        
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        image?.draw(in: imageRect)
        let newImage: UIImage? = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }
    
    @objc func panGesture(_ gesture: UIPanGestureRecognizer) {
        
        /// swipe between camera types
        
        let direction = gesture.velocity(in: self.view)
        
        if gesture.state == .ended {
            if abs(direction.x) > abs(direction.y) && direction.x < 200 {
                if self.gifMode {
                    self.transitionToStill()
                }
                
            } else if abs(direction.x) > abs(direction.y) && direction.x > 200 {
                if !self.gifMode {
                    self.transitionToGIF()
                }
                
            } 
        }
    }

        
    @objc func pinch(_ pinch: UIPinchGestureRecognizer) {
        
        //pinch to zoom in / zoom out
        
        let minimumZoom: CGFloat = 1.0
        let maximumZoom: CGFloat = 5.0

        var device: AVCaptureDevice!
        if cameraController.currentCameraPosition == .rear {
            device = cameraController.rearCamera
        } else {
            device = cameraController.frontCamera
        }
        
        func minMaxZoom(_ factor: CGFloat) -> CGFloat {
            return min(min(max(factor, minimumZoom), maximumZoom), device.activeFormat.videoMaxZoomFactor)
        }
        
        func update(scale factor: CGFloat) {
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                device.videoZoomFactor = factor
            } catch {
                print("\(error.localizedDescription)")
            }
        }
        
        let newScaleFactor = minMaxZoom(pinch.scale * lastZoomFactor)
        
        switch pinch.state {
        case .began: fallthrough
        case .changed: update(scale: newScaleFactor)
        case .ended:
            lastZoomFactor = minMaxZoom(newScaleFactor)
            update(scale: lastZoomFactor)
        default: break
        }
    }
    
    @objc func tap(_ tapGesture: UITapGestureRecognizer) {
        
        // tap to set focus and exposure
        
        if AVCaptureDevice.authorizationStatus(for: .video) != .authorized {
            return
        }
        
        let bounds = UIScreen.main.bounds
        
        let position = tapGesture.location(in: view)
        let screenSize = bounds.size
        let focusPoint = CGPoint(x: position.y / screenSize.height, y: 1.0 - position.x / screenSize.width)
        
        /// add disappearing tap circle indicator and set focus on the tap area
        if position.y < UIScreen.main.bounds.height - 100  && position.y > 50 {
            tapIndicator.frame = CGRect(x: position.x - 25, y: position.y - 25, width: 50, height: 50)
            tapIndicator.isHidden = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                UIView.animate(withDuration: 0.6, animations: { [weak self] in
                    guard let self = self else { return }
                    self.tapIndicator.isHidden = true
                })
            }
            
            var device: AVCaptureDevice!
            if cameraController.currentCameraPosition == .rear {
                device = cameraController.rearCamera
            } else {
                device = cameraController.frontCamera
            }
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = focusPoint
                    device.focusMode = AVCaptureDevice.FocusMode.autoFocus
                }
                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = focusPoint
                    device.exposureMode = AVCaptureDevice.ExposureMode.autoExpose
                }
                device.unlockForConfiguration()
                
            } catch {
                // Handle errors here
                print("There was an error focusing the device's camera")
            }
        }
    }
    
    func resetZoom() {
        
        // resets the zoom level when switching between rear and front cameras
        
        var device: AVCaptureDevice!
        if cameraController.currentCameraPosition == .rear {
            device = cameraController.rearCamera
        } else {
            device = cameraController.frontCamera
        }
        
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            device.videoZoomFactor = 1.0
            self.lastZoomFactor = 1.0
        } catch {
            print("\(error.localizedDescription)")
        }
    }
    
    @objc func transitionToStill(_ sender: UIButton) {
        transitionToStill()
    }
    
    func transitionToStill() {
        
        // transition to still image capture
        
        if self.gifMode {
            self.gifMode = false
            
            UIView.animate(withDuration: 0.3, animations: {
                self.stillText.titleLabel?.font = UIFont(name: "SFCamera-Semibold", size: 14)
                self.gifText.titleLabel?.font = UIFont(name: "SFCamera-Regular", size: 14)
                self.stillText.frame = CGRect(x: self.cameraButton.frame.minX, y: self.stillText.frame.minY, width: self.stillText.frame.width, height: self.stillText.frame.height)
                self.gifText.frame = CGRect(x: self.stillText.frame.minX - 85, y: self.gifText.frame.minY, width: self.gifText.frame.width, height: self.gifText.frame.height)
                self.gifText.setTitleColor(UIColor.white.withAlphaComponent(0.7), for: .normal)
                self.stillText.setTitleColor(UIColor.white, for: .normal)
                self.cameraButton.setImage(UIImage(named: "CameraButton"), for: .normal)
                self.setStillFlash()
            })
        }
    }
    
    @objc func transitionToGIF(_ sender: UIButton) {
        transitionToGIF()
    }
    
    func transitionToGIF() {
        
        // transition to GIF image capture
        
        if !self.gifMode {
            self.gifMode = true
            
            UIView.animate(withDuration: 0.3, animations: {
                self.stillText.titleLabel?.font = UIFont(name: "SFCamera-Regular", size: 14)
                self.gifText.titleLabel?.font = UIFont(name: "SFCamera-Semibold", size: 14)
                self.gifText.frame = CGRect(x: self.cameraButton.frame.minX, y: self.gifText.frame.minY, width: self.gifText.frame.width, height: self.gifText.frame.height)
                self.stillText.frame = CGRect(x: self.gifText.frame.maxX, y: self.stillText.frame.minY, width: self.stillText.frame.width, height: self.stillText.frame.height)
                self.stillText.setTitleColor(UIColor.white.withAlphaComponent(0.7), for: .normal)
                self.gifText.setTitleColor(UIColor.white, for: .normal)
                self.cameraButton.setImage(UIImage(named: "GIFCameraButton"), for: .normal)
                self.setGifFlash()
            })
        }
    }
}
