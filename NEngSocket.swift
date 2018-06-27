//
//  NEngSocket.swift
//  NEngSocketConnection
//
//  Created by Nadeeshan on 6/25/18.
//  Copyright © 2018 NEngineering. All rights reserved.
//

import UIKit
import SystemConfiguration

class NEngSocket: NSObject {
    fileprivate var inputStream:InputStream = InputStream()
    fileprivate var outputStream:OutputStream = OutputStream()
    fileprivate var buffer = [UInt8](repeating: 0, count: 1024)
    
    /*
     *  Notified through the listener when the respond is receved.
     */
    fileprivate func readSocketConnection(stream: InputStream) throws -> Any {
        while stream.hasBytesAvailable {
            stream.read(&buffer, maxLength: buffer.count)
            let source = String(bytes: buffer, encoding: String.Encoding.utf8)
            buffer = [UInt8](repeating: 0, count: 1024)
            return source!
        }
        return NSNull()
    }
    
    /*
     *  Terminate Socket Connection
     */
    fileprivate func terminateSocketConnection() {
        inputStream.close()
        inputStream.remove(from: RunLoop.current, forMode: .defaultRunLoopMode)
        outputStream.close()
        outputStream.remove(from: RunLoop.current, forMode: .defaultRunLoopMode)
        print("Host connection terminated")
    }
    
    /*
     *  Initiate a Socket Connection
     */
    fileprivate func setSocketConnection(host:CFString, port:uint) throws {
        var readStream :Unmanaged<CFReadStream>?;
        var writeStream:Unmanaged<CFWriteStream>?;
        CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault, host as CFString, port, &readStream, &writeStream)
        
        inputStream = readStream!.takeRetainedValue()
        inputStream.schedule(in: RunLoop.current, forMode:.defaultRunLoopMode)
        inputStream.open()
        
        outputStream = writeStream!.takeRetainedValue()
        outputStream.schedule(in:RunLoop.current, forMode:.defaultRunLoopMode)
        outputStream.open()
    }
}

class NEngSocketConnection: NSObject {
    
    private let socket: NEngSocket = NEngSocket()
    
    private var SERVER_TIMEOUT: NSInteger = 0
    private var tHost: String = String()
    private var tPort: uint = 0
    private var isConnectionEstabilish = false
    private var socketResponse :Any!
    private let group = DispatchGroup()
    private var isDispatchGroupEnter = false
    private let timer = Timer()
    
    init(host: String, port: uint, timeout: NSInteger) {
        super.init()
        tHost = host
        tPort = port
        SERVER_TIMEOUT = timeout
    }
    
    /*
     *  Send a packet to the host server using Socket Connection
     */
    public func sendMessageWithCompletion(request: String, completion: @escaping (_ result: Any, _ error: NSError) -> Void) {
        var error = NSError(domain: "Socket Connection Error", code: 0, userInfo: nil)
        
        do {
            try self.socket.setSocketConnection(host: tHost as CFString, port: tPort)
            self.socket.inputStream.delegate = self
            self.socket.outputStream.delegate = self
        } catch {
            print("Error: \(error.localizedDescription)")
            return
        }
        
        if self.networkReachability() {
            let sendData = [UInt8](request.utf8)
            let byteResource = sendData
            group.enter()
            isDispatchGroupEnter = true
            let timeout = DispatchWorkItem {
                self.socket.terminateSocketConnection()
                error = NSError(domain: "Socket Connection Error", code: 408, userInfo: [NSLocalizedDescriptionKey : "Server request timed out"])
                completion(NSNull(),error)
                return
            }
            DispatchQueue.main.asyncAfter(deadline: DispatchTime(uptimeNanoseconds: (DispatchTime.now().uptimeNanoseconds + UInt64(SERVER_TIMEOUT * 1000000))), execute: timeout)
            self.socket.outputStream.write(byteResource, maxLength: byteResource.count)
            group.notify(queue: .main) {
                if self.isConnectionEstabilish {
                    completion(self.socketResponse, error)
                    timeout.cancel()
                    return
                }
                error = NSError(domain: "Socket Connection Error", code: 503, userInfo: [NSLocalizedDescriptionKey : "Service connection refused"])
                completion(NSNull(),error)
                timeout.cancel()
                return
            }
        } else {
            self.socket.terminateSocketConnection()
            error = NSError(domain: "Socket Connection Error", code: 404, userInfo: [NSLocalizedDescriptionKey : "Network is unreachable"])
            completion(NSNull(),error)
            return
        }
    }
}

