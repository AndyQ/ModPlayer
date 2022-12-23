//
//  AudioPlayer.swift
//  ModPlayer
//
//  Created by Andy Qua on 13/11/2019.
//  Copyright © 2019 Andy Qua. All rights reserved.
//
// Parts of this are based loosely of SpindlePlayer  - https://github.com/pmhicks/Spindle-Player
// Licenced under MIT licence


import Foundation
import AudioToolbox
import AudioUnit
import CoreAudio


protocol AudioPlayer {
    func loadModuleFile( filePath: String)  -> Int
    func getModuleInfo() -> ModuleInfo

    func initPlayer()
    
    func muteChannel( channelNr: Int, mute: Bool)
    func play() -> Bool
    func pause()
    func resume()
    func stop()
        
    var currentOrderPosition: Int { get set }
    var numberOfOrderPositions : Int { get }
    var currentPattern : Int { get }
    var numberOfPatterns : Int { get }
    var currentRow : Int { get }
    var timeInSeconds: Int { get }
    var volume: Float { get set }
}

class XMP_AudioPlayer {
    private var context : xmp_context
    private var xmp_moduleInfo = xmp_module_info()

    private var audioDescription : AudioStreamBasicDescription
    private var audioQueue : AudioQueueRef?
    private var audioQueueBuffers : [AudioQueueBufferRef] = []
    private let bufferSize:UInt32 = 1024*2*2

   var position : Int = -1                //current position of mod. Set by callbac : int
   var patternNr : Int = -1                //current pattern number of mod. Set by callbac : int
   var lineInPattern : Int = 0             // While line in the pattern
   var seconds : Int = -1                  //current second of mod. Set by callbac : int
   var isRunning : Bool = false
   var isValid : Bool = false     //true if all initializing completed without error : bool
    
    var volume:Float {
        didSet {
            AudioQueueSetParameter(audioQueue!, AudioQueueParameterID(kAudioQueueParam_Volume), Float32(volume))
        }
    }
    
    init() {
        self.volume = 1
        self.context = xmp_create_context()

        let channelsPerFrame : UInt32 = 2;  //1 - mono, 2 - stereo
        let bitsPerChannel : UInt32 = 16;   //16 or 8 for XMP
        let bytesPerChannel : UInt32 = 2;

        self.audioDescription = AudioStreamBasicDescription()
        self.audioDescription.mSampleRate =  44100
        self.audioDescription.mFormatID = kAudioFormatLinearPCM
        self.audioDescription.mFormatFlags = kAudioFormatFlagIsPacked | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsSignedInteger
        self.audioDescription.mBytesPerPacket = bytesPerChannel * channelsPerFrame
        self.audioDescription.mFramesPerPacket = 1
        self.audioDescription.mBytesPerFrame = bytesPerChannel * channelsPerFrame
        self.audioDescription.mChannelsPerFrame = channelsPerFrame
        self.audioDescription.mBitsPerChannel = bitsPerChannel
        self.audioDescription.mReserved = 0
        
        // Read in module info
        xmp_get_module_info(self.context, &self.xmp_moduleInfo)

    }
    
    deinit {
        print("deinit AudioPlayer")
        disposePlayer()

        xmp_end_player(context)
        xmp_release_module(context)
        xmp_free_context(context)
    }
    
    private func disposePlayer() {
        self.isRunning = false
        self.isValid = false
        xmp_stop_module(self.context)
        if let queue = self.audioQueue {
            _ = AudioQueueDispose(queue, true)
        }
        self.audioQueue = nil
    }
    
    private func audioQueueError(msg:String) {
        print( "Audio queue error - \(msg)" )
    }

}
extension XMP_AudioPlayer : AudioPlayer {
    func loadModuleFile(filePath: String) -> Int {
        let loadResult = xmp_load_module(context, filePath.utf8CString)
        return Int(loadResult)
    }
    
