//
//  WebServer.swift
//  C64Emulator
//
//  Created by Andy Qua on 11/08/2016.
//  Copyright © 2016 Andy Qua. All rights reserved.
//

import UIKit
import GCDWebServers

class ConfirmingGCDUploadServer : GCDWebUploader {
    
    override func shouldDeleteItem(atPath path: String) -> Bool {
        if path.hasSuffix( "data" ) || path.hasSuffix( "main" ) || path.hasSuffix( "private" ) {
            return false
        }
        return true
    }
}

class WebServer : NSObject, GCDWebUploaderDelegate {
    var webServer : GCDWebUploader!

    static let sharedInstance : WebServer = WebServer()

    override init() {
        super.init()
        GCDWebUploader.setLogLevel(5)
        
        let docRoot = documentPath()

        webServer = ConfirmingGCDUploadServer(uploadDirectory: docRoot.path)
        webServer.delegate = self
        webServer.allowHiddenItems = false
    }
    
    func startServer() -> Bool {
        UIApplication.shared.isIdleTimerDisabled = true
        return self.webServer.start(withPort: 8080, bonjourName: "myv")
    }
    
    func stopServer() {
        UIApplication.shared.isIdleTimerDisabled = false
        self.webServer.stop()
    }

    func getServerAddress() -> String {
        if let serverURL = webServer.serverURL {
            return serverURL.absoluteString
        } else {
            return "No Idea"
        }
    }
    
    func bonjourServerURL() -> URL {
        return self.webServer.bonjourServerURL!
    }

    //MARK - Web Server Delegate
    func webUploader(_ uploader: GCDWebUploader, didUploadFileAtPath path: String) {
        print( "[UPLOAD] \(path)")

    }
    func webUploader(_ uploader: GCDWebUploader, didMoveItemFromPath fromPath: String, toPath: String) {
        print( "[MOVE] \(fromPath) -> \(toPath)")
    }
    
    func webUploader(_ uploader: GCDWebUploader, didDeleteItemAtPath path: String) {
        print( "[DELETE] \(path)")
    }
    func webUploader(_ uploader: GCDWebUploader, didDownloadFileAtPath path: String) {
        print( "[DOWNLOAD] \(path)")
    }
    func webUploader(_ uploader: GCDWebUploader, didCreateDirectoryAtPath path: String) {
        print( "[CREATE] \(path)")
    }

}
