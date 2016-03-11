//
//  CameraVC.swift
//  Talnts
//
//  Created by Mikhail Stepkin on 03.08.15.
//  Copyright (c) 2015 Ramotion. All rights reserved.
//

import UIKit
import AVFoundation

import Runes
import JPSVolumeButtonHandler

public class CameraVC: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureFileOutputRecordingDelegate, ImageSource, VideoSource {
    
    static var authorizationStatus: AVAuthorizationStatus {
        let status = AVCaptureDevice.authorizationStatusForMediaType(AVMediaTypeVideo)
        
        return status
    }
    
    static func requestAuthorization(closure: Bool -> Void) {
        AVCaptureDevice.requestAccessForMediaType(AVMediaTypeVideo) { success in
            async(.Main) {
                closure(success)
            }
        }
    }
    
    @IBOutlet var cameraPreviewView: CameraPreview!
    
    @IBOutlet var shootButton : UIButton!
    @IBOutlet var lightButton : UIButton!
    @IBOutlet var switchButton: UIButton!
    
    @IBOutlet var recordButton: RecordButton!
    @IBOutlet var timerIndicator: UILabel!
    
    public var onImageReady: (UIImage -> Void)?
    public var onVideoReady: (AVURLAsset -> Void)?
    public var onClose: (() -> Void)?
    
    public enum CameraType {
        case Photo
        case Video
    }
    private(set) internal var cameraType: CameraType = .Photo
    
    public init(cameraType: CameraType) {
        let bundle = NSBundle(forClass: self.dynamicType)
        super.init(nibName: "CameraVC", bundle: bundle)
        
        self.cameraType = cameraType
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        setupButtons()
    }
    
    private var cameraPosition:AVCaptureDevicePosition = .Back {
        didSet {
            self.updateInput {[weak self, cameraType = self.cameraType] device in
                if let `self` = self {
                    let supported: Bool
                    switch cameraType {
                    case .Photo:
                        supported = device.isFlashModeSupported(self.flashMode)
                    case .Video:
                        supported = device.isTorchModeSupported(self.torchMode)
                    }
                    
                    if supported {
                        self.lightButton.hidden = !supported
                    }
                    else {
                        self.lightButton.hidden = true
                    }
                }
            }
        }
    }
    
    private var flashMode:AVCaptureFlashMode = .Auto {
        didSet {
            if
                let device = self.device
                where device.isFlashModeSupported(self.flashMode)
            {
                do {
                    try device.lockForConfiguration()
                    device.flashMode = self.flashMode
                    device.unlockForConfiguration()
                }
                catch (let error) {
                    print(error)
                }
            }
        }
    }
    
    private var torchMode: AVCaptureTorchMode = .Auto {
        didSet {
            if
                let device = self.device
                where device.isTorchModeSupported(self.torchMode)
            {
                do {
                    try device.lockForConfiguration()
                    device.torchMode = self.torchMode
                    device.unlockForConfiguration()
                }
                catch (let error) {
                    print(error)
                }
            }
        }
    }
    
    @objc
    func updateFlashAndTorch() {
        switch cameraType {
        case .Video:
            let torchMode = self.torchMode
            self.torchMode = torchMode
            
        case .Photo:
            let flashMode = self.flashMode
            self.flashMode = flashMode
        }
    }
    
    private var volumeHandler: JPSVolumeButtonHandler?
    private var flashObserver: NSObjectProtocol?
    override public func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        UIDevice.currentDevice().beginGeneratingDeviceOrientationNotifications()
        
        setupSession()
        
        switch cameraType {
        case .Video:
            self.torchMode = .Auto
            self.flashMode = .Off
        case .Photo:
            self.torchMode = .Off
            self.flashMode = .Auto
        }
        
        self.updateLightButtonText()
        
        self.cameraPosition = .Back
        
        switch cameraType {
        case .Photo:
            self.timerIndicator.hidden = true
            self.recordButton.hidden   = true
        case .Video:
            self.timePassed = 0.0
            self.shootButton.hidden  = true
        }
        
