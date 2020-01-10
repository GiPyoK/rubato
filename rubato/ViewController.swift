//
//  ViewController.swift
//  rubato
//
//  Created by Gi Pyo Kim on 12/30/19.
//  Copyright © 2019 GIPGIP Studio. All rights reserved.
//

import UIKit
import MobileCoreServices
import AVFoundation
import MediaPlayer
import StoreKit
import FDWaveformView

class ViewController: UIViewController {

    // video outlet
    @IBOutlet weak var videoView: UIView!
    @IBOutlet weak var videoMarkerView: UIView!
    @IBOutlet weak var videoSlider: UISlider!
    @IBOutlet weak var videoMarkerCount: UILabel!
    @IBOutlet weak var videoTimeElapsedLabel: UILabel!
    @IBOutlet weak var videoTimeRemainingLabel: UILabel!
    
    // audio outlet
    @IBOutlet weak var audioView: UIView!
    @IBOutlet weak var audioMarkerView: UIView!
    @IBOutlet weak var audioMarkerCount: UILabel!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var audioTimeElapsedLabel: UILabel!
    @IBOutlet weak var audioTimeRemainingLabel: UILabel!
    
    // video
    var videoPlayer: AVPlayer?
    var playerLayer: AVPlayerLayer?
    var videoURL: URL? {
        didSet {
            playerLayer?.removeFromSuperlayer()
            videoPlayer = AVPlayer(url: videoURL!)
            playerLayer = AVPlayerLayer(player: videoPlayer)
            playerLayer!.frame = videoView.bounds
            playerLayer!.videoGravity = .resizeAspect
            videoView.layer.insertSublayer(playerLayer!, at: 0)
            if let item = videoPlayer?.currentItem {
                videoAsset = item.asset
            }
        }
    }
    var videoAsset: AVAsset? {
        didSet {
            videoSlider.minimumValue = 0
            videoSlider.maximumValue = Float(CMTimeGetSeconds(videoAsset!.duration))
            videoSlider.value = 0
            
            timescale = videoAsset!.duration.timescale
        }
    }
    var isSeekInProgress = false
    var chaseTime = CMTime.zero
    var playerCurrentItemStatus:AVPlayerItem.Status = .unknown
    var timescale: CMTimeScale?
    
    // audio
    var waveform = FDWaveformView()
    var audioPlayer: AVAudioPlayer?
    var timer: Timer?
    var isPlaying: Bool {
        return audioPlayer?.isPlaying ?? false
    }
    
    // marker
    var videoMarkers: [Marker] = []
    var audioMarkers: [Marker] = []
    
