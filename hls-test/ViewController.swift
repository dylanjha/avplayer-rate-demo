//
//  ViewController.swift
//  hls-test
//
//  Created by Andrew Hsu on 3/11/19.
//  Copyright © 2019 Andrew Hsu. All rights reserved.
//

import UIKit
import AVFoundation
import MUXSDKStats

class ViewController: UIViewController {
    
    // MARK: - Constants
    
    private let rate: Float = 1.25

    private let speakVideoPath = "https://d34af8cfq8hdgo.cloudfront.net/test/aws-watermark/l1_d0_vl_2.m3u8"
    private let expName = "speak source"
//    private let speakVideoPath = "https://stream.mux.com/idquf6N83PgEPID02peQ4aPx3L02YjxAxW.m3u8"
//    private let expName = "m3u8"
//    private let speakVideoPath = "https://stream.mux.com/idquf6N83PgEPID02peQ4aPx3L02YjxAxW/low.mp4"
//    private let expName = "mp4 low"
//    private let speakVideoPath = "https://stream.mux.com/idquf6N83PgEPID02peQ4aPx3L02YjxAxW/medium.mp4"
//    private let expName = "mp4 med"
//    private let speakVideoPath = "https://stream.mux.com/idquf6N83PgEPID02peQ4aPx3L02YjxAxW/high.mp4"
//    private let expName = "mp4 high"
    private let appleVideoPath = "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8"
    
    // MARK: - Outlets
    
    @IBOutlet private weak var playbackButton: UIButton!
    @IBOutlet private weak var resetStackView: UIStackView!
    @IBOutlet private weak var resetSpeakButton: UIButton!
    @IBOutlet private weak var resetAppleButton: UIButton!
    
    @IBOutlet private weak var debugStackView: UIStackView!
    @IBOutlet private weak var playbackDebugLabel: UILabel!
    @IBOutlet private weak var networkDebugLabel: UILabel!
    
    @IBOutlet private weak var loadingView: UIActivityIndicatorView!
    
    // MARK: - Private properties
    
    let playName = "IOS_PLAYER"
    let player = AVPlayer()
    private lazy var playerLayer = AVPlayerLayer(player: nil)
    
    /// Flag tracking if the AVPlayerItem.status has become ready for the first time
    private var readyForPlayback = false
    
    // Observers
    private var playerTCSObserver: NSKeyValueObservation?
    private var playerTimeObserver: Any?
    
    private var playerItemObserver: NSKeyValueObservation?
    private var isPlaybackLikelyToKeepUpObserver: NSKeyValueObservation?
    
    var currentPlaybackTime: TimeInterval {
        return player.currentTime().seconds
    }
    
    // MARK: - UIViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
        playbackButton.setTitle("play \(rate)x", for: .normal)
        
        loadingView.hidesWhenStopped = true
        loadingView.stopAnimating()
    }
    
    // MARK: - Setup
    
    private func setup() {
        playerLayer.player = player
        playerLayer.frame = view.bounds
        playerLayer.videoGravity = .resizeAspect
        let playerData = MUXSDKCustomerPlayerData(environmentKey: "ENV_KEY")
        let videoData = MUXSDKCustomerVideoData()
        playerData!.experimentName = "Mux experiment: \(expName)"
        videoData.videoTitle = "Speak test video gear \(expName)"
        videoData.videoIsLive = false
        MUXSDKStats.monitorAVPlayerLayer(playerLayer, withPlayerName: playName, playerData: playerData!, videoData: videoData)
        
        view.layer.addSublayer(playerLayer)
        
        view.bringSubviewToFront(playbackButton)
        view.bringSubviewToFront(debugStackView)
        view.bringSubviewToFront(resetStackView)
        view.bringSubviewToFront(loadingView)
    }
    
    func setVideo(path: String) {
        guard let url = URL(string: path) else {
            return
        }
        
        // Prepare player item
        let item = AVPlayerItem(url: url)
        
        // Configure proper pitch shift algorithm for playback rate changes
        // item.audioTimePitchAlgorithm = .timeDomain // might cause issues?
        
        // Set that video can be loaded when video is paused
        item.canUseNetworkResourcesForLiveStreamingWhilePaused = true
        
        // Clear ready for playback flag
        readyForPlayback = false
        
        // Observe necessary properties
        observePlayer()
        observeItem(with: item)
        
        // Set player item
        pause()
        player.replaceCurrentItem(with: item)
    }
    
}