        //        let title = cameraType == .Photo ? "Take Photo" : "Take Video"
        //        navigationController?.topViewController?.navigationItem.title = title
        //        navigationController?.topViewController?.navigationItem.rightBarButtonItem = nil
        //        navigationController?.setNavigationBarHidden(false, animated: animated)
        //        navigationController?.navigationBarType = NavigationBarType.BlackFlat(height:44)
        
        setupBackButton()
    }
    
    override public func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        flashObserver = NSNotificationCenter.defaultCenter().addObserverForName(AVCaptureSessionDidStartRunningNotification, object: nil, queue: nil) { notif -> Void in self.updateFlashAndTorch()
        }
        
        if self.cameraType == .Photo {
            self.volumeHandler = JPSVolumeButtonHandler(
                upBlock: { [weak self] in
                    self?.takePicture()
                },
                downBlock: { [weak self] in
                    self?.takePicture()
                }
            )
        }
    }
    
    override public func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        UIDevice.currentDevice().endGeneratingDeviceOrientationNotifications()
        
        session.synced {
            if session.running {
                session.stopRunning()
            }
        }
        
        self.volumeHandler = nil
        NSNotificationCenter.defaultCenter().removeObserver <^> flashObserver
    }
    
    private let session = AVCaptureSession()
    private var output:AVCaptureOutput?
    private weak var device: AVCaptureDevice?
    private func setupSession() {
        self.updateInput { [weak self, cameraType = self.cameraType, session = self.session] _ in
            if let `self` = self {
                
                let output: AVCaptureOutput
                switch cameraType {
                case .Photo:
                    output = AVCaptureStillImageOutput()
                    (output as! AVCaptureStillImageOutput).outputSettings = [kCVPixelBufferPixelFormatTypeKey: NSNumber(unsignedInt: kCVPixelFormatType_32BGRA)]
                case .Video:
                    output = AVCaptureMovieFileOutput()
                }
                
                if
                    let outputs = ({Set($0)}) <^> (session.outputs as? [AVCaptureOutput])
                    where !outputs.contains(output) && session.canAddOutput(output)
                {
                    session.addOutput(output)
                    self.output = output
                }
                
                session.synced {
                    if !session.running {
                        session.startRunning()
                        self.cameraPreviewView.initPreview(session, cameraType: self.cameraType)
                    }
                }
            }
        }
    }
    
    private func updateInput(completion: (device: AVCaptureDevice) -> Void) {
        async(.Main) { [weak self, cameraType = self.cameraType, session = self.session] in
            if let `self` = self {
                do {
                    if
                        let devices = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo) as? [AVCaptureDevice],
                        let device  = devices.filter({$0.position == self.cameraPosition}).first
                        where self.device != device
                    {
                        let videoInput = try AVCaptureDeviceInput(device: device)
                        session.synced {
                            let inputs = session.inputs as! [AVCaptureInput]
                            inputs.forEach { (input: AVCaptureInput) -> Void in
                                self.session.removeInput(input)
                            }
                            
                            if
                                let inputs = ({Set($0)}) <^> (session.inputs as? [AVCaptureInput])
                                where !inputs.contains(videoInput) && session.canAddInput(videoInput)
                            {
                                session.addInput(videoInput)
                                self.device = device
                                async(.Main) {
                                    completion <^> self.device
                                }
                            }
                        }
                        
                        if cameraType == .Video {
                            AVAudioSession.sharedInstance().requestRecordPermission({ granted -> Void in
                                if granted {
                                    async(.Main) {
                                        do {
                                            if let audioDevice = AVCaptureDevice.devicesWithMediaType(AVMediaTypeAudio).first as? AVCaptureDevice
                                            {
                                                let audioInput  = try AVCaptureDeviceInput(device: audioDevice)
                                                if
                                                    let inputs = ({Set($0)}) <^> (session.inputs as? [AVCaptureInput])
                                                    where !inputs.contains(audioInput) && session.canAddInput(audioInput)
                                                {
                                                    session.addInput(audioInput)
                                                }
                                            }
                                        }
                                        catch (let error) {
                                            print(error)
                                        }
                                    }
                                }
                                //                                else {
                                //                                    alert("Please enable microphone access in the app privacy settings if you want to capture video with sound.")
                                //                                }
                            })
                        }
                        
                        switch cameraType {
                        case .Photo:
                            if session.canSetSessionPreset(AVCaptureSessionPresetPhoto) {
                                session.sessionPreset = AVCaptureSessionPresetPhoto
                            }
                        case .Video:
                            if session.canSetSessionPreset(AVCaptureSessionPresetHigh) {
                                session.sessionPreset = AVCaptureSessionPresetHigh
                            }
                        }
                    }
                    else {
                        async(.Main) {
                            completion <^> self.device
                        }
                    }
                }
                catch (let error) {
                    print(error)
                }
            }
        }
    }
    
    private func setupButtons() {
        
        ignite(recordButton).listen(self) { [weak self] in
            self?.record()
        }
        
        shootButton.onTouchDown.listen(self) { [weak self] in
            self?.takePicture()
        }
        
        switchButton.onTouchDown.listen(self) {
            if self.cameraType == .Video {
                if let output = self.output as? AVCaptureMovieFileOutput where output.recording {
                    return
                }
            }
            
            UIView.transitionWithView(self.cameraPreviewView, duration: 0.6, options: [.BeginFromCurrentState, .TransitionFlipFromLeft, .CurveEaseInOut], animations: { [weak self] () -> Void in
                if let `self` = self {
                    syncWith(self.session) {
                        self.session.stopRunning()
                        self.cameraPosition.flip()
                        self.cameraPreviewView.updateFrames()
                        self.cameraPreviewView.transform = CGAffineTransformMakeScale(0.9, 0.9)
                    }
                }
                }, completion: { [weak self] (f) -> Void in
                    if let `self` = self {
                        syncWith(self.session) {
                            self.cameraPreviewView.transform = CGAffineTransformIdentity
                            self.session.startRunning()
                        }
                    }
                })
        }
        
        lightButton.onTouchDown.listen(self) {
            switch self.cameraType {
            case .Photo:
                self.flashMode.flip()
            case .Video:
                self.torchMode.flip()
            }
            
            self.updateLightButtonText()
        }
    }
    
    func updateLightButtonText() {
        switch self.cameraType {
        case .Video:
            
            switch self.torchMode {
            case .Auto:
                self.lightButton.setTitle("Auto", forState: .Normal)
            case .Off:
                self.lightButton.setTitle("Off", forState: .Normal)
            case .On:
                self.lightButton.setTitle("On", forState: .Normal)
            }
            
        case .Photo:
            switch self.flashMode {
            case .Auto:
                self.lightButton.setTitle("Auto", forState: .Normal)
            case .Off:
                self.lightButton.setTitle("Off", forState: .Normal)
            case .On:
                self.lightButton.setTitle("On", forState: .Normal)
            }
        }
    }
    
    private func takePicture() {
        if self.device == nil {
            return
        }
        
        print("takePicture")
        
        session.synced {
            if session.sessionPreset != AVCaptureSessionPresetPhoto && session.canSetSessionPreset(AVCaptureSessionPresetPhoto) {
                session.sessionPreset = AVCaptureSessionPresetPhoto
            }
        }
        
        if
            let output = self.output as? AVCaptureStillImageOutput,
            let connection = output.connectionWithMediaType(AVMediaTypeVideo)
            where !output.capturingStillImage
        {
            asyncWith(connection, priority: .High) { [weak self] in
                output.captureStillImageAsynchronouslyFromConnection(connection) { [weak self] (b, e) -> Void in
                    if
                        let `self` = self,
                        let buffer = b,
                        let image  = UIImage.imageFromSampleBuffer(
                            buffer,
                            cameraPosition:self.cameraPosition,
                            orientation: AVCaptureVideoOrientation.captureDeviceOrientation() ?? .Portrait
                        )
                    {
                        print(AVCaptureVideoOrientation.captureDeviceOrientation())
                        //                        image.preview { imageBox in
                        //                            if let navigationController = self.navigationController as? NavigationController {
                        //                                navigationController.showCropView <^> imageBox.value
                        //                            }
                        //                        }
                        
                        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                    }
                    else {
                        { e in print(e) } <^> e
                    }
                }
            }
        }
    }
    
    private var timer: NSTimer?
    @objc(updateOnTimer:)
    private func updateOnTimer(timer: NSTimer) {
        timePassed += timer.timeInterval
        
        let percentage = CGFloat(timePassed/maxTime)
        
        Animate(duration: timer.timeInterval, options: UIViewAnimationOptions.CurveEaseInOut)
            .animation {
                self.recordButton.progress = percentage * 100
            }
            .fire()
        
        if let output = self.output as? AVCaptureMovieFileOutput {
            syncWith(output) { [weak self] in
                if
                    let timePassed = self?.timePassed,
                    let maxTime    = self?.maxTime
                    where timePassed >= maxTime
                {
                    timer.invalidate()
                    self?.stopRecording(output)
                }
            }
        }
    }
    
    private let timeFormatter: NSDateFormatter = {
        let timeFormatter = NSDateFormatter()
        timeFormatter.timeZone = NSTimeZone(forSecondsFromGMT: 0)
        timeFormatter.dateFormat = "mm:ss"
        return timeFormatter
    }()
    
    private let maxTime: NSTimeInterval    = 30.0
    private var timePassed: NSTimeInterval =  0.0 {
        didSet {
            timerIndicator.text = timeFormatter.stringFromDate(NSDate(timeIntervalSinceReferenceDate: timePassed))
        }
    }
    
    private func record() {
        if self.device == nil {
            return
        }
        
        if let output = self.output as? AVCaptureMovieFileOutput {
            if output.recording {
                stopRecording(output)
            }
            else {
                startRecording(output)
            }
        }
    }
    
    private func startRecording(output: AVCaptureMovieFileOutput) {
        syncWith(output) { [weak self] in
            if let `self` = self {
                guard self.device != nil else {
                    return
                }
                
                let (hash, timestamp) = generateHash(self.session)
                let tempDir = NSURL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                let url     = tempDir.URLByAppendingPathComponent("\(hash)\(timestamp).mov")
                
                let session = self.session
                
                session.synced {
                    print("startRecording")
                    
                    if session.sessionPreset != AVCaptureSessionPresetHigh && session.canSetSessionPreset(AVCaptureSessionPresetHigh) {
                        session.sessionPreset = AVCaptureSessionPresetHigh
                    }
                    
                    if let connection = output.connectionWithMediaType(AVMediaTypeVideo)
                        where connection.supportsVideoOrientation
                    {
                        if let videoOrientation = AVCaptureVideoOrientation.captureDeviceOrientation() {
                            connection.videoOrientation = videoOrientation
                        }
                    }
                    
                    output.startRecordingToOutputFileURL(url, recordingDelegate: self)
                }
            }
        }
    }
    
    private func stopRecording(output: AVCaptureMovieFileOutput) {
        syncWith(output) {
            print("stopRecording")
            output.stopRecording()
        }
    }
    
    private func setupBackButton() {
        
        let backImage = UIImage(named:"close-icon")
        let img = UIImageView(image: backImage)
        
        img.frame.size.width = img.frame.size.width
        img.frame.size.height = img.frame.size.height
        
        let btn = UIButton(type: UIButtonType.System)
        btn.frame = img.frame
        btn.setImage(backImage, forState: UIControlState.Normal)
        btn.setTitleColor(UIColor.whiteColor(), forState: UIControlState.Normal)
        btn.onTouchDown.listen(self, callback: back)
        
        navigationController?.topViewController?.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: btn)
    }
    
    func back() {
        self.onClose?()
    }
    
    public func captureOutput(captureOutput: AVCaptureFileOutput!, didStartRecordingToOutputFileAtURL fileURL: NSURL!, fromConnections connections: [AnyObject]!) {
        timePassed = 0.0
        timer = NSTimer.scheduledTimerWithTimeInterval(0.1, target: self, selector: Selector("updateOnTimer:"), userInfo: nil, repeats: true)
        recordButton.recording = true
    }
    
    public func captureOutput(captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAtURL outputFileURL: NSURL!, fromConnections connections: [AnyObject]!, error: NSError!) {
        timer?.invalidate()
        timer = nil
        recordButton.recording = false
        self.timePassed = 0.0
        
        if let error = error {
            print(error)
            //            alert(error.localizedRecoverySuggestion ?? error.localizedDescription)
        } else {
            UISaveVideoAtPathToSavedPhotosAlbum(outputFileURL.path!, nil, nil, nil)
            
            //            let videoVC = VideoCropViewController(videoURL: outputFileURL)
            //            videoVC.onVideoReady = { [weak self] asset -> Void in
            //                if let `self` = self {
            //                    self.navigationController?.popViewControllerAnimated(false)
            //                    self.onVideoReady?(asset)
            //                }
            //            }
            //            videoVC.onClose = {
            //                self.navigationController?.popViewControllerAnimated(true)
            //            }
            //            self.navigationController?.pushViewController(videoVC, animated: true)
        }
    }
    
}

