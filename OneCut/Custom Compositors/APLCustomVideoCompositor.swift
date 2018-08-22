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

    /// Instance of `APLMetalRenderer` used to issue rendering commands to subclasses.
    private var metalRenderer: APLMetalRenderer? = nil
    
    override init() {
        super.init()
    }

    fileprivate init(metalRenderer: APLMetalRenderer) {
        self.metalRenderer = metalRenderer
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

        metalRenderer!.renderPixelBuffer(dstPixels, usingForegroundSourceBuffer:foregroundSourceBuffer,
                                        andBackgroundSourceBuffer:backgroundSourceBuffer,
                                        forTweenFactor:Float(tweenFactor))

        if true {
            // lock the buffer, create a new context and draw the watermark image
            CVPixelBufferLockBaseAddress(dstPixels, CVPixelBufferLockFlags.readOnly)
            var bitmapInfo  = CGBitmapInfo.byteOrder32Little.rawValue
            bitmapInfo |= CGImageAlphaInfo.premultipliedFirst.rawValue & CGBitmapInfo.alphaInfoMask.rawValue
            let newContext = CGContext.init(data: CVPixelBufferGetBaseAddress(dstPixels), width: CVPixelBufferGetWidth(dstPixels), height: CVPixelBufferGetHeight(dstPixels), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(dstPixels), space: CGColorSpaceCreateDeviceRGB(), bitmapInfo:bitmapInfo)
            
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
            textLayer.setAffineTransform(CGAffineTransform.identity.scaledBy(x: textscale, y: textscale).translatedBy(x: (CGFloat(weixin.frame.width) - textLayer.frame.size.width)/2/textscale, y: CGFloat(UIImage(named: "weixinbottom")!.cgImage!.height)/weixinbottom.contentsScale/textscale))
            
            weixin.addSublayer(textLayer)
            
            weixin.isGeometryFlipped = true
            weixin.render(in: newContext!)
            
            //                        request.compositionTime
            CVPixelBufferUnlockBaseAddress(dstPixels, CVPixelBufferLockFlags.readOnly)
        }
        
        return dstPixels
    }
}

class APLCrossDissolveCompositor: APLCustomVideoCompositor {

    override init() {
        let newRenderer = APLCrossDissolveRenderer()
        super.init(metalRenderer: newRenderer!)
    }
}

class APLDiagonalWipeCompositor: APLCustomVideoCompositor {

    override init() {
        let newRenderer = APLDiagonalWipeRenderer()
        super.init(metalRenderer: newRenderer!)
    }
}