// MARK: - Helpers

extension ViewController {
    
    private func didPlayTime(_ time: TimeInterval) {
        if let item = player.currentItem, let timebase = item.timebase {
            let timebaseRate: Double = CMTimebaseGetRate(timebase)
            let loadedRanges: String = item.loadedTimeRanges.map {
                let timeRange = $0.timeRangeValue
                let start = String(format: "%0.2f", timeRange.start.seconds)
                let end = String(format: "%0.2f", timeRange.end.seconds)
                return "\(start)s, \(end)s"
                }.joined(separator: "/")
            
            playbackDebugLabel.text = "rate: \(player.rate)\ntimebaseRate: \(timebaseRate)\nloadedTimeRanges: \(loadedRanges)"
            
            newAccessLog(lastEvent())
        }
    }
    
    private func lastEvent() -> AVPlayerItemAccessLogEvent? {
        let accessLog = player.currentItem?.accessLog()
        let lastEvent = accessLog?.events.last
        return lastEvent
    }
    
    private func newAccessLog(_ event: AVPlayerItemAccessLogEvent?) {
        if let event = event {
            let indicated = String(format: "%0.2f", event.indicatedBitrate/1000000.0)
            let uri = (event.uri as NSString?)?.lastPathComponent ?? "no uri"
            let durationWatched = String(format: "%0.2f", event.durationWatched)
            networkDebugLabel.text = "URI: \(uri)\nindicatedBitrate: \(indicated) Mbps\ndurationWatched: \(durationWatched)s\nplayTime: \(currentPlaybackTime)"
        }
    }
    
    @objc private func handleTimebaseRateChanged(_ notification: Notification) {
        if CMTimebaseGetTypeID() == CFGetTypeID(notification.object as CFTypeRef) {
            let timebase = notification.object as! CMTimebase
            let rate: Double = CMTimebaseGetRate(timebase)
            print("Player item timebase rate changed: \(rate).")
            
            updateBufferingStatus()
        }
    }
    
    @objc private func handlePlaybackStalled(_ notification: Notification) {
        print("Player item playback stalled.")
        updateBufferingStatus()
    }
    
    @objc private func handleNewAccessLogEntry(_ notification: Notification) {
        print("Player item new access log entry.")
        newAccessLog(lastEvent())
    }
    
}

// MARK: - Observers

extension ViewController {
    
