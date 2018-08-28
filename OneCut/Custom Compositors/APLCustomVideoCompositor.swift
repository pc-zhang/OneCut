/*
 Copyright (C) 2017 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Custom video compositor class implementing the AVVideoCompositing protocol.
 */

import Foundation
import AVFoundation
import CoreVideo
import UIKit

class APLCustomVideoCompositor: NSObject, AVVideoCompositing {

    /// Returns the pixel buffer attributes required by the video compositor for new buffers created for processing.
    var requiredPixelBufferAttributesForRenderContext: [String : Any] =
        [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]

    /// The pixel buffer attributes of pixel buffers that will be vended by the adaptor’s CVPixelBufferPool.
    var sourcePixelBufferAttributes: [String : Any]? =
        [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]

    /// Set if all pending requests have been cancelled.
    var shouldCancelAllRequests = false

    /// Dispatch Queue used to issue custom compositor rendering work requests.
    private var renderingQueue = DispatchQueue(label: "com.apple.aplcustomvideocompositor.renderingqueue")
    /// Dispatch Queue used to synchronize notifications that the composition will switch to a different render context.
    private var renderContextQueue = DispatchQueue(label: "com.apple.aplcustomvideocompositor.rendercontextqueue")

    /// The current render context within which the custom compositor will render new output pixels buffers.
    private var renderContext: AVVideoCompositionRenderContext?

    /// Maintain the state of render context changes.
    private var internalRenderContextDidChange = false
    /// Actual state of render context changes.
    private var renderContextDidChange: Bool {
        get {
            return renderContextQueue.sync { internalRenderContextDidChange }
        }
        set (newRenderContextDidChange) {
            renderContextQueue.sync { internalRenderContextDidChange = newRenderContextDidChange }
        }
    }

    
    override init() {
        super.init()
    }

    // MARK: AVVideoCompositing protocol functions

    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {
        renderContextQueue.sync { renderContext = newRenderContext }
        renderContextDidChange = true
    }

    enum PixelBufferRequestError: Error {
        case newRenderedPixelBufferForRequestFailure
    }
    
    let timeRemainingFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.zeroFormattingBehavior = .pad
        formatter.allowedUnits = [.minute, .second]
        
