//
//  ViewController.swift
//  ModPlayer
//
//  Created by Andy Qua on 13/11/2019.
//  Copyright © 2019 Andy Qua. All rights reserved.
//

class ColorHighlightButton : UIButton {
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder:aDecoder)
        
        setBackgroundColor(color: .lightGray, forState: .highlighted)
    }
    
    /// Sets the background color to use for the specified button state.
    func setBackgroundColor(color: UIColor, forState: UIControl.State) {
        
        let minimumSize: CGSize = CGSize(width: 1.0, height: 1.0)
        
        UIGraphicsBeginImageContext(minimumSize)
        
        if let context = UIGraphicsGetCurrentContext() {
            context.setFillColor(color.cgColor)
            context.fill(CGRect(origin: .zero, size: minimumSize))
        }
        
        let colorImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        self.clipsToBounds = true
        self.setBackgroundImage(colorImage, for: forState)
    }
}

import UIKit

class ViewController: UIViewController {
    @IBOutlet weak var trackView: TrackView!
    @IBOutlet weak var trackNameLabel: UILabel!
    @IBOutlet weak var positionLabel: UILabel!
    @IBOutlet weak var patternLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var ejectBtn: UIButton!

    var player : MusicPlayer!

    var currentPattern : [String] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        self.player = MusicPlayer(volume: 1.0)
        
        trackView.muteTrack = { [unowned self] (trackNr, shouldMute) in
            self.player.muteTrack(trackNr: trackNr, shouldMute: shouldMute)
        }
                
        NotificationCenter.default.addObserver(forName: NSNotification.Name.positionChanged, object: nil, queue: OperationQueue.main) {[weak self] note in
            
            guard let pos = note.object as? Int32 else { return }

            let seconds = self?.player.seconds ?? 0
            let time = String(format: "%02d:%02d", seconds / 60, seconds % 60)

            self?.timeLabel.text = time
//            print( "AP: pos- \(position), patternNr- \(patternNr), lineInPattern- \(lineInPattern), seconds- \(seconds)" )
            self?.trackView.pos = CGFloat(pos)

            self?.trackView.setNeedsDisplay()
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name.patternChanged, object: nil, queue: OperationQueue.main) { [weak self] note in
            
            guard let dict = note.object as? [String:Int] else { return }
            guard let modInfo = self?.player.moduleInfo      else { return }
            
            
            let position = dict["position"] ?? 0
            let patternNr = dict["pattern"] ?? 0

            let nrPositions = modInfo.lengthInPatterns - 1
            self?.positionLabel.text = String(format:"%03d/%03d", position, nrPositions)
            self?.patternLabel.text = String(format:"Pattern: %03d", patternNr)
            
            self?.trackView.pattern = self?.player.moduleInfo?.patterns[patternNr] ?? []
            self?.trackView.setNeedsDisplay()
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name.stateChanged, object: nil, queue: OperationQueue.main) { [weak self] note in
            
            guard let state = note.object as? PlayerState else { return }
            
            self?.trackView.isPlaying = state == .Playing
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController?.isNavigationBarHidden = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        self.navigationController?.isNavigationBarHidden = false
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let vc = segue.destination as? FileChooserViewController {
            vc.selectedFile = { [unowned self] file in
                self.navigationController?.popViewController(animated: true)
//                self.dismiss(animated: true, completion: nil)
                _ = self.player!.load(url:file)
                
                self.trackNameLabel.text = self.player.moduleInfo?.name ?? ""
                let nrChannels = self.player.moduleInfo?.channelCount ?? 0
                self.trackView.updateNrChannels( nrChannels )
                self.trackView.setNeedsDisplay()
            }
        }
    }
    
    @IBAction func eject( _ sender : Any ) {
        self.player?.stop()
        
        // Display Track Selector
        self.performSegue(withIdentifier: "ShowFileSelect", sender: self)
        
    }
    @IBAction func play( _ sender : Any ) {
        self.player.play()
    }
    @IBAction func stop( _ sender : Any ) {
        self.player.stop()
    }
    @IBAction func pause( _ sender : Any ) {
        self.player.pause()
    }
    @IBAction func nextPattern( _ sender : Any ) {
        self.player.nextPosition()
    }
    @IBAction func prevPattern( _ sender : Any ) {
        self.player.previousPosition()
    }
}

