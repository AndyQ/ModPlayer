//
//  ModPlayerConfig.swift
//  ModPlayer
//
//  Created by Andy Qua on 13/11/2019.
//  Copyright © 2019 Andy Qua. All rights reserved.
//

import Foundation

extension Notification.Name {
    static let songChanged = Notification.Name("SongChanged")
    static let patternChanged = Notification.Name("PatternChanged")
    static let positionChanged = Notification.Name("PositionChanged")
    static let timeChanged = Notification.Name("TimeChanged")
    static let songFinished = Notification.Name("SongFinished")
    static let queueFinished = Notification.Name("QueueFinished")
    static let playListChanged = Notification.Name("playListChanged")
    static let playAtIndex = Notification.Name("playAtIndex")
    static let stateChanged = Notification.Name("stateChanged")
}
