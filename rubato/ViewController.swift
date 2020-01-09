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
    
    var videoPlayer: AVPlayer!
    var playerLayer: AVPlayerLayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapGuesture(_:)))
        view.addGestureRecognizer(tapGesture)
        
        let url = Bundle.main.url(forResource: "Dancin", withExtension: "mp3")
        let waveform = FDWaveformView()
        waveform.audioURL = url
        waveform.doesAllowScroll = true
        waveform.doesAllowStretch = true
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
            
//            let start = fastToNormal(track: track1, startTime: .zero, endTime: CMTimeMake(value: Int64(Double(videoAsset.duration.value) * 2.0/3.0), timescale: 600),finalDuration: 1, timescale: videoAsset.duration.timescale)
            
            let start = slowToFast(track: track1, startTime: .zero, endTime: CMTimeMake(value: Int64(Double(videoAsset.duration.value) * 0.5), timescale: 600), finalDuration: 2.0, timescale: 600)
            normalToSlow(track: track1, startTime: start, endTime: CMTimeMake(value: videoAsset.duration.value, timescale: 600), timescale: 600)
            
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
        
        var start = CMTimeMake(value: Int64(CMTimeGetSeconds(startTime) * Float64(timescale)), timescale: timescale)
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
    
    func calcFrames(duration: Int64, iteration: Int64) -> Int64{
        return Int64(Float64(duration + 10) * Float64(iteration) / 2.0)
    }
    
    func normalToSlow(track: AVMutableCompositionTrack, startTime: CMTime, endTime: CMTime, timescale: CMTimeScale) -> CMTime {
        var frame: Int64 = Int64(CMTimeGetSeconds(startTime) * Float64(timescale))
        let endFrame = Int64(CMTimeGetSeconds(endTime) * Float64(timescale))
        let singleFrame = CMTimeMake(value: 10, timescale: timescale)
        var start = CMTimeMake(value: frame, timescale: timescale)
        
        var offset: Int64 = 0
        
        while frame < endFrame {
            let duration = CMTimeMake(value: 10 + offset , timescale: timescale)
            
            track.scaleTimeRange(CMTimeRangeMake(start: start, duration: singleFrame), toDuration: duration)
            start = CMTimeAdd(start, duration)
            
            offset += 1
            frame += 1
        }
        return start
    }
    
    func fastToNormal(track: AVMutableCompositionTrack, startTime: CMTime, endTime: CMTime, finalDuration: Float64, timescale: CMTimeScale)  -> CMTime {
        var frame: Int64 = Int64(CMTimeGetSeconds(startTime) * Float64(timescale))
        let numbOfIteration = Int64(finalDuration * Float64(timescale) / 10)
        let singleFrame = CMTimeMake(value: 10, timescale: timescale)
        var start = CMTimeMake(value: frame, timescale: timescale)
        
        let currentDuration = CMTimeGetSeconds(endTime) - CMTimeGetSeconds(startTime)
        let totalFrames = Int64(currentDuration * Float64(timescale))
        let dividedFrames = totalFrames / numbOfIteration
        let extraFrames = dividedFrames - 10
        let decreamentInterval = numbOfIteration / extraFrames
        
        let finalFrames =  Int64(finalDuration * Float64(timescale))
        
        var offset: Int64 = (decreamentInterval != 0 && decreamentInterval != 1) ? extraFrames*2 : totalFrames/(numbOfIteration/2) - 10
        //var offset: Int64 = totalFrames/(numbOfIteration/2) - 10

        let offsetInterval = offset / numbOfIteration
        var intervalIndex: Int64 = 1
        
        while frame < numbOfIteration {
            let fastFrame = CMTimeMake(value: 10 + offset, timescale: timescale)
            track.scaleTimeRange(CMTimeRangeMake(start: start, duration: fastFrame), toDuration: singleFrame)
            start = CMTimeAdd(start, singleFrame)
            
            if decreamentInterval != 0, intervalIndex % decreamentInterval == 0 {
                offset -= 1
                intervalIndex = 1
            } else if decreamentInterval == 0 {
                offset -= offsetInterval
            }
            //offset -= offsetInterval
            intervalIndex += 1
            frame += 1
        }
        
        return start
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
//        var topRect = videoView.bounds
//        topRect.size.height = topRect.height / 1.5
//        topRect.size.width = topRect.width / 1.5
//        topRect.origin.y = view.safeAreaInsets.top
        playerLayer?.frame = videoView.bounds
        playerLayer?.videoGravity = .resizeAspect
        videoView.layer.insertSublayer(playerLayer!, at: 0)
//        view.layer.addSublayer(playerLayer!)
        
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

