//
//  DocumentViewController.swift
//  OneCut
//
//  Created by zpc on 2018/7/3.
//  Copyright © 2018年 Apple Inc. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit
import MobileCoreServices
import NVActivityIndicatorView

private var MainViewControllerKVOContext = 0

class MainViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, NVActivityIndicatorViewable {
    
    // MARK: - View Controller
    
    override func viewDidLoad() {
        playerView.playerLayer.player = player
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        player.play()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        player.pause()
    }
    
    
    // Attempt load and test these asset keys before playing.
    static let assetKeysRequiredToPlay = [
        "playable",
        "hasProtectedContent"
    ]
    
    @objc let player = AVPlayer()
    
    var rate: Float {
        get {
            return player.rate
        }
        
        set {
            player.rate = newValue
        }
    }
    
    var composition: AVMutableComposition? = nil
    var videoComposition: AVMutableVideoComposition? = nil
    var audioMix: AVMutableAudioMix? = nil
    
    private var playerLayer: AVPlayerLayer? {
        return playerView.playerLayer
    }
    
    
    /*
     A token obtained from calling `player`'s `addPeriodicTimeObserverForInterval(_:queue:usingBlock:)`
     method.
     */
    
    private var playerItem: AVPlayerItem? = nil
    
    // MARK: - IBOutlets
    
    @IBOutlet weak var playerView: PlayerView!

    @IBOutlet weak var cameraButton: UIButton! {
        didSet {
            cameraButton.isEnabled = UIImagePickerController.isSourceTypeAvailable(.savedPhotosAlbum)
        }
    }
    
    // MARK: - IBActions
    