        return formatter
    }()
    
    private func createTimeString(time: Double) -> String {
        let components = NSDateComponents()
        components.second = Int(max(0.0, time))
        
        return timeRemainingFormatter.string(from: components as DateComponents)!
    }

    func startRequest(_ asyncVideoCompositionRequest: AVAsynchronousVideoCompositionRequest) {

        autoreleasepool {
            renderingQueue.async {
                // Check if all pending requests have been cancelled.
                if self.shouldCancelAllRequests {
                    asyncVideoCompositionRequest.finishCancelledRequest()
                } else {

                    guard let resultPixels =
                        self.newRenderedPixelBufferForRequest(asyncVideoCompositionRequest) else {
                            asyncVideoCompositionRequest.finish(with: PixelBufferRequestError.newRenderedPixelBufferForRequestFailure)
                            return
                    }
                    
                    // The resulting pixelbuffer from Metal renderer is passed along to the request.
                    asyncVideoCompositionRequest.finish(withComposedVideoFrame: resultPixels)
                }
            }
        }
    }

    func cancelAllPendingVideoCompositionRequests() {

        /*
         Pending requests will call finishCancelledRequest, those already rendering will call
         finishWithComposedVideoFrame.
         */
        renderingQueue.sync { shouldCancelAllRequests = true }
        renderingQueue.async {
            // Start accepting requests again.
            self.shouldCancelAllRequests = false
        }
    }

    // MARK: Utilities

    func factorForTimeInRange( _ time: CMTime, range: CMTimeRange) -> Float64 { /* 0.0 -> 1.0 */

        let elapsed = CMTimeSubtract(time, range.start)

        return CMTimeGetSeconds(elapsed) / CMTimeGetSeconds(range.duration)
    }

    func newRenderedPixelBufferForRequest(_ request: AVAsynchronousVideoCompositionRequest) -> CVPixelBuffer? {

        /*
         tweenFactor indicates how far within that timeRange are we rendering this frame. This is normalized to vary
         between 0.0 and 1.0. 0.0 indicates the time at first frame in that videoComposition timeRange. 1.0 indicates
         the time at last frame in that videoComposition timeRange.
         */
        let tweenFactor =
            factorForTimeInRange(request.compositionTime, range: request.videoCompositionInstruction.timeRange)

        guard let currentInstruction =
            request.videoCompositionInstruction as? APLCustomVideoCompositionInstruction else {
            return nil
        }

        // Source pixel buffers are used as inputs while rendering the transition.
        guard let foregroundSourceBuffer = request.sourceFrame(byTrackID: currentInstruction.foregroundTrackID) else {
            return nil
        }
        guard let backgroundSourceBuffer = request.sourceFrame(byTrackID: currentInstruction.backgroundTrackID) else {
            return nil
        }

        // Destination pixel buffer into which we render the output.
        guard let dstPixels = renderContext?.newPixelBuffer() else { return nil }

        if renderContextDidChange { renderContextDidChange = false }

        if true {
            // lock the buffer, create a new context and draw the watermark image
            CVPixelBufferLockBaseAddress(dstPixels, CVPixelBufferLockFlags.readOnly)
            var bitmapInfo  = CGBitmapInfo.byteOrder32Little.rawValue
            bitmapInfo |= CGImageAlphaInfo.premultipliedFirst.rawValue & CGBitmapInfo.alphaInfoMask.rawValue
            let newContext = CGContext.init(data: CVPixelBufferGetBaseAddress(dstPixels), width: 540, height: 960, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(dstPixels), space: CGColorSpaceCreateDeviceRGB(), bitmapInfo:bitmapInfo)
            
            if true {
                let foregroundImage = CIImage(cvPixelBuffer: foregroundSourceBuffer)
                let temporaryContext = CIContext(options: nil)
                let videoImage = temporaryContext.createCGImage(foregroundImage, from: CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(foregroundSourceBuffer), height: CVPixelBufferGetHeight(foregroundSourceBuffer)))
                
                newContext?.draw(videoImage!, in: CGRect(origin: .zero, size: CGSize(width: newContext!.width, height: newContext!.height)))
            }
            
            if true {
                let backgroundImage = CIImage(cvPixelBuffer: backgroundSourceBuffer)
                let temporaryContext = CIContext(options: nil)
                let videoImage = temporaryContext.createCGImage(backgroundImage, from: CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(backgroundSourceBuffer), height: CVPixelBufferGetHeight(backgroundSourceBuffer)))
                
                let scale = CGFloat(newContext!.height)/3/CGFloat(videoImage!.height)
                
                newContext?.draw(videoImage!, in: CGRect(x: CGFloat(newContext!.width) - CGFloat(videoImage!.width)*scale - CGFloat(newContext!.width)/40, y: CGFloat(newContext!.height) - CGFloat(newContext!.height/3) - CGFloat(newContext!.height)/16, width: CGFloat(videoImage!.width)*scale, height: CGFloat(newContext!.height/3)))
            }
            
            let weixin = CALayer()
            weixin.contents = UIImage(named: "weixintop")!.cgImage!
            weixin.frame = CGRect(origin: .zero, size: CGSize(width: newContext!.width, height: newContext!.height))
            weixin.contentsGravity = "top"
            weixin.contentsScale = CGFloat(UIImage(named: "weixintop")!.cgImage!.width) / CGFloat(newContext!.width) * 1.1
            
            let weixinbottom = CALayer()
            weixinbottom.contents = UIImage(named: "weixinbottom")!.cgImage!
            weixinbottom.frame = CGRect(origin: .zero, size: CGSize(width: newContext!.width, height: newContext!.height))
            weixinbottom.contentsGravity = "bottom"
            weixinbottom.contentsScale = CGFloat(UIImage(named: "weixinbottom")!.cgImage!.width) / CGFloat(newContext!.width) * 1.2
            
            weixin.addSublayer(weixinbottom)
            
            let textLayer = CATextLayer()
            textLayer.string = self.createTimeString(time: 1000 + CMTimeGetSeconds(request.compositionTime))
            textLayer.foregroundColor = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
            textLayer.font = UIFont(name: "Helvetica", size: 36.0)
            
            textLayer.alignmentMode = kCAAlignmentCenter
            textLayer.frame.origin = .zero
            textLayer.frame.size = textLayer.preferredFrameSize()
            let textscale: CGFloat = (CGFloat(weixin.frame.width) / 7) / textLayer.frame.size.width
            textLayer.setAffineTransform(CGAffineTransform.identity.scaledBy(x: textscale, y: textscale).translatedBy(x: (CGFloat(weixin.frame.width) - textLayer.frame.size.width)/2/textscale, y: CGFloat(UIImage(named: "weixinbottom")!.cgImage!.height)/weixinbottom.contentsScale/textscale + 30))
            
            weixin.addSublayer(textLayer)
            
            weixin.isGeometryFlipped = true
            weixin.render(in: newContext!)
            
            //                        request.compositionTime
            CVPixelBufferUnlockBaseAddress(dstPixels, CVPixelBufferLockFlags.readOnly)
        }
        
        return dstPixels
    }
}

