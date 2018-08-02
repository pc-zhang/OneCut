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
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if UIImagePickerController.isSourceTypeAvailable(.savedPhotosAlbum) {
            let picker = UIImagePickerController()
            picker.sourceType = .savedPhotosAlbum
            picker.mediaTypes = [kUTTypeMovie as String]
            picker.delegate = self
            picker.allowsEditing = true
            present(picker, animated: false)
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
    }
    
    static let assetKeysRequiredToPlay = [
        "playable",
        "hasProtectedContent"
    ]

    // MARK: - IBActions
    
    func export(_ newAsset: AVURLAsset, _ front: Bool)
    {
        let composition = AVMutableComposition()
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = CGSize(width: 1080, height: 1920)
        videoComposition.frameDuration = CMTimeMake(1, 30)
        
        // Add two video tracks and two audio tracks.
        let firstVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
        
        let secondVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
        
        let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!
        
        
        guard let videoAssetTrack = newAsset.tracks(withMediaType: .video).first else {
            self.handleErrorWithMessage("这个视频坏掉了，换个视频试试？")
            return
        }
        
        if let audioAssetTrack = newAsset.tracks(withMediaType: .audio).first {
            try? audioTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, newAsset.duration), of: audioAssetTrack, at: kCMTimeZero)
        }
        
        try? firstVideoTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, newAsset.duration), of: videoAssetTrack, at: kCMTimeZero)
        
        try? secondVideoTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, newAsset.duration), of: videoAssetTrack, at: kCMTimeZero)
        
        
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRangeMake(kCMTimeZero, newAsset.duration)
        let scale = 2*videoComposition.renderSize.width/videoAssetTrack.naturalSize.width
        
        
        let transformer1 = AVMutableVideoCompositionLayerInstruction(assetTrack: firstVideoTrack)
        
        let transformer2 = AVMutableVideoCompositionLayerInstruction(assetTrack: secondVideoTrack)
        
        if front {
            transformer1.setCropRectangle(CGRect(x: 0, y: 0, width: videoAssetTrack.naturalSize.width/2, height: videoAssetTrack.naturalSize.height), at: kCMTimeZero)
            transformer1.setTransform(CGAffineTransform.identity.scaledBy(x: scale/3.0, y: scale/3.0).translatedBy(x: videoAssetTrack.naturalSize.width-15, y: videoAssetTrack.naturalSize.height/8), at: kCMTimeZero)
            
            transformer2.setCropRectangle(CGRect(x: videoAssetTrack.naturalSize.width/2, y: 0, width: videoAssetTrack.naturalSize.width/2, height: videoAssetTrack.naturalSize.height), at: kCMTimeZero)
            transformer2.setTransform(CGAffineTransform.identity.scaledBy(x: scale, y: scale).translatedBy(x: -videoAssetTrack.naturalSize.width/2, y: 0), at: kCMTimeZero)
            
        } else {
            transformer1.setCropRectangle(CGRect(x: videoAssetTrack.naturalSize.width/2, y: 0, width: videoAssetTrack.naturalSize.width/2, height: videoAssetTrack.naturalSize.height), at: kCMTimeZero)
            transformer1.setTransform(CGAffineTransform.identity.scaledBy(x: scale/3.0, y: scale/3.0).translatedBy(x: videoAssetTrack.naturalSize.width/2-15, y: videoAssetTrack.naturalSize.height/8), at: kCMTimeZero)
            
            transformer2.setCropRectangle(CGRect(x: 0, y: 0, width: videoAssetTrack.naturalSize.width/2, height: videoAssetTrack.naturalSize.height), at: kCMTimeZero)
            transformer2.setTransform(CGAffineTransform.identity.scaledBy(x: scale, y: scale), at: kCMTimeZero)
        }
        
        instruction.layerInstructions = [transformer1, transformer2]
        videoComposition.instructions = [instruction]
        
        let weixin = CALayer()
        weixin.contents = UIImage(named: "weixintop")!.cgImage!
        weixin.frame = CGRect(origin: .zero, size: videoComposition.renderSize)
        weixin.contentsGravity = "top"
        weixin.contentsScale = CGFloat(UIImage(named: "weixintop")!.cgImage!.width) / videoComposition.renderSize.width * 1.1
        
        let weixinbottom = CALayer()
        weixinbottom.contents = UIImage(named: "weixinbottom")!.cgImage!
        weixinbottom.frame = CGRect(origin: .zero, size: videoComposition.renderSize)
        weixinbottom.contentsGravity = "bottom"
        weixinbottom.contentsScale = CGFloat(UIImage(named: "weixinbottom")!.cgImage!.width) / videoComposition.renderSize.width * 1.2
        
        weixin.addSublayer(weixinbottom)
        
        let textLayer = CATextLayer()
        
        textLayer.string = "00:00"
        textLayer.foregroundColor = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        textLayer.fontSize = 50.0
        textLayer.font = UIFont(name: "Helvetica", size: 36.0)
        
        textLayer.alignmentMode = kCAAlignmentCenter
        textLayer.frame = weixin.frame
        textLayer.frame.origin = .zero
        textLayer.frame.origin.y = videoComposition.renderSize.height / 4
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
        parentLayer.frame = CGRect(origin: .zero, size: videoComposition.renderSize)
        videoLayer.frame = CGRect(origin: .zero, size: videoComposition.renderSize)
        
        parentLayer.addSublayer(videoLayer)
        parentLayer.addSublayer(weixin)
        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parentLayer)

        // Create the export session with the composition and set the preset to the highest quality.
        let compatiblePresets = AVAssetExportSession.exportPresets(compatibleWith: composition)
        if !compatiblePresets.contains(AVAssetExportPresetHighestQuality) {
            self.handleErrorWithMessage("这个视频坏掉了，换个视频试试？")
            return
        }
        let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality)!
        // Set the desired output URL for the file created by the export process.
        exporter.outputURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent(String(Int(Date.timeIntervalSinceReferenceDate))).appendingPathExtension("mov")
        // Set the output file type to be a QuickTime movie.
        exporter.outputFileType = AVFileType.mov
        exporter.shouldOptimizeForNetworkUse = true
        exporter.videoComposition = videoComposition
        // Asynchronously export the composition to a video file and save this file to the camera roll once export completes.
        
        let size = CGSize(width: 100, height: 100)
        
        startAnimating(size, message: "正在导出...", type: NVActivityIndicatorType(rawValue: NVActivityIndicatorType.lineScalePulseOut.rawValue)!)
        
        exporter.exportAsynchronously {
            DispatchQueue.main.async {
                if (exporter.status == .completed) {
                    if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(exporter.outputURL!.path)){
                        UISaveVideoAtPathToSavedPhotosAlbum(exporter.outputURL!.path, self, #selector(self.video), nil)
                    }
                    if front == true {
                        self.export(newAsset, false)
                    } else {
                        NVActivityIndicatorPresenter.sharedInstance.setMessage("导出成功")
                        
                        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2) {
                            self.stopAnimating()
                        }
                    }
                    
                } else {
                    NVActivityIndicatorPresenter.sharedInstance.setMessage("导出失败")
                    
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2) {
                        self.stopAnimating()
                    }
                }
            }
        }
    }
    
    @objc func video(videoPath: NSString, didFinishSavingWithError error:NSError, contextInfo:Any) -> Void {
    }
    
    func addClip(_ movieURL: URL) {
        let newAsset = AVURLAsset(url: movieURL, options: [AVURLAssetPreferPreciseDurationAndTimingKey: false])
        
        newAsset.loadValuesAsynchronously(forKeys: MainViewController.assetKeysRequiredToPlay) {

            DispatchQueue.main.async {
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
                
                if CMTimeGetSeconds(newAsset.duration) > 70 {
                    self.handleErrorWithMessage("请选择70s之内的视频")
                    
                    return
                }
                
                self.export(newAsset, true)
                
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
    
    
    // MARK: - Error Handling
    
    func handleErrorWithMessage(_ message: String?, error: Error? = nil) {
        NSLog("Error occured with message: \(message), error: \(error).")
        
        let size = CGSize(width: 100, height: 100)
        startAnimating(size, message: message, type: NVActivityIndicatorType(rawValue: NVActivityIndicatorType.lineScalePulseOut.rawValue)!)
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2) {
            self.stopAnimating()
        }
    }
    
    // MARK: Delegate
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        if let videoURL = info[UIImagePickerControllerMediaURL] as? URL {
            addClip(videoURL)
        }
        picker.presentingViewController?.dismiss(animated: false, completion: nil)

    }
    
}

