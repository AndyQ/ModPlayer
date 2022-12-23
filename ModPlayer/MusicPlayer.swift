//
//  MusicPlayer.swift
//  ModPlayer
//
//  Created by Andy Qua on 13/11/2019.
//  Copyright © 2019 Andy Qua. All rights reserved.
//
// Parts of this are based loosely of SpindlePlayer  - https://github.com/pmhicks/Spindle-Player
// Licenced under MIT licence

import Foundation

public enum PlayerState: String, CustomStringConvertible {
    case Unloaded = "Unloaded"
    case Loaded = "Loaded"
    case FailedLoad = "FailedLoad"
    case Error = "Error"
    case Playing = "Playing"
    case Stopped = "Stopped"
    case Paused = "Paused"
    
    public var description : String {
        get {
            return self.rawValue
        }
    }
}

class MusicPlayer {
    private var player : AudioPlayer
    private (set) var moduleInfo : ModuleInfo?
        
    private var state:PlayerState {
        didSet {
            print("StateChange Old: \(oldValue) New: \(state)")
            NotificationCenter.default.post(name: NSNotification.Name.stateChanged, object: state)

        }
    }

    var channelMuteStatus : [Int:Bool] = [Int:Bool]()

    var position : Int = 0
    var patternNr : Int = 0
    var lineInPattern : Int {
        return player.currentRow
    }
    var seconds : Int {
        return player.timeInSeconds
    }

    var volume:Float {
        didSet {
            if volume > 1.0 {
                volume = 1.0
            }
            if volume < 0.0 {
                volume = 0.0
            }
            player.volume = volume
        }
    }
    
    init(volume:Float) {
        self.volume = volume
        self.state = .Unloaded
        
        player = XMP_AudioPlayer()
        player.initPlayer()
        player.volume = volume

        let center = NotificationCenter.default

        center.addObserver(forName: NSNotification.Name.queueFinished, object: nil, queue: OperationQueue.main) { [weak self] _ in
            if let s = self {
                if s.state == .Playing {
                    s.player.stop()
                    s.state = .Stopped
                    center.post(name: NSNotification.Name.songFinished, object: nil)
                }
            }
        }
        
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name.patternChanged, object: nil, queue: OperationQueue.main) { [weak self] note in
            
            guard let dict = note.object as? [String:Int] else { return }
            self?.position = dict["position"] ?? 0
            self?.patternNr = dict["pattern"] ?? 0
            //print( self?.position )
        }
        
    }
   
    deinit {
        print("deinit MusicPlayer")
        player.stop()
        sendEndNotification()
        if !(state == .Unloaded || state == .FailedLoad) {
            print("releasing XMP")
        }
    }
    
    func load(url:URL) -> (module:ModuleInfo?, success:Bool, error:String) {
        
        if !url.isFileURL {
            self.state = .FailedLoad
            return (nil, false, "URL is not a file")
        }
        let filename = url.path
        let loadResult = player.loadModuleFile(filePath: filename)
//        let loadResult = xmp_load_module(context, filename.utf8CString)
        if loadResult != 0 {
            //let err = lastError()
            self.state = .FailedLoad
            let message:String = {
                switch loadResult {
                    case -3:
                        return "Unrecognized Module Format"
                    case -4:
                        return "Error Loading Module (corrupt file?)"
                    default:
                        return "XMP code \(loadResult)"
                }
                
            }()
            return (nil, false, message)
        }

        self.moduleInfo = player.getModuleInfo()

        // Reset channels to unmutes
        let nrChannels = self.moduleInfo?.channelCount ?? 0
        self.channelMuteStatus.removeAll()
        for i in 0 ..< nrChannels {
            self.channelMuteStatus[i] = false
        }

        state = .Loaded
        
        self.position = 0
        self.patternNr = moduleInfo?.patternInOrder(for: 0) ?? 0
        let dict = ["pattern":self.patternNr, "position" : self.position]
        NotificationCenter.default.post(name: NSNotification.Name.patternChanged, object: dict)

        return (self.moduleInfo, true, "")
    }
    
    func play() {
        
        switch self.state {
        case .Unloaded, .FailedLoad, .Error:
            return
        case .Playing:
            return
        case .Paused:
            player.resume()
            self.state = .Playing
            return
        case .Loaded, .Stopped:
            if !player.play() {
                self.state = .Error
                return
            }
            player.currentOrderPosition = self.position
            
            
            for i in 0 ..< self.moduleInfo!.channelCount {
                player.muteChannel(channelNr: i, mute:self.channelMuteStatus[i] ?? false)
            }

            self.state = .Playing
        }
    }
    
    func pause() {
        switch self.state {
        case .Playing:
            player.pause()
            self.state = .Paused
        case .Paused:
            player.resume()
            self.state = .Playing
        default:
            break
        }
    }
    
    func endPlayer() {
        print("End Player")
        self.stop()
    }
    
    func stop() {
        switch self.state {
        case .Playing, .Paused:
            self.state = .Stopped
            player.stop()
            sendEndNotification()
        default:
            break
        }
    }
    
    func muteTrack( trackNr: Int, shouldMute: Bool ) {
        channelMuteStatus[trackNr] = shouldMute
        player.muteChannel(channelNr: trackNr, mute: shouldMute)
    }
    
    private func sendEndNotification() {
        let center = NotificationCenter.default
        center.post(name: NSNotification.Name.timeChanged, object: NSNumber(value: 0))
        center.post(name: NSNotification.Name.positionChanged, object: NSNumber(value: 0))

    }
    
    func nextPosition() {
        guard let modInfo = self.moduleInfo else { return }
        var nextPos = self.position + 1
        if nextPos > modInfo.lengthInPatterns-1 {
            nextPos = modInfo.lengthInPatterns-1
        }

        player.currentOrderPosition = nextPos
        
        let pattern = modInfo.patternInOrder( for:nextPos )
        let dict = ["pattern":pattern, "position" : nextPos]
        NotificationCenter.default.post(name: NSNotification.Name.patternChanged, object: dict)
    }
    
    func previousPosition() {
        guard let modInfo = self.moduleInfo else { return }
        var prevPos = self.position - 1
        if prevPos < 0 {
            prevPos = 0
        }
        player.currentOrderPosition = prevPos

        let pattern = modInfo.patternInOrder( for:prevPos )
        let dict = ["pattern":pattern, "position" : prevPos]
        NotificationCenter.default.post(name: NSNotification.Name.patternChanged, object: dict)
    }
    
    // return false if not playing
    func seek(seconds:Int) -> Bool {
        if self.state == .Playing || self.state == .Paused {
            return true
        }
        return false
    }
}
