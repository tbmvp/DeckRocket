//
//  MultipeerClient.swift
//  DeckRocket
//
//  Created by JP Simard on 6/14/14.
//  Copyright (c) 2014 JP Simard. All rights reserved.
//

import Foundation
import MultipeerConnectivity

typealias stateChange = ((state: MCSessionState, peerID: MCPeerID) -> ())?

final class MultipeerClient: NSObject, MCNearbyServiceBrowserDelegate, MCSessionDelegate {

    // MARK: Properties

    private let localPeerID = MCPeerID(displayName: UIDevice.currentDevice().name)
    let browser: MCNearbyServiceBrowser?
    private(set) var session: MCSession?
    private(set) var state = MCSessionState.NotConnected
    var onStateChange: stateChange?

    // MARK: Init

    override init() {
        browser = MCNearbyServiceBrowser(peer: localPeerID, serviceType: "deckrocket")
        super.init()
        browser?.delegate = self
        browser?.startBrowsingForPeers()
    }

    // MARK: Send

    func send(data: NSData) {
        session?.sendData(data, toPeers: session!.connectedPeers, withMode: .Reliable, error: nil) // Safe to force unwrap
    }

    func sendString(string: NSString) {
        if let stringData = string.dataUsingEncoding(NSUTF8StringEncoding) {
            send(stringData)
        }
    }

    // MARK: MCNearbyServiceBrowserDelegate

    func browser(browser: MCNearbyServiceBrowser!, foundPeer peerID: MCPeerID!, withDiscoveryInfo info: [NSObject : AnyObject]!) {
        if session == nil {
            session = MCSession(peer: localPeerID)
            session?.delegate = self
        }
        browser.invitePeer(peerID, toSession: session, withContext: nil, timeout: 30)
    }

    func browser(browser: MCNearbyServiceBrowser!, lostPeer peerID: MCPeerID!) {

    }

    // MARK: MCSessionDelegate

    func session(session: MCSession!, peer peerID: MCPeerID!, didChangeState state: MCSessionState) {
        self.state = state
        onStateChange??(state: state, peerID: peerID)
    }

    func session(session: MCSession!, didReceiveData data: NSData!, fromPeer peerID: MCPeerID!) {

    }

    func session(session: MCSession!, didReceiveStream stream: NSInputStream!, withName streamName: String!, fromPeer peerID: MCPeerID!) {

    }

    func session(session: MCSession!, didStartReceivingResourceWithName resourceName: String!, fromPeer peerID: MCPeerID!, withProgress progress: NSProgress!) {

    }

    func session(session: MCSession!, didFinishReceivingResourceWithName resourceName: String!, fromPeer peerID: MCPeerID!, atURL localURL: NSURL!, withError error: NSError!) {
        if error == nil {
            if let fileType = FileType(fileExtension: resourceName.pathExtension) {
                switch fileType {
                    case .PDF:
                        handlePDF(resourceName, atURL: localURL)
                    case .Markdown:
                        handleMarkdown(resourceName, atURL: localURL)
                }
            }
        }
    }

    // MARK: Handle Resources

    private func handlePDF(resourceName: String!, atURL localURL: NSURL!) {
        promptToLoadResource("New Presentation File", resourceName: resourceName, atURL: localURL, userDefaultsKey: "pdfName")
    }

    private func handleMarkdown(resourceName: String!, atURL localURL: NSURL!) {
        promptToLoadResource("New Markdown File", resourceName: resourceName, atURL: localURL, userDefaultsKey: "mdName")
    }

    private func promptToLoadResource(title: String, resourceName: String, atURL localURL: NSURL, userDefaultsKey: String) {
        let rootVC = UIApplication.sharedApplication().delegate?.window??.rootViewController as? ViewController

        let alert = UIAlertController(title: title, message: "Would you like to load \"\(resourceName)\"?", preferredStyle: .Alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Load", style: .Default) { action in
            let filePath = documentsPath.stringByAppendingPathComponent(resourceName)
            let fileManager = NSFileManager.defaultManager()

            var error: NSError? = nil
            if fileManager.fileExistsAtPath(filePath) {
                fileManager.removeItemAtPath(filePath, error: &error)
            }

            if let url = NSURL(fileURLWithPath: filePath) where fileManager.moveItemAtURL(localURL, toURL: url, error: &error) {
                NSUserDefaults.standardUserDefaults().setObject(resourceName, forKey: userDefaultsKey)
                NSUserDefaults.standardUserDefaults().synchronize()
                rootVC?.updatePresentation()
            } else {
                let message = error?.localizedDescription ?? "move file failed with no error"
                fatalError(message)
            }
        })
        dispatch_async(dispatch_get_main_queue()) {
            rootVC?.presentViewController(alert, animated: true, completion: nil)
        }
    }
}
