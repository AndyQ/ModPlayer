//
//  TrackView.swift
//  ModPlayer
//
//  Created by Andy Qua on 17/11/2019.
//  Copyright © 2019 Andy Qua. All rights reserved.
//

import UIKit
import CoreGraphics

class TrackView : UIView {
    
    var muteTrack : ((Int, Bool) ->())?

    @IBOutlet weak var widthConstraint: NSLayoutConstraint!
    
    var isPlaying : Bool = false
    var pos : CGFloat = 0
    var pattern : [String] = []
    private var trackLength : CGSize = .zero
    
    private var sampleTrack : String = ""
    private var displayFont : UIFont = UIFont.monospacedSystemFont(ofSize: 9, weight:.regular)
    private var buttons = [UIButton]()
    private var nrChannels : Int = 0
    

    private var startDragX : CGFloat = 0
    private var startDragY : CGFloat = 0
    private var startDrag : CGPoint = .zero
    private var origPos : CGFloat = 0

    required init?(coder aDecoder: NSCoder) {
        super.init(coder:aDecoder)
        
        self.layer.cornerRadius = 5
        self.isUserInteractionEnabled = true
        
        let gr = UIPanGestureRecognizer(target: self, action: #selector(dragged(_:)))
        self.addGestureRecognizer(gr)
    }
    
    override func layoutSubviews() {
        if sampleTrack != "" {
            adjustFont()
            updateMuteButtons()
        }

        self.setNeedsDisplay()
    }
    
    @objc func dragged( _ gr : UIPanGestureRecognizer ) {
        let p = gr.location(in: self)
        if gr.state == .began {
            startDragX = p.x
            startDragY = p.y
            origPos = pos
        } else {
            let dy = p.y - startDragY
            let dx = p.x - startDragX
            if !isPlaying {
                pos = origPos - dy/5
                if pos < 0 {
                    pos = 0
                } else if pos > 63 {
                    pos = 63
                }
            }
            
            let sv = self.superview as! UIScrollView
            var newOffset = sv.contentOffset.x - dx
            if newOffset < 0 {
                newOffset = 0
            } else if newOffset > self.bounds.size.width - sv.bounds.size.width {
                newOffset = self.bounds.size.width - sv.bounds.size.width
            }
            sv.contentOffset.x = newOffset
            self.setNeedsDisplay()
        }
    }
    
    func updateNrChannels( _ nrChannels: Int ) {
        self.nrChannels = nrChannels
        updateMuteButtons()
        
    }
    
    func updateMuteButtons() {
        // Generate dummy track
        sampleTrack = "--|" + String( repeating: "--- -- -- ---|", count:nrChannels )
        adjustFont()

        // remove all existing buttons from view
        buttons.forEach { $0.removeFromSuperview() }
        buttons.removeAll()
        
        let singleTrack = "--- -- -- ---|"
        let attributes = [
            NSAttributedString.Key.font: self.displayFont,
            NSAttributedString.Key.foregroundColor: UIColor.white,
            NSAttributedString.Key.backgroundColor: UIColor.black,
        ]
        let headerLength = "--|".size(withAttributes: attributes).width
        let singleTrackLength : Int = Int(singleTrack.size(withAttributes: attributes).width)

        var f = CGRect( x:0, y: Int(self.bounds.height - 30), width: singleTrackLength, height: 30)
        for i in 0 ..< nrChannels {
            f.origin.x = headerLength + CGFloat(i * singleTrackLength)
            let b = UIButton( frame:f )
            let title = NSAttributedString(string: "Mute", attributes: attributes)
            b.setAttributedTitle(title, for: .normal)
            self.addSubview(b)
            
            b.addTarget(self, action: #selector(mutePressed(_:)), for: .touchUpInside)
            buttons.append(b)
        }
        
    }
    
    @objc func mutePressed( _ btn : UIButton ) {
        guard let i = buttons.firstIndex(of: btn) else { return }
        
        let attributes = [
            NSAttributedString.Key.font: self.displayFont,
            NSAttributedString.Key.foregroundColor: UIColor.white,
            NSAttributedString.Key.backgroundColor: UIColor.black,
        ]

        guard let attributedTitle = btn.attributedTitle(for: .normal) else { return }
        if attributedTitle.string == "Mute" {
            // Mute track
            let title = NSAttributedString(string: "Un-Mute", attributes: attributes)
            btn.setAttributedTitle(title, for: .normal)
            muteTrack?( i, true )
        } else {
            // Unmute track
            let title = NSAttributedString(string: "Mute", attributes: attributes)
            btn.setAttributedTitle(title, for: .normal)
            muteTrack?( i, false )
        }
    }
    
    func adjustFont() {
        // Find best fit for screen
        var fs : CGFloat = 9
        var fontSize : CGFloat = 9
        
        let screenWidth = self.superview?.bounds.size.width ?? 0
        repeat {
            
            let attributes = [
                NSAttributedString.Key.font: UIFont.monospacedSystemFont(ofSize: fs, weight:.regular),
            ]
            
            let newTrackLength = sampleTrack.size(withAttributes: attributes)
            if newTrackLength.width < screenWidth {
                fontSize = fs
                fs += 0.1
                trackLength = newTrackLength
            } else {
                if fs == 9 {
                    trackLength = newTrackLength
                }
                break
            }
        } while trackLength.width < screenWidth
        
        self.widthConstraint.constant = max(trackLength.width, screenWidth)
        self.displayFont = UIFont.monospacedSystemFont(ofSize: fontSize, weight:.regular)
    }
    
    override func draw(_ rect: CGRect) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        
        let row1 = [NSAttributedString.Key.font: self.displayFont,
                    NSAttributedString.Key.foregroundColor: UIColor.white]
        let row2 = [NSAttributedString.Key.font: self.displayFont,
                    NSAttributedString.Key.foregroundColor: UIColor.yellow]
        
        let attributes = [
            NSAttributedString.Key.font: self.displayFont,
            NSAttributedString.Key.foregroundColor: UIColor.green
        ]
        
        let selattributes = [
            NSAttributedString.Key.font: self.displayFont,
            NSAttributedString.Key.foregroundColor: UIColor.black,
            NSAttributedString.Key.backgroundColor: UIColor.green
        ]
        
        let totalRows = trackLength.height == 0 ? 0 : Int(self.bounds.height/trackLength.height)
        
        let x = (self.bounds.width - trackLength.width)/2
        
        let start = Int(pos) - (totalRows/2)
        let end = Int(pos) + (totalRows/2) + 2
        var y : CGFloat = 0
        for i in start ..< end {
            if i >= 0 && i < pattern.count {
                let attribs = i != Int(pos) ? attributes : selattributes
                let attributedString = NSMutableAttributedString(string: pattern[i], attributes: attribs)
                attributedString.setAttributes(i%2 == 0 ?row1:row2, range: NSRange(location: 0, length: 2))
                
                let p = CGPoint(x: x, y: y )
                attributedString.draw(at: p)
            }
            y += trackLength.height
        }
    }
}