class CameraPreview: UIView {
    
    private var cameraType: CameraVC.CameraType = .Photo
    private var previewLayer: AVCaptureVideoPreviewLayer?
    func initPreview(session: AVCaptureSession, cameraType: CameraVC.CameraType) {
        guard previewLayer?.session != session else {
            return
        }
        
        async(.Main) {
            self.cameraType = cameraType
            self.previewLayer?.removeFromSuperlayer()
            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
            
            self.layer.insertSublayer(previewLayer, atIndex: 0)
            self.previewLayer = previewLayer
            
            self.updateFrames()
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        updateFrames()
    }
    
    private func updateFrames() {
        if let previewLayer = previewLayer {
            switch cameraType {
            case .Photo:
                previewLayer.position = CGPointZero
                previewLayer.frame = self.layer.bounds
            case .Video:
                var rect = self.layer.bounds
                rect.origin.y = 48
                rect.size.height = rect.size.width
                previewLayer.frame = rect
            }
        }
    }
    
}

func |(lhs: CGBitmapInfo, rhs: CGImageAlphaInfo) -> CGBitmapInfo {
    return lhs.union(CGBitmapInfo(rawValue: rhs.rawValue))
}

func |(lhs: CGImageAlphaInfo, rhs: CGBitmapInfo) -> CGBitmapInfo {
    return CGBitmapInfo(rawValue: lhs.rawValue).union(rhs)
}

protocol Flippable {
    
