# NEngSocket Connection

NEngSocket is a custom class that Design to commentate with a host server using host IP address and port based on TCP server connection. This class have two separates methods to communicate with the server. Class is based on Swift language and require both UIKit and SystemConfiguration frameworks for function the functionalities.


Testing NEngSocket example:

To test the example file of NEngSocketConnection_Example project, you can use netcat local host utility. The netcat utility is used for just about anything under the sun involving TCP or UDP. It can open TCP connections, send UDP packets, listen on arbitrary TCP and UDP ports, do port scanning, and deal with both IPv4 and IPv6. Unlike telnet, nc scripts nicely, and separates error messages onto standard error instead of sending them to standard output, as telnet does with some.

        1. Launch terminal form the Launchpad in your mac.

        2. Type "nc -vl 127.0.0.1 8080" on the terminal window and hit enter.


To use NEngSocketConnection in your project, please follow following steps

1. Add (or Drag and drop to Your project in Xcode) NEngSocket.swift files to your project

2. Declare and initialize an NEngSocketConnection class instance with a "host", "port" and "timeout" in your ViewController class
       Ex:
       
          // Create an instance of NEngSocketConnection class
          var socket: NEngSocketConnection = NEngSocketConnection(host: "localhost", port: 8080, timeout: 30000)

3. Use "sendMessageWithCompletion" public function to send message to server with completion handler

	Ex:
      
          // Using NEngSocketConnection to send message to server with completion
          NEngSocketConnection(host: "localhost", port: 8080, timeout: 30000).sendMessageWithCompletion(request: "Hi Server") {
          (result: Any, error: NSError) in
          
              // Respond: "result" (Any) is the respond that receive from the server
              print(result)
          
              // Error: "error" (NSError) is the exception that receive while Socket Connection crash
              switch error.code {
                  case 404:
                    print("Error: \(error.localizedDescription). Please try again.")
                  break
                  
                  case 408:
                    print("Error: \(error.localizedDescription). Please try again.")
                  break
                  
                  case 503:
                    print("Error: \(error.localizedDescription). Please try again.")
                  break
                  
                  default: break
              }
          }


To use NEngWebSocketConnection in your project, please follow following steps
          
1. Add (or Drag and drop to Your project in Xcode) NEngSocket.swift files to your project

2. Add NEngWebSocketDelegate to your ViewController class
        Ex:

            // Add NEngWebSocketDelegate to ViewController
            class ViewController: UIViewController, NEngWebSocketDelegate

3. Declare and initialize an NEngWebSocketConnection class instance with a "host" and "port" in your ViewController class
          Ex:
          
            // Creating an instance of NEngWebSocketConnection with host and port info
            var socket: NEngWebSocketConnection = NEngWebSocketConnection(host: "localhost", port: 8080)

4. Assign NEngWebSocketDelegate to instance

            override func viewDidLoad() {
            super.viewDidLoad()

                 // Assigning NEngWebSocketDelegate to NEngWebSocketConnection instance so the new instance can access NEngWebSocketDelegate public functions
                 self.socket.delegate = self
            }
        
5. Add NEngWebSocketDelegate functions into your ViewController calss so you can use your NEngWebSocketConnection instance to communicate with your host
        
            func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
                switch eventCode {
                    case Stream.Event.openCompleted:
                        print("Host Status: Host connection established")
                    break
                    
                    case Stream.Event.hasBytesAvailable:
                        // Read socket respond that send by the server
                        let socketResponse = try? socket.readSocketConnection(stream: socket.inputStream())
                        if socketResponse != nil {
                            print("Host Status: Host has Bytes Available")
                            print("respond from server (Web Socket) : \(String(describing: socketResponse!))")
                        }
                    break
                    
                    case Stream.Event.errorOccurred:
                        print("Host Status: Error Occurred")
                        socket.terminateSocketConnection()
                    break
                    
                    case Stream.Event.endEncountered:
                        print("Host Status: End of the Stream")
                    break
                    
                    default:
                    break
                }
            }


Created by Nadeeshan Jayawardana (NEngineering).
