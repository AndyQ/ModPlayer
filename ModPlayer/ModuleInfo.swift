//
//  ModuleInfo.swift
//  ModPlayer
//
//  Created by Andy Qua on 13/11/2019.
//  Copyright © 2019 Andy Qua. All rights reserved.
//
import Foundation


struct ModuleInfo {
    var comment : String = ""
    let volumeBase : Int
    let sequenceCount : Int
    let md5 : String
    
    let name : String
    let format : String

    let patternCount : Int
    let channelCount : Int
    let instrumentCount : Int
    let sampleCount : Int
    
    let initialSpeed : Int
    let initialBPM : Int
    let lengthInPatterns : Int
    let restartPosition : Int
    let globalVolume : Int
    
    let duration : Int
    let durationSeconds : Int
    
    var patterns : [[String]]
    
    private let modInfo : xmp_module_info
    private let notes = ["C ", "C#", "D ", "D#", "E ", "F ", "F#", "G ", "G#", "A ", "A#", "B "]

    init(info:xmp_module_info) {
        self.modInfo = info
        if let comment = info.comment {
            self.comment = String(cString:comment)
        }
        self.volumeBase = Int(info.vol_base)
        self.sequenceCount = Int(info.num_sequences)
        self.md5 = md5UInt8ToString(tuple: info.md5)
        
        let mod = info.mod.pointee
        
        self.name = int8TupleToString(tuple: mod.name)
        self.format = int8TupleToString(tuple: mod.type)
        
        self.patternCount = Int(mod.pat)
        self.channelCount =  Int(mod.chn)
        self.instrumentCount =  Int(mod.ins)
        self.sampleCount =  Int(mod.smp)
        self.initialSpeed =  Int(mod.spd)
        self.initialBPM =  Int(mod.bpm)
        self.lengthInPatterns = Int(mod.len) - 1
        self.restartPosition = Int(mod.rst)
        self.globalVolume =  Int(mod.gvl)
        
        let seq = info.seq_data
        self.duration = Int(seq?.pointee.duration ?? 0)  //
        self.durationSeconds = self.duration / 1000

        patterns = [[String]]()
        for i in 0 ..< self.patternCount {
            patterns.append( getPattern(patternNr: i) )
        }
    }
    
    private func getPattern(patternNr : Int ) -> [String] {
        
        guard let nrRows = modInfo.mod.pointee.xxp[patternNr]?.pointee.rows else { return [] }
        var ret = [String]()
        for row in 0 ..< Int(nrRows) {
            let line = getPatternForTrack( modInfo:modInfo , patternNr : patternNr, trackNr: row )
            
            ret.append(line)
        }
        return ret
    }
    
    private func getPatternForTrack( modInfo:xmp_module_info, patternNr : Int, trackNr: Int ) -> String {
        var line = String(format:"%02x|", trackNr)
        
        let xxp = modInfo.mod.pointee.xxp[patternNr]

        withUnsafePointer(to:&xxp!.pointee.index) { (trkPtr) in
            for chn in 0 ..< modInfo.mod.pointee.chn {
                let trk = trkPtr.advanced(by: Int(chn)).pointee

                let xxt = modInfo.mod.pointee.xxt![Int(trk)]
                withUnsafePointer(to:&xxt!.pointee.event) { (evtPtr) in
                    //                let evtPtr = UnsafePointer<xmp_event>(&xxt!.pointee.event)
                    let event = evtPtr.advanced(by: trackNr).pointee
                    
                    var note = ""
                    if ( event.note == 0 ) {
                        note = "---"
                    } else if ( event.note > 128 ) {
                        note = "==="
                    } else {
                        let n = (event.note - 1) % 12;
                        let o = (event.note - 1) / 12;
                        note = "\(notes[Int(n)])\(o)"
                    }
                    
                    let ins = event.ins == 0 ? "--" : String(format:"%02x", event.ins )
                    let vol = event.vol == 0 ? "--" : String(format:"%02x", event.vol )
                    var fx = " ---"
                    if event.fxt != 0 {
                        var format = " %x%02x"
                        if event.fxt > 0x0f {
                            format = "%02x%02x"
                        }
                        fx = String(format:format, event.fxt, event.fxp )
                    }
                    
                    line += "\(note) \(ins) \(vol)\(fx)|"
                }
            }
        }
            
        return line
    }
    
    func patternInOrder( for position : Int ) -> Int {
        var xxo = modInfo.mod.pointee.xxo
        let xxo_lookup = withUnsafeMutablePointer(to: &xxo) { $0.withMemoryRebound(to: UInt8.self, capacity: 256) { $0 } }
        
        return Int(xxo_lookup[position])
    }
}