    mutating func flip() -> Self
    
}

extension AVCaptureDevicePosition: Flippable {
    
    mutating func flip() -> AVCaptureDevicePosition {
        switch self {
        case .Back:
            self = .Front
        case .Front:
            self = .Back
        case .Unspecified:
            break
        }
        return self
    }
    
}

extension AVCaptureTorchMode: Flippable {
    
    mutating func flip() -> AVCaptureTorchMode {
        switch self {
        case .Auto:
            self = .On
        case .On:
            self = .Off
        case .Off:
            self = .Auto
        }
        return self
    }
    
}

extension AVCaptureFlashMode: Flippable {
    
    mutating func flip() -> AVCaptureFlashMode {
        switch self {
        case .Auto:
            self = .On
        case .On:
            self = .Off
        case .Off:
            self = .Auto
        }
        return self
    }
    
}

extension UIImage {
    
    static func imageFromSampleBuffer(sampleBuffer: CMSampleBufferRef, cameraPosition: AVCaptureDevicePosition, orientation: AVCaptureVideoOrientation) -> UIImage? {
        if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            
            CVPixelBufferLockBaseAddress(imageBuffer, 0)
            
            let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer)
            let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
            let width  = CVPixelBufferGetWidth(imageBuffer)
            let height = CVPixelBufferGetHeight(imageBuffer)
            
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            
            let context = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, CGBitmapInfo.ByteOrder32Little.rawValue | CGImageAlphaInfo.PremultipliedFirst.rawValue)
            CGContextRotateCTM(context, CGFloat(-M_PI))
            if let quartzImage = CGBitmapContextCreateImage(context) {
                CVPixelBufferUnlockBaseAddress(imageBuffer, 0)
                
                let image = UIImage(CGImage: quartzImage)
                
                let angle: Double
                switch orientation {
                case .Portrait:
                    angle = M_PI_2
                case .PortraitUpsideDown:
                    angle = -M_PI_2
                case .LandscapeRight:
                    angle = 0
                case .LandscapeLeft:
                    angle = M_PI
                }
                
                let radians = CGFloat(angle)
                
                return image.rotatedBy(radians, mirrored: cameraPosition == .Front)
            }
            else {
                return nil
            }
        }
        else {
            return nil
        }
    }
    
    func rotatedBy(radians: CGFloat, mirrored: Bool = false) -> UIImage? {
        let rotatedViewBox = UIView(frame: CGRectMake(0, 0, self.size.width, self.size.height))
        let t = CGAffineTransformMakeRotation(radians)
        rotatedViewBox.transform = t
        let rotatedSize = rotatedViewBox.frame.size
        
        UIGraphicsBeginImageContext(rotatedSize)
        let bitmap = UIGraphicsGetCurrentContext()
        
        CGContextTranslateCTM(bitmap, rotatedSize.width/2, rotatedSize.height/2)
        CGContextRotateCTM(bitmap, radians)
        
        CGContextScaleCTM(bitmap, 1.0, mirrored ? 1.0 : -1.0)
        CGContextDrawImage(bitmap, CGRectMake(-self.size.width / 2, -self.size.height / 2, self.size.width, self.size.height), self.CGImage)
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return image
    }
    
}

