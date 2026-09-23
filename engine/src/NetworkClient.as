package
{
   import flash.events.Event;
   import flash.events.EventDispatcher;
   import flash.events.IOErrorEvent;
   import flash.events.ProgressEvent;
   import flash.events.ServerSocketConnectEvent;
   import flash.net.ServerSocket;
   import flash.net.Socket;
   import flash.utils.ByteArray;
   import flash.utils.Dictionary;
   import flash.utils.Endian;
   import flash.utils.clearTimeout;
   import flash.utils.setTimeout;

   // Peer-to-peer multiplayer client. The host's own game IS the server
   // (flash.net.ServerSocket) - no separate process to install, configure,
   // or remember to start; it only exists while the host's game is open.
   // Guests connect directly to the host's address:port with a plain
   // flash.net.Socket. Frame format on every connection: [1 byte type]
   // [4 byte BE length][payload]. See docs/multiplayer-architecture.md.
   // Owns no game state - the engine hands it a GameType.serialize() blob
   // to publish and gets a raw blob back on NetworkEvent.STATE_RECEIVED,
   // which the caller deserializes.
   public class NetworkClient extends EventDispatcher
   {

      private static const FRAME_JSON:int = 1;

      private static const FRAME_STATE:int = 2;

      private static const HEADER_LEN:int = 5;

      // Time to wait for a TCP connect to succeed at all.
      private static const CONNECT_TIMEOUT_MS:int = 6000;

      // Time to wait, AFTER connecting, for a "welcome"/join-ack frame.
      // A real-world bug (something else already listening on the chosen
      // port, e.g. an unrelated local server) let TCP connect succeed
      // while the peer never spoke our protocol at all - the connect
      // timeout alone never caught that, since it only guards the
      // connect step. This catches "connected but nothing legitimate is
      // on the other end" too.
      private static const HANDSHAKE_TIMEOUT_MS:int = 6000;

      private static var _instance:NetworkClient;

      public static function get instance() : NetworkClient
      {
         if(_instance == null)
         {
            _instance = new NetworkClient();
         }
         return _instance;
      }

      // Host role.
      private var serverSocket:ServerSocket;

      private var guestSockets:Dictionary;

      // Shared by both roles: every open socket (host's per-guest sockets,
      // or the guest's single connection to the host) gets its own
      // receive buffer, since TCP framing must never mix bytes from two
      // different connections.
      private var recvBuffers:Dictionary;

      // Guest role.
      private var clientSocket:Socket;

      private var connectTimeoutId:uint = 0;

      private var handshakeTimeoutId:uint = 0;

      private var _isNetworked:Boolean = false;

      private var _mySlots:Array = [];

      private var _isHost:Boolean = false;

      public function get isNetworked() : Boolean
      {
         return _isNetworked;
      }

      // The host is the single client authoritative for opponent AI and
      // end-of-round bookkeeping; see docs/multiplayer-architecture.md.
      // Guests only ever act during their own player-turn slot.
      public function get isHost() : Boolean
      {
         return _isHost;
      }

      public function get mySlots() : Array
      {
         return _mySlots;
      }

      public function NetworkClient()
      {
         super();
         guestSockets = new Dictionary();
         recvBuffers = new Dictionary();
      }

      // Starts listening directly for guest connections on `port` - the
      // host's own game process is the server. Share this machine's IP
      // address (LAN: shown by e.g. `ipconfig`; over the internet: the
      // router's WAN IP with `port` forwarded to this machine) and `port`
      // with whoever is joining. Fires NetworkEvent.ROOM_READY once
      // listening starts, or NetworkEvent.ERROR if the port can't be
      // bound (e.g. already in use by something else).
      public function hostGame(port:int, slot:int) : void
      {
         _mySlots = [slot];
         _isHost = true;
         serverSocket = new ServerSocket();
         serverSocket.addEventListener(ServerSocketConnectEvent.CONNECT,onGuestConnect);
         serverSocket.addEventListener(IOErrorEvent.IO_ERROR,onServerSocketError);
         try
         {
            serverSocket.bind(port);
            serverSocket.listen();
            _isNetworked = true;
            dispatchEvent(new NetworkEvent(NetworkEvent.ROOM_READY,null,{"port":port}));
         }
         catch(e:Error)
         {
            _isNetworked = false;
            dispatchEvent(new NetworkEvent(NetworkEvent.ERROR,null,{"message":"Could not start hosting on port " + port + ": " + e.message + ". Something else may already be using that port - try a different one."}));
         }
      }

      private function onServerSocketError(e:IOErrorEvent) : void
      {
         _isNetworked = false;
         dispatchEvent(new NetworkEvent(NetworkEvent.ERROR,null,{"message":"Hosting failed: " + e.text}));
      }

      private function onGuestConnect(e:ServerSocketConnectEvent) : void
      {
         var guest:Socket = e.socket;
         recvBuffers[guest] = new ByteArray();
         guest.addEventListener(ProgressEvent.SOCKET_DATA,onSocketData);
         guest.addEventListener(IOErrorEvent.IO_ERROR,onGuestDisconnect);
         guest.addEventListener(Event.CLOSE,onGuestDisconnect);
      }

      private function onGuestDisconnect(e:Event) : void
      {
         var guest:Socket = e.currentTarget as Socket;
         delete recvBuffers[guest];
         var slot:String;
         for(slot in guestSockets)
         {
            if(guestSockets[slot] === guest)
            {
               delete guestSockets[slot];
            }
         }
      }

      // Connects directly to whoever is hosting - no intermediary.
      public function joinGame(hostAddress:String, port:int, slot:int) : void
      {
         _mySlots = [slot];
         _isHost = false;
         clientSocket = new Socket();
         recvBuffers[clientSocket] = new ByteArray();
         clientSocket.addEventListener(Event.CONNECT,function(e:Event) : void
         {
            clearConnectTimeout();
            sendControlOn(clientSocket,{
               "type":"join",
               "slot":slot
            });
            armHandshakeTimeout(hostAddress,port);
         });
         clientSocket.addEventListener(ProgressEvent.SOCKET_DATA,onSocketData);
         clientSocket.addEventListener(IOErrorEvent.IO_ERROR,onClientSocketError);
         clientSocket.connect(hostAddress,port);
         connectTimeoutId = setTimeout(function() : void
         {
            connectTimeoutId = 0;
            if(clientSocket != null && clientSocket.connected)
            {
               return;
            }
            if(clientSocket != null)
            {
               clientSocket.close();
            }
            dispatchEvent(new NetworkEvent(NetworkEvent.ERROR,null,{"message":"Could not connect to " + hostAddress + ":" + port + " within " + (CONNECT_TIMEOUT_MS / 1000) + "s. Is the host's game running and reachable at that address/port?"}));
         },CONNECT_TIMEOUT_MS);
      }

      private function armHandshakeTimeout(hostAddress:String, port:int) : void
      {
         handshakeTimeoutId = setTimeout(function() : void
         {
            handshakeTimeoutId = 0;
            if(_isNetworked)
            {
               return;
            }
            if(clientSocket != null)
            {
               clientSocket.close();
            }
            dispatchEvent(new NetworkEvent(NetworkEvent.ERROR,null,{"message":"Connected to " + hostAddress + ":" + port + " but got no reply within " + (HANDSHAKE_TIMEOUT_MS / 1000) + "s. Something else is likely using that port - it isn't a Gazillionaire host."}));
         },HANDSHAKE_TIMEOUT_MS);
      }

      private function clearHandshakeTimeout() : void
      {
         if(handshakeTimeoutId != 0)
         {
            clearTimeout(handshakeTimeoutId);
            handshakeTimeoutId = 0;
         }
      }

      public function disconnect() : void
      {
         clearConnectTimeout();
         clearHandshakeTimeout();
         if(serverSocket != null)
         {
            try
            {
               serverSocket.close();
            }
            catch(e:Error)
            {
            }
            serverSocket = null;
         }
         if(clientSocket != null && clientSocket.connected)
         {
            clientSocket.close();
         }
         var slot:String;
         for(slot in guestSockets)
         {
            try
            {
               Socket(guestSockets[slot]).close();
            }
            catch(e:Error)
            {
            }
         }
         guestSockets = new Dictionary();
         recvBuffers = new Dictionary();
         _isNetworked = false;
         _isHost = false;
      }

      // Called once a network-controlled player's turn finishes. Host:
      // broadcasts to every connected guest (each guest self-filters by
      // checking g.player against its own mySlots, same as before - the
      // host doesn't need to target a specific connection). Guest: sends
      // to the host, its only connection.
      public function publishTurn(state:ByteArray) : void
      {
         if(_isHost)
         {
            var slot:String;
            for(slot in guestSockets)
            {
               writeFrameOn(guestSockets[slot],FRAME_STATE,state);
            }
         }
         else if(clientSocket != null && clientSocket.connected)
         {
            writeFrameOn(clientSocket,FRAME_STATE,state);
         }
      }

      private function clearConnectTimeout() : void
      {
         if(connectTimeoutId != 0)
         {
            clearTimeout(connectTimeoutId);
            connectTimeoutId = 0;
         }
      }

      private function sendControlOn(socket:Socket, msg:Object) : void
      {
         var payload:ByteArray = new ByteArray();
         payload.writeUTFBytes(JSON.stringify(msg));
         writeFrameOn(socket,FRAME_JSON,payload);
      }

      private function writeFrameOn(socket:Socket, type:int, payload:ByteArray) : void
      {
         socket.endian = Endian.BIG_ENDIAN;
         socket.writeByte(type);
         socket.writeUnsignedInt(payload.length);
         socket.writeBytes(payload);
         socket.flush();
      }

      private function onClientSocketError(e:IOErrorEvent) : void
      {
         clearConnectTimeout();
         clearHandshakeTimeout();
         _isNetworked = false;
         dispatchEvent(new NetworkEvent(NetworkEvent.ERROR,null,{"message":"Could not connect (" + e.text + "). Check the address/port and that the host's game is running."}));
      }

      private function onSocketData(e:ProgressEvent) : void
      {
         var socket:Socket = e.currentTarget as Socket;
         var buf:ByteArray = recvBuffers[socket];
         if(buf == null)
         {
            buf = new ByteArray();
            recvBuffers[socket] = buf;
         }
         var chunk:ByteArray = new ByteArray();
         socket.readBytes(chunk);
         buf.position = buf.length;
         buf.writeBytes(chunk);
         drainFrames(socket,buf);
      }

      // Consumes every complete frame currently sitting in buf for the
      // given socket, then compacts it down to whatever partial frame
      // remains. If the very first byte isn't a frame type this protocol
      // recognizes, something other than a Gazillionaire peer is on the
      // other end (e.g. an HTTP server) - fail loudly instead of quietly
      // discarding garbage and leaving the caller stuck waiting forever.
      private function drainFrames(socket:Socket, buf:ByteArray) : void
      {
         buf.position = 0;
         while(buf.bytesAvailable >= HEADER_LEN)
         {
            var startPos:int = buf.position;
            var type:int = buf.readUnsignedByte();
            if(type != FRAME_JSON && type != FRAME_STATE)
            {
               clearHandshakeTimeout();
               dispatchEvent(new NetworkEvent(NetworkEvent.ERROR,null,{"message":"Got unrecognized data instead of a Gazillionaire handshake - something else is likely listening on that address/port."}));
               try
               {
                  socket.close();
               }
               catch(e:Error)
               {
               }
               return;
            }
            var len:uint = buf.readUnsignedInt();
            if(buf.bytesAvailable < len)
            {
               buf.position = startPos;
               break;
            }
            var payload:ByteArray = new ByteArray();
            buf.readBytes(payload,0,len);
            handleFrame(socket,type,payload);
         }
         var remaining:ByteArray = new ByteArray();
         if(buf.bytesAvailable > 0)
         {
            buf.readBytes(remaining);
         }
         recvBuffers[socket] = remaining;
      }

      private function handleFrame(socket:Socket, type:int, payload:ByteArray) : void
      {
         if(type == FRAME_JSON)
         {
            payload.position = 0;
            var msg:Object = JSON.parse(payload.readUTFBytes(payload.length));
            handleControl(socket,msg);
         }
         else if(type == FRAME_STATE)
         {
            clearHandshakeTimeout();
            _isNetworked = true;
            dispatchEvent(new NetworkEvent(NetworkEvent.STATE_RECEIVED,payload));
         }
      }

      private function handleControl(socket:Socket, msg:Object) : void
      {
         if(msg.type == "join" && _isHost)
         {
            guestSockets[String(int(msg.slot))] = socket;
            sendControlOn(socket,{"type":"welcome"});
            dispatchEvent(new NetworkEvent(NetworkEvent.PEER_LIST,null,{"slot":msg.slot}));
         }
         else if(msg.type == "welcome" && !_isHost)
         {
            clearHandshakeTimeout();
            _isNetworked = true;
            dispatchEvent(new NetworkEvent(NetworkEvent.ROOM_READY,null,{}));
         }
         else if(msg.type == "error")
         {
            dispatchEvent(new NetworkEvent(NetworkEvent.ERROR,null,{"message":msg.message}));
         }
      }
   }
}