    func getModuleInfo() -> ModuleInfo {
        var rawinfo = xmp_module_info()
        xmp_get_module_info(context, &rawinfo)

        let modInfo = ModuleInfo(info: rawinfo)

        return modInfo
    }
    
    func muteChannel(channelNr: Int, mute: Bool) {
        xmp_channel_mute(context, Int32(channelNr), mute ? 1 : 0 )
    }
    
    
    func getPattern(patternNr: Int) -> [String] {
        return []
    }
    
    var currentOrderPosition: Int {
        set {
            xmp_set_position(context, Int32(newValue))
        }
        
        get {
            return self.position
        }
    }
    
    var numberOfOrderPositions: Int {
        return self.getModuleInfo().patternCount
    }
    
    var currentPattern: Int {
        return self.patternNr
    }
    
    var numberOfPatterns: Int {
        return self.getModuleInfo().lengthInPatterns
    }
    
    var currentRow: Int {
        return self.lineInPattern
    }
    
    var timeInSeconds: Int {
        return self.seconds
    }
    

    func initPlayer() {
        var err:OSStatus
        
        self.isValid = true

        //setup queue
        err = initQueue()
        if err != noErr {
            print("Queue init failed. OSStatus \(err)")
            disposePlayer()
            return
        }
        AudioQueueSetParameter(self.audioQueue!, AudioQueueParameterID(kAudioQueueParam_Volume), Float32(volume))

        //setup buffers
        let numberOfBuffers : Int = 3
        for i in 0 ..< numberOfBuffers {
            err = allocBuffer(buffer:i)
            if err != noErr {
                print("Buffer Alloc failed. OSStatus \(err)")
                disposePlayer()
                return
            }
        }
    }
    
    func pause() {
        let status = AudioQueuePause(self.audioQueue!)
        if status != noErr {
            audioQueueError(msg: "Pause failed: \(status)")
        }
    }
    func resume() {
        let status = AudioQueueStart(self.audioQueue!, nil)
        if status != noErr {
            audioQueueError(msg: "Unpause failed: \(status)")
        }
    }
    
     func play() -> Bool {
        xmp_restart_module(context)
        let start = xmp_start_player(context, 44100, 0)
        if start != 0 {
            return false
        }
        
        //enqueue data
        for i in 0 ..< audioQueueBuffers.count {
            let xmpStatus = primeFrame(buffer:i)
            if xmpStatus != 0 {
                print("Prime frames failed. xmp_status \(xmpStatus)")
                return false
            }
        }
        let status = AudioQueueStart(self.audioQueue!, nil)
        if status == 0 {
            self.isRunning = true
        }
        
        return true
    }
    
    func stop() {
        xmp_stop_module(context)
    }
    

}


extension XMP_AudioPlayer {
    func initQueue( ) -> OSStatus {
        var status : OSStatus = 0
        let statePtr = Unmanaged.passUnretained(self as AnyObject).toOpaque()

        status = AudioQueueNewOutput(&self.audioDescription, { (inUserData, inAQ, inBuffer) in
            if let selfPoint = UnsafeRawPointer.init(inUserData) {
                let sself = Unmanaged<XMP_AudioPlayer>.fromOpaque(selfPoint).takeUnretainedValue()
                
                sself.audioQueueOutputCallback(inAQ: inAQ, inBuffer: inBuffer)
            }

        }, statePtr, nil, nil, 0, &self.audioQueue)
        
        if (status == noErr) {
            status = AudioQueueAddPropertyListener(self.audioQueue!, kAudioQueueProperty_IsRunning, { (inUserData, inAQ, inID) in
                var running : Int32 = 0
                var psize : UInt32 = 0
                
                //send notification if queue has finished
                if (inID == kAudioQueueProperty_IsRunning) {
                    var status = AudioQueueGetPropertySize(inAQ, kAudioQueueProperty_IsRunning, &psize)
                    status = AudioQueueGetProperty(inAQ, kAudioQueueProperty_IsRunning, &running, &psize);
                    if (status == noErr) {
                        if (0 == running) {
                            if let selfPoint = UnsafeRawPointer.init(inUserData) {
                                let sself = Unmanaged<XMP_AudioPlayer>.fromOpaque(selfPoint).takeUnretainedValue()

                                sself.notifySongFinished();
                            }
                        }
                    } else {
                        print("Failed getting kAudioQueueProperty_IsRunning. OSStatus=\(status)");
                    }
                }
            }, statePtr)
        }
        return status
    }

