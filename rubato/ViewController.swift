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

    @IBOutlet weak var videoView: UIView!
    @IBOutlet weak var audioView: UIView!
    @IBOutlet weak var markerView: UIView!
    @IBOutlet weak var videoSlider: UISlider!
    
    // video player
    var videoPlayer: AVPlayer!
    var playerLayer: AVPlayerLayer?
    
    // marker
    var videoMarkers: [Marker] = []
    var audioMarkers: [Marker] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapGuesture(_:)))
        view.addGestureRecognizer(tapGesture)
        
        // audio waveform
        let url = Bundle.main.url(forResource: "Dubstep1", withExtension: "mp3")
        let waveform = FDWaveformView()
        waveform.audioURL = url
        waveform.doesAllowScroll = false
        waveform.doesAllowStretch = false
        waveform.doesAllowScrubbing = true
        waveform.frame = audioView.bounds
        audioView.insertSubview(waveform, at: 0)
    }

    @IBAction func chooseVideo(_ sender: Any) {
        presentVideoPickerController()
//        getAuthorizationForAppleMusic()
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
    
    private func slowMotion(url: URL) -> AVPlayerItem? {
        
        let videoAsset = AVURLAsset(url: url)
        
        let mixComp = AVMutableComposition()
       
        let videoAssetSourceTrack = videoAsset.tracks(withMediaType: AVMediaType.video).first! as AVAssetTrack
        
        guard let track1 = mixComp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            print("Error while adding mutable track to composition")
            return nil
        }

        do {
            try track1.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: videoAsset.duration), of: videoAssetSourceTrack, at: CMTime.zero)
            
            let start = fastToSlow(track: track1, startTime: .zero, endTime: CMTimeMake(value: Int64(Double(videoAsset.duration.value) * 0.5), timescale: 600), finalDuration: 1.0, timescale: 600)
            slowToFast(track: track1, startTime: start, endTime: CMTimeMake(value: videoAsset.duration.value, timescale: 600), finalDuration: 1.0, timescale: 600)
            
            
            track1.preferredTransform = videoAssetSourceTrack.preferredTransform
            
            
            let asset:AVAsset = mixComp
            print("Applied slow motion effect!")
            return AVPlayerItem(asset: asset)
            
        } catch {
            print("Error processing slow motion: \(error)")
            return nil
        }
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
            if requiredFrames <= finalSlowMoFrames {
                if finalSlowMoFrames < slowMoDuration + 10 {
                    slowMoDuration = finalSlowMoFrames - 10
                }
                track.scaleTimeRange(CMTimeRangeMake(start: start, duration: singleFrame),
                                     toDuration: CMTimeMake(value: 10 + slowMoDuration, timescale: timescale))
                start = CMTimeSubtract(start, singleFrame)
                finalSlowMoFrames -= (10 + slowMoDuration)
                if requiredFrames > finalSlowMoFrames {
                    slowMoDuration -= 1
                    numOfSlowMoIteration -= 1
                }
                continue
            } else {
                repeat {
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
                increament += 1
            }
        }
        
        return CMTimeAdd(start, CMTimeMake(value: finalNumOfFrames, timescale: timescale))
    }
    
    func calcFrames(duration: Int64, iteration: Int64) -> Int64{
        return Int64(Float64(duration + 10) * Float64(iteration) / 2.0)
    }
    
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
    @IBAction func videoSliderValueChanged(_ sender: Any) {
        
    }
    
    @IBAction func addVideoMarker(_ sender: Any) {
        let markerPosition = videoSlider.value
        guard let marker = Marker(position: markerPosition as NSNumber) else { return }
        videoMarkers.append(marker)
        
        let imageView = UIImageView(image: marker.image)
        let size = markerView.frame.height
        let xPosition = (markerView.frame.width * CGFloat(markerPosition)) - size/2.0
        
        imageView.frame = CGRect(x: xPosition, y: -size, width: size, height: size)
        imageView.tag = videoMarkers.count
        markerView.addSubview(imageView)
        markerView.bringSubviewToFront(imageView)
        
    }
    
    @IBAction func removeVideoMarker(_ sender: Any) {
        if !videoMarkers.isEmpty {
            markerView.viewWithTag(videoMarkers.count)?.removeFromSuperview()
            videoMarkers.removeLast()
        }
    }
    
    @IBAction func removeAudioMarker(_ sender: Any) {
        
    }
    @IBAction func addAudioMarker(_ sender: Any) {
    }
    
}



extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        picker.dismiss(animated: true, completion: nil)
        
        guard let mediaType = info[UIImagePickerController.InfoKey.mediaType] as? String,
            mediaType == (kUTTypeMovie as String),
            let url = info[UIImagePickerController.InfoKey.mediaURL] as? URL else {
                
                // TODO: self.presentInformationalAlertController(title: "Error", message: "Please choose a video")
                return
        }
        playerLayer?.removeFromSuperlayer()
                
        videoPlayer = AVPlayer(playerItem: slowMotion(url: url))
        playerLayer = AVPlayerLayer(player: videoPlayer)
        playerLayer?.frame = videoView.bounds
        playerLayer?.videoGravity = .resizeAspect
        videoView.layer.insertSublayer(playerLayer!, at: 0)
        
        videoPlayer.play()
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
            
        }
    }
    
    func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController) {
        mediaPicker.dismiss(animated: true, completion: nil)
    }
}