extension AVCaptureVideoOrientation {
    
    static func captureDeviceOrientation() -> AVCaptureVideoOrientation? {
        let orientation = UIDevice.currentDevice().orientation
        let videoOrientation: AVCaptureVideoOrientation?
        switch orientation {
        case .Portrait:
            videoOrientation = .Portrait
        case .PortraitUpsideDown:
            videoOrientation = .PortraitUpsideDown
        case .LandscapeLeft:
            videoOrientation = .LandscapeRight
        case .LandscapeRight:
            videoOrientation = .LandscapeLeft
        default:
            videoOrientation = nil
        }
        
        return videoOrientation
    }
    
}

extension AVCaptureVideoOrientation: CustomStringConvertible {
    
    public var description: String {
        switch self {
        case .Portrait:
            return "Portrait"
        case .PortraitUpsideDown:
            return "PortraitUpsideDown"
        case .LandscapeLeft:
            return "LandscapeLeft"
        case .LandscapeRight:
            return "LandscapeRight"
        }
    }
    
}

extension UIDeviceOrientation: CustomStringConvertible {
    
    public var description: String {
        switch self {
        case .Portrait:
            return "Portrait"
        case .PortraitUpsideDown:
            return "PortraitUpsideDown"
        case .LandscapeLeft:
            return "LandscapeLeft"
        case .LandscapeRight:
            return "LandscapeRight"
        case .FaceUp:
            return "FaceUp"
        case .FaceDown:
            return "FaceDown"
        case .Unknown:
            return "Unknown"
        }
    }
    
}
