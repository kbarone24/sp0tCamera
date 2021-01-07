//
//  GIFPreviewController.swift
//  sp0tCamera
//
//  Created by kbarone on 1/7/21.
//

import Foundation
import UIKit

protocol GIFPreviewDelegate {
    func FinishPassing(images: [(UIImage)])
}

class GIFPreviewController: UIViewController {
    
    lazy var photos: [UIImage] = []
    
    var gif = false
    var previewView: UIImageView!
    var draftsButton: UIButton!
    var delegate: GIFPreviewDelegate?
    var offset: CGFloat = 0
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.isHidden = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor(named: "SpotBlack")
        
        let minY : CGFloat = UIScreen.main.bounds.height > 800 ? (UIScreen.main.bounds.height - 710) / 2 : 39
        let cameraHeight = UIScreen.main.bounds.width * 1.6
        
        /// display the still image or GIF on an image preview to allow the user to preview what they just captured
        previewView = UIImageView(frame: CGRect(x: 0, y: minY, width: UIScreen.main.bounds.width, height: cameraHeight))
        previewView.image = photos[0]
        previewView.contentMode = .scaleAspectFill
        previewView.clipsToBounds = true
        previewView.isUserInteractionEnabled = true
        previewView.layer.cornerRadius = 4
        view.addSubview(previewView)
        
        /// if this is the GIF we use the UIImageView extension animateGIF to animate between images in the GIF
        if gif { previewView.animateGIF(directionUp: true, counter: 0, photos: photos) }
        
        /// manual back button takes user back to camera
        let cancelButton = UIButton(frame: CGRect(x: 17, y: 13, width: 38, height: 38))
        cancelButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        cancelButton.setImage(UIImage(named: "CancelButton"), for: .normal)
        cancelButton.addTarget(self, action: #selector(backTapped(_:)), for: .touchUpInside)
        previewView.addSubview(cancelButton)
    }
        
    @objc func backTapped(_ sender: UIButton) {
        guard let controllers = self.navigationController?.viewControllers else { return }
        if let vc = controllers[controllers.count - 2] as? AVCameraController {
            vc.animationImages.removeAll()
            self.navigationController?.popToViewController(vc, animated: true)
        }
    }
}

// These classes just convert the images to a video to be saved to the user's camera roll

extension UIImageView {
    
    /// Animate gif will create a "bounce" animation. Rather than resetting back to image 0 after the animation is finished, the animation will play backwards back to 0
    func animateGIF(directionUp: Bool, counter: Int, photos: [UIImage]) {
        
        if superview == nil { return }
        var newDirection = directionUp
        var newCount = counter
        
        if directionUp {
            if counter == 4 {
                newDirection = false
                newCount = 3
            } else {
                newCount += 1
            }
            
        } else {
            if counter == 0 {
                newDirection = true
                newCount = 1
            } else {
                newCount -= 1
            }
        }
        
        /// animation here is meant to smooth the transition between images in the GIF but doesn't work particularly well
        UIView.transition(with: self, duration: 0.1, options: [.transitionCrossDissolve, .allowUserInteraction, .beginFromCurrentState], animations: { [weak self] in
            guard let self = self else { return }
                            self.image = photos[counter] },
                          completion: nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            self.animateGIF(directionUp: newDirection, counter: newCount, photos: photos)
        }
        
    }
}