    func export()
    {
        // Create the export session with the composition and set the preset to the highest quality.
        let compatiblePresets = AVAssetExportSession.exportPresets(compatibleWith: composition!)
        let exporter = AVAssetExportSession(asset: composition!, presetName: AVAssetExportPresetHEVCHighestQuality)!
        // Set the desired output URL for the file created by the export process.
        exporter.outputURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent(String(Int(Date.timeIntervalSinceReferenceDate))).appendingPathExtension("mov")
        // Set the output file type to be a QuickTime movie.
        exporter.outputFileType = AVFileType.mov
        exporter.shouldOptimizeForNetworkUse = true
        exporter.videoComposition = self.videoComposition
        // Asynchronously export the composition to a video file and save this file to the camera roll once export completes.
        
        let size = CGSize(width: 100, height: 100)
        
        startAnimating(size, message: "正在导出...", type: NVActivityIndicatorType(rawValue: NVActivityIndicatorType.lineScalePulseOut.rawValue)!)
        
        exporter.exportAsynchronously {
            DispatchQueue.main.async {
                if (exporter.status == .completed) {
                    if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(exporter.outputURL!.path)){
                        UISaveVideoAtPathToSavedPhotosAlbum(exporter.outputURL!.path, self, #selector(self.video), nil)
                    }
                    NVActivityIndicatorPresenter.sharedInstance.setMessage("导出成功")
                    
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
                        self.stopAnimating()
                    }
                } else {
                    NVActivityIndicatorPresenter.sharedInstance.setMessage("导出失败")
                    
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
                        self.stopAnimating()
                    }
                }
            }
        }
    }
    
    @objc func video(videoPath: NSString, didFinishSavingWithError error:NSError, contextInfo contextInfo:Any) -> Void {
    }
    
    func addClip(_ movieURL: URL) {
        let newAsset = AVURLAsset(url: movieURL, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        
        /*
         Using AVAsset now runs the risk of blocking the current thread (the
         main UI thread) whilst I/O happens to populate the properties. It's
         prudent to defer our work until the properties we need have been loaded.
         */
        newAsset.loadValuesAsynchronously(forKeys: MainViewController.assetKeysRequiredToPlay) {
            /*
             The asset invokes its completion handler on an arbitrary queue.
             To avoid multiple threads using our internal state at the same time
             we'll elect to use the main thread at all times, let's dispatch
             our handler to the main queue.
             */
            DispatchQueue.main.async {
                
                /*
                 Test whether the values of each of the keys we need have been
                 successfully loaded.
                 */
                for key in MainViewController.assetKeysRequiredToPlay {
                    var error: NSError?
                    
                    if newAsset.statusOfValue(forKey: key, error: &error) == .failed {
                        let stringFormat = NSLocalizedString("error.asset_key_%@_failed.description", comment: "Can't use this AVAsset because one of it's keys failed to load")
                        
                        let message = String.localizedStringWithFormat(stringFormat, key)
                        
                        self.handleErrorWithMessage(message, error: error)
                        
                        return
                    }
                }
                
                // We can't play this asset.
                if !newAsset.isPlayable || newAsset.hasProtectedContent {
                    let message = NSLocalizedString("error.asset_not_playable.description", comment: "Can't use this AVAsset because it isn't playable or has protected content")
                    
                    self.handleErrorWithMessage(message)
                    
                    return
                }
                
                /*
                 We can play this asset. Create a new `AVPlayerItem` and make
                 it our player's current item.
                 */
                
                self.composition = AVMutableComposition()
                // Add two video tracks and two audio tracks.
                let firstVideoTrack = self.composition!.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
                
                let secondVideoTrack = self.composition!.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
                
                let audioTrack = self.composition!.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!
                    
                
                let videoAssetTrack = newAsset.tracks(withMediaType: .video).first!
                
                let audioAssetTrack = newAsset.tracks(withMediaType: .audio).first!
                
                try! firstVideoTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, newAsset.duration), of: videoAssetTrack, at: kCMTimeZero)
                
                try! secondVideoTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, newAsset.duration), of: videoAssetTrack, at: kCMTimeZero)
                
                try! audioTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, newAsset.duration), of: audioAssetTrack, at: kCMTimeZero)
                
                
                if false {
                    self.videoComposition = AVMutableVideoComposition()
                    self.videoComposition?.renderSize = CGSize(width: 1080, height: 1920)
                    self.videoComposition?.frameDuration = CMTimeMake(1, 30)
                    
                    let transformer1 = AVMutableVideoCompositionLayerInstruction(assetTrack: firstVideoTrack)
                    
                    let transformer2 = AVMutableVideoCompositionLayerInstruction(assetTrack: secondVideoTrack)
                    
                    let instruction = AVMutableVideoCompositionInstruction()
                    instruction.timeRange = CMTimeRangeMake(kCMTimeZero, newAsset.duration)
                    let scale = 2*(self.videoComposition?.renderSize.width)!/videoAssetTrack.naturalSize.width
                    
                    transformer1.setCropRectangle(CGRect(x: 0, y: 0, width: videoAssetTrack.naturalSize.width/2, height: videoAssetTrack.naturalSize.height), at: kCMTimeZero)
                    transformer1.setTransform(CGAffineTransform.identity.scaledBy(x: scale/3.0, y: scale/3.0).translatedBy(x: videoAssetTrack.naturalSize.width-15, y: videoAssetTrack.naturalSize.height/8), at: kCMTimeZero)
                    
                    transformer2.setCropRectangle(CGRect(x: videoAssetTrack.naturalSize.width/2, y: 0, width: videoAssetTrack.naturalSize.width/2, height: videoAssetTrack.naturalSize.height), at: kCMTimeZero)
                    transformer2.setTransform(CGAffineTransform.identity.scaledBy(x: scale, y: scale).translatedBy(x: -videoAssetTrack.naturalSize.width/2, y: 0), at: kCMTimeZero)
                    
                    instruction.layerInstructions = [transformer1, transformer2]
                    self.videoComposition?.instructions = [instruction]
                    
                    
                    let weixin = CALayer()
                    weixin.contents = UIImage(named: "weixintop")!.cgImage!
                    weixin.frame = CGRect(origin: .zero, size: self.videoComposition!.renderSize)
                    weixin.contentsGravity = "top"
                    weixin.contentsScale = CGFloat(UIImage(named: "weixintop")!.cgImage!.width) / self.videoComposition!.renderSize.width * 1.1
                    
                    let weixinbottom = CALayer()
                    weixinbottom.contents = UIImage(named: "weixinbottom")!.cgImage!
                    weixinbottom.frame = CGRect(origin: .zero, size: self.videoComposition!.renderSize)
                    weixinbottom.contentsGravity = "bottom"
                    weixinbottom.contentsScale = CGFloat(UIImage(named: "weixinbottom")!.cgImage!.width) / self.videoComposition!.renderSize.width * 1.2
                    
                    weixin.addSublayer(weixinbottom)

                    let textLayer = CATextLayer()
                    
                    textLayer.string = "00:00"
                    textLayer.foregroundColor = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
                    textLayer.fontSize = 50.0
                    textLayer.font = UIFont(name: "Helvetica", size: 36.0)
                    
                    textLayer.alignmentMode = kCAAlignmentCenter
                    textLayer.frame = weixin.frame
                    textLayer.frame.origin = .zero
                    textLayer.frame.origin.y = self.videoComposition!.renderSize.height / 4
                    textLayer.frame.size.height = textLayer.preferredFrameSize().height
                    
                    let anim = CAKeyframeAnimation(keyPath: "string")
                    let count = Int(CMTimeGetSeconds(newAsset.duration)) + 1
                    anim.duration = Double(count)
                    anim.calculationMode = kCAAnimationDiscrete
                    anim.keyTimes = (0...count).map {Double($0)/3.0/Double(count)} as [NSNumber]
                    anim.values = (0...count).map {self.createTimeString(time: Double(1000+$0))}
                    textLayer.add(anim, forKey: nil)
                    
                    weixin.addSublayer(textLayer)
                    
                    let parentLayer = CALayer()
                    let videoLayer = CALayer()
                    parentLayer.frame = CGRect(origin: .zero, size: self.videoComposition!.renderSize)
                    videoLayer.frame = CGRect(origin: .zero, size: self.videoComposition!.renderSize)

                    parentLayer.addSublayer(videoLayer)
                    parentLayer.addSublayer(weixin)
                    self.videoComposition?.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parentLayer)
                    
                    self.export()
                } else {
                    self.videoComposition = AVMutableVideoComposition()
                    self.videoComposition?.renderSize = CGSize(width: 1080, height: 1920)
                    self.videoComposition?.frameDuration = CMTimeMake(1, 30)
                    
                    let transformer1 = AVMutableVideoCompositionLayerInstruction(assetTrack: firstVideoTrack)
                    
                    let transformer2 = AVMutableVideoCompositionLayerInstruction(assetTrack: secondVideoTrack)
                    
                    let instruction = AVMutableVideoCompositionInstruction()
                    instruction.timeRange = CMTimeRangeMake(kCMTimeZero, newAsset.duration)
                    let scale = 2*(self.videoComposition?.renderSize.width)!/videoAssetTrack.naturalSize.width
                    
                    transformer1.setCropRectangle(CGRect(x: videoAssetTrack.naturalSize.width/2, y: 0, width: videoAssetTrack.naturalSize.width/2, height: videoAssetTrack.naturalSize.height), at: kCMTimeZero)
                    transformer1.setTransform(CGAffineTransform.identity.scaledBy(x: scale/3.0, y: scale/3.0).translatedBy(x: videoAssetTrack.naturalSize.width/2-15, y: videoAssetTrack.naturalSize.height/8), at: kCMTimeZero)
                    
                    transformer2.setCropRectangle(CGRect(x: 0, y: 0, width: videoAssetTrack.naturalSize.width/2, height: videoAssetTrack.naturalSize.height), at: kCMTimeZero)
                    transformer2.setTransform(CGAffineTransform.identity.scaledBy(x: scale, y: scale), at: kCMTimeZero)
                    
                    instruction.layerInstructions = [transformer1, transformer2]
                    self.videoComposition?.instructions = [instruction]
                    
                    
                    let weixin = CALayer()
                    weixin.contents = UIImage(named: "weixintop")!.cgImage!
                    weixin.frame = CGRect(origin: .zero, size: self.videoComposition!.renderSize)
                    weixin.contentsGravity = "top"
                    weixin.contentsScale = CGFloat(UIImage(named: "weixintop")!.cgImage!.width) / self.videoComposition!.renderSize.width * 1.1
                    
                    let weixinbottom = CALayer()
                    weixinbottom.contents = UIImage(named: "weixinbottom")!.cgImage!
                    weixinbottom.frame = CGRect(origin: .zero, size: self.videoComposition!.renderSize)
                    weixinbottom.contentsGravity = "bottom"
                    weixinbottom.contentsScale = CGFloat(UIImage(named: "weixinbottom")!.cgImage!.width) / self.videoComposition!.renderSize.width * 1.2
                    
                    weixin.addSublayer(weixinbottom)
                    
                    let textLayer = CATextLayer()
                    
                    textLayer.string = "00:00"
                    textLayer.foregroundColor = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
                    textLayer.fontSize = 50.0
                    textLayer.font = UIFont(name: "Helvetica", size: 36.0)
                    
                    textLayer.alignmentMode = kCAAlignmentCenter
                    textLayer.frame = weixin.frame
                    textLayer.frame.origin = .zero
                    textLayer.frame.origin.y = self.videoComposition!.renderSize.height / 4
                    textLayer.frame.size.height = textLayer.preferredFrameSize().height
                    
                    let anim = CAKeyframeAnimation(keyPath: "string")
                    let count = Int(CMTimeGetSeconds(newAsset.duration)) + 1
                    anim.duration = Double(count)
                    anim.calculationMode = kCAAnimationDiscrete
                    anim.keyTimes = (0...count).map {Double($0)/3.0/Double(count)} as [NSNumber]
                    anim.values = (0...count).map {self.createTimeString(time: Double(1000+$0))}
                    textLayer.add(anim, forKey: nil)
                    
                    weixin.addSublayer(textLayer)
                    
                    let parentLayer = CALayer()
                    let videoLayer = CALayer()
                    parentLayer.frame = CGRect(origin: .zero, size: self.videoComposition!.renderSize)
                    videoLayer.frame = CGRect(origin: .zero, size: self.videoComposition!.renderSize)
                    
                    parentLayer.addSublayer(videoLayer)
                    parentLayer.addSublayer(weixin)
                    self.videoComposition?.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parentLayer)
                    
                    self.export()
                }
                
                
                return
            }
        }
    }
    
    let timeRemainingFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.zeroFormattingBehavior = .pad
        formatter.allowedUnits = [.minute, .second]
        
        return formatter
    }()
    
    func createTimeString(time: Double) -> String {
        let components = NSDateComponents()
        components.second = Int(max(0.0, time))
        
        return timeRemainingFormatter.string(from: components as DateComponents)!
    }
    
    
    @IBAction func AddVideo(_ sender: UIButton) {
        let picker = UIImagePickerController()
        picker.sourceType = .savedPhotosAlbum
        picker.mediaTypes = [kUTTypeMovie as String]
        picker.delegate = self
        picker.allowsEditing = true
        present(picker, animated: true)
    }
    
    
    // MARK: - Error Handling
    
    func handleErrorWithMessage(_ message: String?, error: Error? = nil) {
        NSLog("Error occured with message: \(message), error: \(error).")
        
        let alertTitle = NSLocalizedString("alert.error.title", comment: "Alert title for errors")
        let defaultAlertMessage = NSLocalizedString("error.default.description", comment: "Default error message when no NSError provided")
        
        let alert = UIAlertController(title: alertTitle, message: message == nil ? defaultAlertMessage : message, preferredStyle: UIAlertControllerStyle.alert)
        
        let alertActionTitle = NSLocalizedString("alert.error.actions.OK", comment: "OK on error alert")
        
        let alertAction = UIAlertAction(title: alertActionTitle, style: .default, handler: nil)
        
        alert.addAction(alertAction)
        
        present(alert, animated: true, completion: nil)
    }
    
    // MARK: Delegate
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.presentingViewController?.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        if let videoURL = info[UIImagePickerControllerMediaURL] as? URL {
            addClip(videoURL)
        }
        picker.presentingViewController?.dismiss(animated: true, completion: nil)

    }
    
}