extension NEngSocketConnection: StreamDelegate {
    
    /*
     *  Server listener delegate method
     */
    internal func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case Stream.Event.openCompleted:
            print("Host Status: Host connection established")
            break
        case Stream.Event.hasBytesAvailable:
            self.socketResponse = try? self.socket.readSocketConnection(stream: self.socket.inputStream)
            if self.socketResponse != nil {
                self.isConnectionEstabilish = true;
                print("Host Status: Host has Bytes Available")
            }
            if isDispatchGroupEnter {
                self.socket.terminateSocketConnection()
                self.isDispatchGroupEnter = false
                self.group.leave()
            }
            break
        case Stream.Event.errorOccurred:
            self.socketResponse = nil
            self.isConnectionEstabilish = false;
            if isDispatchGroupEnter {
                self.socket.terminateSocketConnection()
                self.isDispatchGroupEnter = false
                self.group.leave()
            }
            break
        case Stream.Event.endEncountered:
            print("Host Status: End of the Stream")
            break
        default:
            break
        }
    }
}



@objc protocol NEngWebSocketDelegate {
    @objc optional func stream(_ aStream: Stream, handle eventCode: Stream.Event)
}

class NEngWebSocketConnection: NSObject {
    
    private let socket: NEngSocket = NEngSocket()
    
    private let stream: Stream = Stream()
    var delegate: NEngWebSocketDelegate?
    
    init(host: String, port: uint) {
        super.init()
        do {
             try self.socket.setSocketConnection(host: host as CFString, port: port)
             self.socket.inputStream.delegate = self
             self.socket.outputStream.delegate = self
        } catch {
             print("Error: \(error.localizedDescription)")
        }
    }
    
    /*
     *  Send a packet to the host server using Web Socket Connection
     */
    public func sendMessage(request: String) throws {
        if self.networkReachability() {
            let sendData = [UInt8](request.utf8)
            let byteResource = sendData
            if 0 > self.socket.outputStream.write(byteResource, maxLength: byteResource.count) {
                let error: Error = self.socket.outputStream.streamError!
                throw error
            }
        } else {
            self.socket.terminateSocketConnection()
            let error = NSError(domain: "Socket Connection Error", code: 404, userInfo: [NSLocalizedDescriptionKey : "Network is unreachable"])
            throw error
        }
    }
    
    /*
     *  Defining public access to the read Socket Connection functions
     */
    public func readSocketConnection(stream: InputStream) throws -> Any {
        return try self.socket.readSocketConnection(stream: stream)
    }
    
    /*
     *  Defining public access to the Terminate Socket Connection functions
     */
    public func terminateSocketConnection() {
        self.socket.terminateSocketConnection()
    }
    
    /*
     *  Defining public access to the inputStream param
     */
    public func inputStream() -> InputStream {
        return self.socket.inputStream
    }
}

extension NEngWebSocketConnection: StreamDelegate {
    
    /*
     *  Server listener delegate method
     */
    internal func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        delegate?.stream!(aStream, handle: eventCode)
    }
}

extension NSObject {
    /*
     *  Check device Network Reachability of 3G/4G/Wi-fi
     */
    func networkReachability() -> Bool {
        var zeroAddress = sockaddr_in(sin_len: 0, sin_family: 0, sin_port: 0, sin_addr: in_addr(s_addr: 0), sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
        zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        let defaultRouteReachability = withUnsafePointer(to: &zeroAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {zeroSockAddress in
                SCNetworkReachabilityCreateWithAddress(nil, zeroSockAddress)
            }
        }
        
        var flags: SCNetworkReachabilityFlags = SCNetworkReachabilityFlags(rawValue: 0)
        if SCNetworkReachabilityGetFlags(defaultRouteReachability!, &flags) == false {
            return false
        }
        
        let isReachable = (flags.rawValue & UInt32(kSCNetworkFlagsReachable)) != 0
        let needsConnection = (flags.rawValue & UInt32(kSCNetworkFlagsConnectionRequired)) != 0
        return (isReachable && !needsConnection)
    }
}