    private lazy var timeFormatter: DateComponentsFormatter = {
        let formatting = DateComponentsFormatter()
        formatting.unitsStyle = .positional
        formatting.zeroFormattingBehavior = .pad
        formatting.allowedUnits = [.minute, .second]
        return formatting
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapGuesture(_:)))
        view.addGestureRecognizer(tapGesture)
        
        // audio waveform
        guard let url = Bundle.main.url(forResource: "Dubstep2", withExtension: "mp3") else { return }
        waveform.audioURL = url
        waveform.delegate = self
        waveform.doesAllowScroll = false
        waveform.doesAllowStretch = false
        waveform.doesAllowScrubbing = true
        waveform.wavesColor = UIColor.systemGray
        waveform.progressColor = UIColor.systemBlue
        view.addSubview(waveform)
        waveform.translatesAutoresizingMaskIntoConstraints = false
        waveform.topAnchor.constraint(equalTo: audioView.topAnchor).isActive = true
        waveform.leadingAnchor.constraint(equalTo: audioView.leadingAnchor).isActive = true
        waveform.trailingAnchor.constraint(equalTo: audioView.trailingAnchor).isActive = true
        waveform.heightAnchor.constraint(equalTo: audioView.heightAnchor).isActive = true
        
        // audio play
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
        } catch {
            print("Error initializing AVAudioPlayer \(error)")
        }
        audioTimeElapsedLabel.font = UIFont.monospacedDigitSystemFont(ofSize: audioTimeElapsedLabel.font.pointSize, weight: .regular)
        audioTimeRemainingLabel.font = UIFont.monospacedDigitSystemFont(ofSize: audioTimeRemainingLabel.font.pointSize, weight: .regular)

        audioPlayer?.delegate = self
        
        // video play
        videoTimeElapsedLabel.font = UIFont.monospacedDigitSystemFont(ofSize: videoTimeElapsedLabel.font.pointSize, weight: .regular)
        videoTimeRemainingLabel.font = UIFont.monospacedDigitSystemFont(ofSize: videoTimeRemainingLabel.font.pointSize, weight: .regular)
        
        updateAudioViews()
        updateVideoViews()
    }
    
    private func updateVideoViews() {
        guard let videoAsset = videoAsset else {
            videoSlider.value = 0
            videoTimeElapsedLabel.text = timeFormatter.string(from: 0)
            videoTimeRemainingLabel.text = timeFormatter.string(from: 0)
            return
        }
        
        let sliderPercentage: Double = Double(videoSlider.value / videoSlider.maximumValue)
        let totalTime: TimeInterval = CMTimeGetSeconds(videoAsset.duration)
        let elapsedTime: TimeInterval = totalTime * sliderPercentage
        videoTimeElapsedLabel.text = timeFormatter.string(from: elapsedTime)
        videoTimeRemainingLabel.text = timeFormatter.string(from: totalTime - elapsedTime)
    }
    
    func stopPlayingAndSeekSmoothlyToTime(newChaseTime:CMTime) {
        if let player = videoPlayer {
            player.pause()
            if CMTimeCompare(newChaseTime, chaseTime) != 0 {
                chaseTime = newChaseTime;
                if !isSeekInProgress {
                    trySeekToChaseTime()
                }
            }
        }
    }
    
    func trySeekToChaseTime() {
        actuallySeekToTime()
    }
    
    func actuallySeekToTime() {
        if let player = videoPlayer {
            isSeekInProgress = true
            let seekTimeInProgress = chaseTime
            player.seek(to: seekTimeInProgress, toleranceBefore: CMTime.zero,
                        toleranceAfter: CMTime.zero, completionHandler:
                { (isFinished:Bool) -> Void in
                    
                    if CMTimeCompare(seekTimeInProgress, self.chaseTime) == 0 {
                        self.isSeekInProgress = false
                    } else {
                        self.trySeekToChaseTime()
                    }
            })
        }
    }
    
    private func updateAudioViews() {
        guard let audioPlayer = audioPlayer else { return }
        playButton.isSelected = isPlaying
        
        let elapsedTime = audioPlayer.currentTime
        audioTimeElapsedLabel.text = timeFormatter.string(from: elapsedTime)
        
        let totalTime = audioPlayer.duration
        var endIndex: Int = 0
        if !totalTime.isZero {
            endIndex = Int(Double(elapsedTime) / Double(audioPlayer.duration) * Double(waveform.totalSamples))
        }
        waveform.highlightedSamples = 0..<endIndex
        audioTimeRemainingLabel.text = timeFormatter.string(from: totalTime - elapsedTime)
        
        if isPlaying {
            playButton.isSelected = true
        } else {
            playButton.isSelected = false
        }
    }
    
    private func playPauseAudio() {
        if isPlaying {
            audioPlayer?.pause()
            cancelTimer()
            updateAudioViews()
        } else {
            audioPlayer?.play()
            startTimer()
            updateAudioViews()
        }
    }
    
    private func startTimer() {
        cancelTimer()
        timer = Timer.scheduledTimer(timeInterval: 0.03, target: self, selector: #selector(updateTimer(timer:)), userInfo: nil, repeats: true)
    }
    
    private func cancelTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    @objc private func updateTimer(timer: Timer) {
        updateAudioViews()
    }

    private func presentVideoPickerController() {
        if UIImagePickerController.isSourceTypeAvailable(UIImagePickerController.SourceType.photoLibrary){
            DispatchQueue.main.async {
                let videoPicker = UIImagePickerController()
                videoPicker.sourceType = .photoLibrary
                videoPicker.mediaTypes = UIImagePickerController.availableMediaTypes(for: .photoLibrary)!
                videoPicker.mediaTypes = [kUTTypeMovie as String]
                videoPicker.allowsEditing = true
                videoPicker.delegate = self
                self.present(videoPicker, animated: true, completion: nil)
            }
        } else {
            // TODO: self.presentInformationalAlertController(title: "Error", message: "The photo library or the camera is unavailable.")
        }
    }
    
    private func presentAudioPickerController() {
        DispatchQueue.main.async {
            let mediaPickerController = MPMediaPickerController(mediaTypes: .any)
            mediaPickerController.delegate = self
            mediaPickerController.prompt = "Select Audio"
            self.present(mediaPickerController, animated: true, completion: nil)
        }
    }
    
    private func getAuthorizationForAppleMusic() {
        let authorizationStatus:MPMediaLibraryAuthorizationStatus = MPMediaLibrary.authorizationStatus()
        
        switch authorizationStatus {
        case MPMediaLibraryAuthorizationStatus.authorized:
            presentAudioPickerController()
            break
        case MPMediaLibraryAuthorizationStatus.notDetermined:
            MPMediaLibrary.requestAuthorization { (authorizationStatus) in
                if authorizationStatus == MPMediaLibraryAuthorizationStatus.authorized {
                    self.presentAudioPickerController()
                } else {
                    print("The Media Library was not authorized by the user")
                }
            }
        default:
            break
        }
    }
    
    private func applyEffects() {
        
        guard let videoAsset = videoAsset, let timescale = timescale, let audioPlayer = audioPlayer else { return }
        let totalDuration = videoAsset.duration
        let mixComp = AVMutableComposition()
        let videoAssetSourceTrack = videoAsset.tracks(withMediaType: AVMediaType.video).first! as AVAssetTrack
        guard let track = mixComp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            print("Error while adding mutable track to composition")
            return
        }

        do {
            try track.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: videoAsset.duration), of: videoAssetSourceTrack, at: CMTime.zero)
        } catch {
            print("Error inserting time range: \(error)")
            return
        }
        
        if !videoMarkers.isEmpty && !audioMarkers.isEmpty && videoMarkers.count == audioMarkers.count {
            videoMarkers.sort{$0.position < $1.position}
            audioMarkers.sort{$0.position < $1.position}
            
            var start = CMTime.zero
            var index = 0
            var endTime = CMTimeMake(value: Int64(videoMarkers[index].position * Float64(totalDuration.value)), timescale: timescale)
            var finalDuration = Float64(audioMarkers[index].position * audioPlayer.duration)
            start = fastToSlow(track: track, startTime: start, endTime: endTime, finalDuration: finalDuration, timescale: timescale)
            //start = CMTimeAdd(start, CMTimeMakeWithSeconds(finalDuration, preferredTimescale: timescale))
            index += 1
            while index < videoMarkers.count {
                print("applyEffects() while loop")
                let timeDiff = CMTimeSubtract(CMTimeMake(value: Int64(videoMarkers[index].position * Float64(totalDuration.value)), timescale: timescale), endTime)
                endTime = CMTimeMakeWithSeconds(CMTimeGetSeconds(timeDiff) / 2.0 + CMTimeGetSeconds(endTime), preferredTimescale: timescale)
                let durationDiff = Float64(audioMarkers[index].position * audioPlayer.duration) - finalDuration
                finalDuration = durationDiff / 2.0
                
                start = slowToFast(track: track, startTime: start, endTime: endTime, finalDuration: finalDuration, timescale: timescale)
                
                //start = CMTimeAdd(start, CMTimeMakeWithSeconds(finalDuration, preferredTimescale: timescale))
                endTime = CMTimeMake(value: Int64(videoMarkers[index].position * Float64(totalDuration.value)), timescale: timescale)
                
                start = fastToSlow(track: track, startTime: start, endTime: endTime, finalDuration: finalDuration, timescale: timescale)
                
                index += 1
            }
            start = slowToFast(track: track, startTime: start, endTime: totalDuration, finalDuration: CMTimeGetSeconds(totalDuration) - finalDuration, timescale: timescale)

            track.preferredTransform = videoAssetSourceTrack.preferredTransform
        }
        
        playerLayer?.removeFromSuperlayer()
        videoPlayer = AVPlayer(playerItem: AVPlayerItem(asset: mixComp))
        playerLayer = AVPlayerLayer(player: videoPlayer!)
        playerLayer?.frame = videoView.bounds
        playerLayer?.videoGravity = .resizeAspect
        videoView.layer.insertSublayer(playerLayer!, at: 0)
        videoPlayer!.play()
        
    }
    
    func slowToFast(track: AVMutableCompositionTrack, startTime: CMTime, endTime: CMTime, finalDuration: Float64, timescale: CMTimeScale) -> CMTime {
        // Number of frames
        let originalNumOfFrames = Int64((CMTimeGetSeconds(endTime) - CMTimeGetSeconds(startTime)) * Float64(timescale))
        let finalNumOfFrames = Int64(finalDuration * Float64(timescale))
        
        // slow mo constant factors
        let slowMoWillApply: Float64 = 0.1
        let slowMoApplied: Float64 = 2.0/3.0
        let singleFrame = CMTimeMake(value: 10, timescale: timescale)
        
        // slow mo variables
        let originalSlowMoFrames: Int64 = Int64(Float64(originalNumOfFrames) * slowMoWillApply)
        var finalSlowMoFrames: Int64 = Int64(Float64(finalNumOfFrames) * slowMoApplied)
        // loop
        var numOfSlowMoIteration: Int64 = originalSlowMoFrames / 10
        let leftOverSlowMoFrames: Int64 = originalSlowMoFrames % 10 // if there are 0.x frames, add them to the first iteration
        var slowMoDuration: Int64 = 40 // slow down by factor of 4
        
        var start = startTime
        var requiredFrames = calcFrames(duration: slowMoDuration + leftOverSlowMoFrames, iteration: numOfSlowMoIteration)
        
        track.scaleTimeRange(CMTimeRangeMake(start: start, duration: singleFrame),
                             toDuration: CMTimeMake(value: 10 + slowMoDuration + leftOverSlowMoFrames, timescale: timescale))
        start = CMTimeAdd(start, CMTimeMake(value: 10 + slowMoDuration + leftOverSlowMoFrames, timescale: timescale))
        finalSlowMoFrames -= (10 + slowMoDuration + leftOverSlowMoFrames)
        slowMoDuration -= 1
        numOfSlowMoIteration -= 1
        
        // slow mo loop
        while finalSlowMoFrames > 0 {
            print("slowToFast slow mo while loop")
            if requiredFrames <= finalSlowMoFrames {
                if finalSlowMoFrames < slowMoDuration + 10 {
                    slowMoDuration = finalSlowMoFrames - 10
                }
                track.scaleTimeRange(CMTimeRangeMake(start: start, duration: singleFrame),
                                     toDuration: CMTimeMake(value: 10 + slowMoDuration, timescale: timescale))
                start = CMTimeAdd(start, CMTimeMake(value: 10 + slowMoDuration, timescale: timescale))
                finalSlowMoFrames -= (10 + slowMoDuration)
                if requiredFrames > finalSlowMoFrames {
                    slowMoDuration -= 1
                    numOfSlowMoIteration -= 1
                }
                continue
            } else {
                repeat {
                    print("slowToFast slow mo repeat while loop")
                    slowMoDuration = Int64(Double(slowMoDuration) / 2.0)
                    numOfSlowMoIteration = Int64(Double(numOfSlowMoIteration) / 2.0)
                    requiredFrames = calcFrames(duration: slowMoDuration, iteration: numOfSlowMoIteration)
                } while requiredFrames > finalSlowMoFrames
            }
        }
        
        // fast mo constant factors
        let fastMoWillApply: Float64 = 1.0 - slowMoWillApply
        let fastMoApplied: Float64 = 1.0 - slowMoApplied
        
        // fast mo variables
        var originalFastMoFrames: Int64 = Int64(Float64(originalNumOfFrames) * fastMoWillApply)
        let finalFastMoFrames: Int64 = Int64(Float64(finalNumOfFrames) * fastMoApplied)
        // loop
        let numOfFastMoIteration: Int64 = finalFastMoFrames / 10
        let leftOverFastMoFrames: Int64 = finalFastMoFrames % 10 // if there are 0.x frames, add them to the last iteration
        let fastMoPrep: Float64 = Double(originalFastMoFrames) / (Double(numOfFastMoIteration) / 2.0) - 20.0
        let fastMoIncreament: Int64 = Int64(fastMoPrep / Float64(numOfFastMoIteration))
        let fastMoIncreamentFloat: Float64 = fastMoPrep / Float64(numOfFastMoIteration)
        
        var increament: Int64 = 0
        var increamentFloat: Float64 = 0
        var iteration: Int64 = 0
        
        while iteration < numOfFastMoIteration {
            print("slowToFast fast mo while loop")
            if iteration == numOfFastMoIteration - 1 {
                if originalFastMoFrames > 10 + increament {
                    increament = originalFastMoFrames - 10
                }
            }
            track.scaleTimeRange(CMTimeRangeMake(start: start, duration: CMTimeMake(value: 10 + increament, timescale: timescale)),
                                 toDuration: iteration == numOfFastMoIteration - 1 ?
                                        CMTimeMake(value: 10 + leftOverFastMoFrames, timescale: timescale) : singleFrame)
            start = CMTimeAdd(start, iteration == numOfFastMoIteration - 1 ?
                                    CMTimeMake(value: 10 + leftOverFastMoFrames, timescale: timescale) : singleFrame)
            originalFastMoFrames -= (10 + increament)
            
            if originalFastMoFrames <= 0 { // if the loop fast motioned all frames, then early exit
                break
            }
            
            increament += fastMoIncreament
            increamentFloat += fastMoIncreamentFloat
            iteration += 1
            
            while increament < Int64(increamentFloat) {
                print("slowToFast fast mo increament while loop")
                increament += 1
            }
        }
        return start
    }
    
    func fastToSlow(track: AVMutableCompositionTrack, startTime: CMTime, endTime: CMTime, finalDuration: Float64, timescale: CMTimeScale) -> CMTime {
        // Number of frames
        let originalNumOfFrames = Int64((CMTimeGetSeconds(endTime) - CMTimeGetSeconds(startTime)) * Float64(timescale))
        let finalNumOfFrames = Int64(finalDuration * Float64(timescale))
        
        // slow mo constant factors
        let slowMoWillApply: Float64 = 0.1
        let slowMoApplied: Float64 = 2.0/3.0
        let singleFrame = CMTimeMake(value: 10, timescale: timescale)
        
        // slow mo variables
        let originalSlowMoFrames: Int64 = Int64(Float64(originalNumOfFrames) * slowMoWillApply)
        var finalSlowMoFrames: Int64 = Int64(Float64(finalNumOfFrames) * slowMoApplied)
        // loop
        var numOfSlowMoIteration: Int64 = originalSlowMoFrames / 10
        let leftOverSlowMoFrames: Int64 = originalSlowMoFrames % 10 // if there are 0.x frames, add them to the first iteration
        var slowMoDuration: Int64 = 40 // slow down by factor of 4
        
        // start from the end time and work backwards
        var start = CMTimeSubtract(endTime, singleFrame)
        var requiredFrames = calcFrames(duration: slowMoDuration + leftOverSlowMoFrames, iteration: numOfSlowMoIteration)
        
        track.scaleTimeRange(CMTimeRangeMake(start: start, duration: singleFrame),
                             toDuration: CMTimeMake(value: 10 + slowMoDuration + leftOverSlowMoFrames, timescale: timescale))
        start = CMTimeSubtract(start, singleFrame)
        finalSlowMoFrames -= (10 + slowMoDuration + leftOverSlowMoFrames)
        slowMoDuration -= 1
        numOfSlowMoIteration -= 1
        
        // slow mo loop
        while finalSlowMoFrames > 0 {
            print("fastToSlow slow mo while loop")
            if requiredFrames <= finalSlowMoFrames {
                track.scaleTimeRange(CMTimeRangeMake(start: start, duration: singleFrame),
                                     toDuration: CMTimeMake(value: 10 + slowMoDuration, timescale: timescale))
                start = CMTimeSubtract(start, singleFrame)
                finalSlowMoFrames = finalSlowMoFrames - (10 + slowMoDuration)
                if requiredFrames > finalSlowMoFrames {
                    slowMoDuration -= 1
                    numOfSlowMoIteration -= 1
                    requiredFrames = calcFrames(duration: slowMoDuration, iteration: numOfSlowMoIteration)
                }
                if finalSlowMoFrames < slowMoDuration + 10 {
                    slowMoDuration = finalSlowMoFrames - 10
                }
                continue
            } else {
                repeat {
                    print("fastToSlow slow mo repeat while loop")
                    slowMoDuration = Int64(Double(slowMoDuration) / 2.0)
                    numOfSlowMoIteration = Int64(Double(numOfSlowMoIteration) / 2.0)
                    requiredFrames = calcFrames(duration: slowMoDuration, iteration: numOfSlowMoIteration)
                } while requiredFrames > finalSlowMoFrames
            }
        }
        
        // fast mo constant factors
        let fastMoWillApply: Float64 = 1.0 - slowMoWillApply
        let fastMoApplied: Float64 = 1.0 - slowMoApplied
        
        // fast mo variables
        var originalFastMoFrames: Int64 = Int64(Float64(originalNumOfFrames) * fastMoWillApply)
        let finalFastMoFrames: Int64 = Int64(Float64(finalNumOfFrames) * fastMoApplied)
        // loop
        let numOfFastMoIteration: Int64 = finalFastMoFrames / 10
        let leftOverFastMoFrames: Int64 = finalFastMoFrames % 10 // if there are 0.x frames, add them to the last iteration
        let fastMoPrep: Float64 = Double(originalFastMoFrames) / (Double(numOfFastMoIteration) / 2.0) - 20.0
        let fastMoIncreament: Int64 = Int64(fastMoPrep / Float64(numOfFastMoIteration))
        let fastMoIncreamentFloat: Float64 = fastMoPrep / Float64(numOfFastMoIteration)
        
        var increament: Int64 = 0
        var increamentFloat: Float64 = 0
        var iteration: Int64 = 0
        
        start = CMTimeSubtract(start, CMTimeMake(value: 10 + increament, timescale: timescale))
        
        while iteration < numOfFastMoIteration {
            print("fastToSlow fast mo while loop")
            if iteration == numOfFastMoIteration - 1 {
                if originalFastMoFrames > 10 + increament {
                    increament = originalFastMoFrames - 10
                }
            }
            track.scaleTimeRange(CMTimeRangeMake(start: start, duration: CMTimeMake(value: 10 + increament, timescale: timescale)),
                                 toDuration: iteration == numOfFastMoIteration - 1 ?
                                    CMTimeMake(value: 10 + leftOverFastMoFrames, timescale: timescale) : singleFrame)
            start = CMTimeSubtract(start, CMTimeMake(value: 10 + increament, timescale: timescale))
            originalFastMoFrames -= (10 + increament)
            
            if originalFastMoFrames <= 0 { // if the loop fast motioned all frames, then early exit
                break
            }
            
            increament += fastMoIncreament
            increamentFloat += fastMoIncreamentFloat
            iteration += 1
            
            while increament < Int64(increamentFloat) {
                print("fastToSlow fast mo increament while loop")
                increament += 1
            }
        }
        
        return CMTimeAdd(start, CMTimeMake(value: finalNumOfFrames, timescale: timescale))
    }
    
    func calcFrames(duration: Int64, iteration: Int64) -> Int64{
        return Int64(Float64(duration + 10) * Float64(iteration) / 2.0)
    }
    
    // MARK: - Tab Guesture
    @objc func handleTapGuesture(_ tapGesture: UITapGestureRecognizer) {
        print("tap")
        switch tapGesture.state {
        case .ended:
            playRecording()
        default:
            print("Handle other states: \(tapGesture.state)")
        }
    }
    
    func playRecording() {
        if let player = videoPlayer {
            // CMTime
            player.seek(to: CMTime.zero)
            player.play()
        }
    }
    
    // MARK: - IBActions
    @IBAction func chooseVideo(_ sender: Any) {
        presentVideoPickerController()
        for markerView in videoMarkerView.subviews {
            markerView.removeFromSuperview()
        }
        videoMarkers = []
        videoMarkerCount.text = "Marker: \(videoMarkers.count)"
        
        for markerView in audioMarkerView.subviews {
            markerView.removeFromSuperview()
        }
        audioMarkers = []
        audioMarkerCount.text = "Marker: \(audioMarkers.count)"
    }
    @IBAction func applyEffectsAndPlay(_ sender: Any) {
        applyEffects()
    }
    
    @IBAction func videoSliderValueChanged(_ sender: Any) {
        guard let timescale = timescale else { return }
        let seekTime: CMTime = CMTimeMakeWithSeconds(Float64(videoSlider!.value), preferredTimescale: timescale)
        stopPlayingAndSeekSmoothlyToTime(newChaseTime: seekTime)
        updateVideoViews()
    }
    
    @IBAction func addVideoMarker(_ sender: Any) {
        let markerPosition = videoSlider.value / videoSlider.maximumValue
        guard let marker = Marker(position: Float64(markerPosition)) else { return }
        videoMarkers.append(marker)
        
        let imageView = UIImageView(image: marker.image)
        let size = videoMarkerView.frame.height
        let xPosition = (videoMarkerView.frame.width * CGFloat(markerPosition)) - size/2.0
        
        imageView.frame = CGRect(x: xPosition, y: 0, width: size, height: size)
        imageView.tag = videoMarkers.count
        videoMarkerView.addSubview(imageView)
        videoMarkerView.bringSubviewToFront(imageView)
        videoMarkerCount.text = "Marker: \(videoMarkers.count)"
    }
    
    @IBAction func removeVideoMarker(_ sender: Any) {
        if !videoMarkers.isEmpty {
            videoMarkerView.viewWithTag(videoMarkers.count)?.removeFromSuperview()
            videoMarkers.removeLast()
            videoMarkerCount.text = "Marker: \(videoMarkers.count)"
        }
    }
    
    @IBAction func addAudioMarker(_ sender: Any) {
        if (audioMarkers.count == videoMarkers.count) {
            return
        }
        let markerPosition: Float = (waveform.highlightedSamples != nil ? Float(waveform.highlightedSamples!.endIndex) : 0.0) / Float(waveform.totalSamples)
        guard let marker = Marker(position: Float64(markerPosition)) else { return }
        audioMarkers.append(marker)

        let imageView = UIImageView(image: marker.image)
        let size = audioMarkerView.frame.height
        let xPosition = (audioMarkerView.frame.width * CGFloat(markerPosition)) - size/2.0

        imageView.frame = CGRect(x: xPosition, y: 0, width: size, height: size)
        imageView.tag = audioMarkers.count
        audioMarkerView.addSubview(imageView)
        audioMarkerView.bringSubviewToFront(imageView)
        audioMarkerCount.text = "Marker: \(audioMarkers.count)"
    }
    
    @IBAction func removeAudioMarker(_ sender: Any) {
        if !audioMarkers.isEmpty {
            audioMarkerView.viewWithTag(audioMarkers.count)?.removeFromSuperview()
            audioMarkers.removeLast()
            audioMarkerCount.text = "Marker: \(audioMarkers.count)"
        }
    }
    
    @IBAction func playButtonPressed(_ sender: Any) {
        playPauseAudio()
    }
}



extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        picker.dismiss(animated: true, completion: nil)
        
        guard let mediaType = info[UIImagePickerController.InfoKey.mediaType] as? String,
            mediaType == (kUTTypeMovie as String),
            let videoURL = info[UIImagePickerController.InfoKey.mediaURL] as? URL else {
                
                // TODO: self.presentInformationalAlertController(title: "Error", message: "Please choose a video")
                return
        }
        self.videoURL = videoURL
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
}

extension ViewController: MPMediaPickerControllerDelegate {
    func mediaPicker(_ mediaPicker: MPMediaPickerController, didPickMediaItems mediaItemCollection: MPMediaItemCollection) {
        mediaPicker.dismiss(animated: true) {
            let selectedSongs = mediaItemCollection.items
            guard let song = selectedSongs.first else { return }
            
            let url = song.value(forProperty: MPMediaItemPropertyAssetURL) as? URL
            // print(url)
        }
    }
    
    func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController) {
        mediaPicker.dismiss(animated: true, completion: nil)
    }
}

extension ViewController: FDWaveformViewDelegate {
    func waveformDidEndScrubbing(_ waveformView: FDWaveformView) {
        if let audioPlayer = audioPlayer {
            if let highlightedSamples = waveformView.highlightedSamples {
                audioPlayer.currentTime = Double(highlightedSamples.endIndex) / Double(waveformView.totalSamples) * audioPlayer.duration
            } else {
                audioPlayer.currentTime = 0
            }
            audioTimeElapsedLabel.text = timeFormatter.string(from: audioPlayer.currentTime)
        }
    }
}

extension ViewController: AVAudioPlayerDelegate {
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        if let error = error {
            print("Audio playback error: \(error)")
        }
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        updateAudioViews()
    }
}