    private func observePlayer() {
        // Always register/unregister KVO observers on main queue
        DispatchQueue.main.async {
            self.removePlayerObservers()
            
            let timeControlStatusKeyPath = \AVPlayer.timeControlStatus
            self.playerTCSObserver = self.player.observe(timeControlStatusKeyPath, options: [.initial, .new]) { [weak self] (item, _) in
                print("AVPlayer timeControlStatus: \(self?.player.timeControlStatus.spk_stringValue ?? "nil")")
                self?.updateBufferingStatus()
            }
        }
        
        removePlayerTimeObserver()
        
        let observeCMTimeInterval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC)) // Constant 0.1 cm time interval - don't base it on asset timescale
        playerTimeObserver = player.addPeriodicTimeObserver(forInterval: observeCMTimeInterval, queue: .main) { [weak self] time in
            print("play time: \(time.seconds)")
            self?.didPlayTime(time.seconds)
        }
    }
    
    private func observeItem(with playerItem: AVPlayerItem) {
        // Always register/unregister KVO observers on main queue
        DispatchQueue.main.async {
            self.removeItemObservers()
            
            let statusKeyPath = \AVPlayerItem.status
            self.playerItemObserver = playerItem.observe(statusKeyPath, options: [.initial, .new]) { [weak self] (item, _) in
                guard let weakSelf = self else {
                    return
                }
                print("AVPlayerItem status changed: \(playerItem.status.spk_stringValue)")
                
                switch playerItem.status {
                case .readyToPlay: weakSelf.updateReadyState()
                case .failed, .unknown: break
                }
            }
            
            let isPlaybackLikelyToKeepUpKeyPath = \AVPlayerItem.isPlaybackLikelyToKeepUp
            self.isPlaybackLikelyToKeepUpObserver = playerItem.observe(isPlaybackLikelyToKeepUpKeyPath, options: [.initial, .new]) { [weak self] (item, _) in
                print("AVPlayerItem isPlaybackLikelyToKeepUp: \(playerItem.isPlaybackLikelyToKeepUp)")
                self?.updateBufferingStatus()
            }
            
        }
        
        // Observe playerItem playback
        removeItemPlaybackObservers(for: playerItem)
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(handleTimebaseRateChanged(_:)), name: .TimebaseEffectiveRateChangedNotification, object: playerItem.timebase)
        nc.addObserver(self, selector: #selector(handlePlaybackStalled(_:)), name: .AVPlayerItemPlaybackStalled, object: playerItem)
        nc.addObserver(self, selector: #selector(handleNewAccessLogEntry(_:)), name: .AVPlayerItemNewAccessLogEntry, object: playerItem)
    }
    
    private func updateReadyState() {
        if !readyForPlayback {
            readyForPlayback = true
            print("AVPlayerItem ready, set video player state to ready.")
        }
    }
    
    private func updateBufferingStatus() {
        guard let playerItem = player.currentItem else {
            return
        }
        
        let waitingToMinimizeStalls = player.reasonForWaitingToPlay == .toMinimizeStalls
        let isBuffering: Bool = waitingToMinimizeStalls
        
        let stateString = "time: \(String(format: "%0.2f", player.currentTime().seconds)), timeControlStatus: \(player.timeControlStatus.spk_stringValue), waitingReason: \(player.reasonForWaitingToPlay?.spk_stringValue ?? "nil"), keepUp: \(playerItem.isPlaybackLikelyToKeepUp), empty: \(playerItem.isPlaybackBufferEmpty), full: \(playerItem.isPlaybackBufferFull)"
        print("Buffering: \(isBuffering) - \(stateString)")
        
        DispatchQueue.main.async {
            if isBuffering {
                self.loadingView.startAnimating()
            } else {
                self.loadingView.stopAnimating()
            }
        }
    }
    
    private func removePlayerTimeObserver() {
        if let token = playerTimeObserver {
            player.removeTimeObserver(token)
        }
    }
    
    private func removePlayerObservers() {
        if let observer = self.playerTCSObserver {
            observer.invalidate()
        }
    }
    
    private func removeItemObservers() {
        playerItemObserver?.invalidate()
        isPlaybackLikelyToKeepUpObserver?.invalidate()
    }
    
    private func removeItemPlaybackObservers(for playerItem: AVPlayerItem) {
        let nc = NotificationCenter.default
        nc.removeObserver(self, name: .TimebaseEffectiveRateChangedNotification, object: playerItem.timebase)
        nc.removeObserver(self, name: .AVPlayerItemPlaybackStalled, object: playerItem)
        nc.removeObserver(self, name: .AVPlayerItemNewAccessLogEntry, object: playerItem)
    }
    
}

// MARK: - Playback helpers

extension ViewController {
    
    private func play() {
        player.rate = rate
        playbackButton.setTitle("pause", for: .normal)
    }
    
    private func pause() {
        player.pause()
        playbackButton.setTitle("play \(rate)x", for: .normal)
    }
    
}


// MARK: - Target action

extension ViewController {
    
    @IBAction func playbackButtonTapped() {
        if player.timeControlStatus == .playing {
            pause()
        } else {
            play()
        }
    }
    
    @IBAction func resetToSpeakVideoButtonTapped() {
        setVideo(path: speakVideoPath)
    }
    
    @IBAction func resetToAppleVideoButtonTapped() {
        setVideo(path: appleVideoPath)
    }
    
}

// MARK: - Notification extensions

extension Notification.Name {
    
    /// Notification for when a timebase changed rate
    static let TimebaseEffectiveRateChangedNotification = Notification.Name(rawValue: kCMTimebaseNotification_EffectiveRateChanged as String)
    
}

// MARK: - AVFoundation extensions

extension AVPlayer.TimeControlStatus {
    
    var spk_stringValue: String {
        switch self {
        case .paused: return "paused"
        case .waitingToPlayAtSpecifiedRate: return "waitingToPlayAtSpecifiedRate"
        case .playing: return "playing"
        }
    }
    
}

extension AVPlayer.WaitingReason {
    
    var spk_stringValue: String {
        switch self {
        case .toMinimizeStalls: return "toMinimizeStalls"
        case .evaluatingBufferingRate: return "evaluatingBufferingRate"
        case .noItemToPlay: return "noItemToPlay"
        default: return "default"
        }
    }
    
}

extension AVPlayerItem.Status {
    
    var spk_stringValue: String {
        switch self {
        case .failed: return "failed"
        case .unknown: return "unknown"
        case .readyToPlay: return "readyToPlay"
        }
    }
    
}
