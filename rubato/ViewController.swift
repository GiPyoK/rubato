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

class ViewController: UIViewController {

    @IBOutlet weak var videoView: UIView!
    
    var videoPlayer: AVPlayer!
    var playerLayer: AVPlayerLayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapGuesture(_:)))
        view.addGestureRecognizer(tapGesture)
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
        
        let third = CMTimeMake(value: videoAsset.duration.value / 3, timescale: 600)
        
        let third1 = CMTimeRangeMake(start: CMTime.zero, duration: CMTime(seconds: 2, preferredTimescale: 600))
        let third1Slow = CMTimeMake(value: videoAsset.duration.value / 3 / 3, timescale: 600)
        
        let third2 = CMTimeRangeMake(start: third1Slow, duration: third)
        let third2Fast = CMTimeMake(value: videoAsset.duration.value / 3 * 2, timescale: 600)
        
        let third3 = CMTimeRangeMake(start: CMTimeAdd(third1Slow, third2Fast), duration: third)
        let third3Slow = CMTimeMake(value: videoAsset.duration.value / 3 / 3, timescale: 600)
        
        
        

        do {
            try track1.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: videoAsset.duration), of: videoAssetSourceTrack, at: CMTime.zero)
//            track1.scaleTimeRange(third1, toDuration: third1Slow)
//            track1.scaleTimeRange(third2, toDuration: third2Fast)
//            track1.scaleTimeRange(third3, toDuration: third3Slow)
            
            normalToSlow(track: track1, startTime: .zero, endTime: CMTimeMake(value: videoAsset.duration.value / 4, timescale: 600), timescale: videoAsset.duration.timescale)
            
            track1.preferredTransform = videoAssetSourceTrack.preferredTransform
            
            
            let asset:AVAsset = mixComp
            print("Applied slow motion effect!")
            return AVPlayerItem(asset: asset)
            
        } catch {
            print("Error processing slow motion: \(error)")
            return nil
        }
    }
    
    func normalToSlow(track: AVMutableCompositionTrack, startTime: CMTime, endTime: CMTime, timescale: CMTimeScale) {
        var frame : Int64 = Int64(CMTimeGetSeconds(startTime) * Float64(timescale))
        let singleFrame = CMTimeMake(value: 10, timescale: timescale)
        let endFrame = Int64(CMTimeGetSeconds(endTime) * Float64(timescale))
        var start = CMTime.zero
        
        while frame < endFrame {
            let duration = CMTimeMake(value: 10 + frame , timescale: timescale)
            
            track.scaleTimeRange(CMTimeRangeMake(start: start, duration: singleFrame), toDuration: duration)
            start = CMTimeAdd(start, duration)
            
            frame += 1
        }
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
        print("Video URL: \(url)")
                
        videoPlayer = AVPlayer(playerItem: slowMotion(url: url))
        
        playerLayer = AVPlayerLayer(player: videoPlayer)
        var topRect = view.bounds
        topRect.size.height = topRect.height / 1.5
        topRect.size.width = topRect.width / 1.5
        topRect.origin.y = view.safeAreaInsets.top
        playerLayer?.frame = topRect
        view.layer.addSublayer(playerLayer!)
        
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
            
            print("Audio URL: \(url)")
        }
    }
    
    func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController) {
        mediaPicker.dismiss(animated: true, completion: nil)
    }
}