    func allocBuffer( buffer : Int ) -> OSStatus {
        var buffer:AudioQueueBufferRef?
        let rc =  AudioQueueAllocateBuffer(self.audioQueue!, bufferSize, &buffer);
        if rc == noErr {
            self.audioQueueBuffers.append( buffer!)
        }
        return rc
    }

    // MARK: CoreAudio C Callback functions and helpers
    func audioQueueOutputCallback(inAQ:AudioQueueRef, inBuffer:AudioQueueBufferRef) {
        if self.isRunning == false {
            return;
        }
        
        if queueFrame(inAQ: inAQ, inBuffer:inBuffer) == 0 {
            AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, nil)
        } else {
            //nothing else to read
            self.isRunning = false
            let status = AudioQueueStop(self.audioQueue!, false)
            if status != noErr {
                print("audioQueueOutputCallback() stop failed. OSStatus=\(status)")
            }
        }
    }

    func primeFrame( buffer : Int ) -> Int32 {
        var status : OSStatus = 0
        
        let inAQ = self.audioQueue!
        let inBuffer = self.audioQueueBuffers[buffer]
        
        let frame_status = queueFrame(inAQ:inAQ, inBuffer:inBuffer)
        if 0 == frame_status {
            status = AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, nil)
            if status != noErr {
                print("Failed to enqueue buffer in prime_frame. OSSStatus=\(status)")
            }
        }
        return frame_status;
    }

    func queueFrame( inAQ :AudioQueueRef , inBuffer : AudioQueueBufferRef ) -> Int32 {
        var fi = xmp_frame_info()
        
        
        let frame_status = xmp_play_frame(self.context)
        if frame_status == 0 {
            xmp_get_frame_info(self.context, &fi)
            if fi.loop_count != 0 {
                if self.getModuleInfo().restartPosition >= 127 {
                    return XMP_END
                }
            }
            memcpy(inBuffer.pointee.mAudioData, fi.buffer, Int(fi.buffer_size))
            inBuffer.pointee.mAudioDataByteSize = UInt32(fi.buffer_size)

            if (self.isRunning) {
                if self.lineInPattern != fi.row {
                    self.lineInPattern = Int(fi.row)
                    notifyPositionChange(pos:self.lineInPattern)
                }
                
                if (fi.pos != self.position) {
                    self.patternNr = Int(fi.pattern)
                    self.position = Int(fi.pos)
                    
                    notifyPatternChange(dict:["pattern":self.patternNr, "position" : self.position])
                }
                let seconds = fi.time / 1000;
                if (seconds != self.seconds) {
                    self.seconds = Int(seconds)
                    notifyTimeChange(time:self.seconds)
                }
            }
            
        } else {
            print("no frame. status=\(frame_status)\n");
        }
        return frame_status;
        
    }

    // MARK: Notifications
    func notifyPatternChange(dict : [String:Int]) {
        send_notification(name:NSNotification.Name.patternChanged, obj:dict)
    }

    func notifyPositionChange(pos : Int) {
        send_notification(name:NSNotification.Name.positionChanged, obj:pos)
    }

    func notifySongFinished() {
        send_notification(name:NSNotification.Name.queueFinished, obj:nil)
    }

    func notifyTimeChange( time : Int ) {
        send_notification(name:NSNotification.Name.timeChanged, obj:time);
    }


    func send_notification( name : NSNotification.Name, obj : Any?) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: name, object: obj)
        }
    }
}
