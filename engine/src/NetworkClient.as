package
{
   import flash.events.Event;
   import flash.events.EventDispatcher;
   import flash.events.IOErrorEvent;
   import flash.events.ProgressEvent;
   import flash.net.Socket;
   import flash.utils.ByteArray;
   import flash.utils.Endian;

   // Client for the multiplayer relay in tools/multiplayer-server/relay.js.
   // Frame format (must match the server): [1 byte type][4 byte BE length][payload].
   // See docs/multiplayer-architecture.md. Owns no game state — the engine
   // hands it a GameType.serialize() blob to publish and gets a raw blob
   // back on NetworkEvent.STATE_RECEIVED, which the caller deserializes.
   public class NetworkClient extends EventDispatcher
   {

      private static const FRAME_JSON:int = 1;

      private static const FRAME_STATE:int = 2;

      private static const HEADER_LEN:int = 5;

      private static var _instance:NetworkClient;

      public static function get instance() : NetworkClient
      {
         if(_instance == null)
         {
            _instance = new NetworkClient();
         }
         return _instance;
      }

      private var socket:Socket;

      private var recvBuffer:ByteArray;

      private var _isNetworked:Boolean = false;

      private var _mySlots:Array = [];

      private var _roomCode:String = null;

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

      public function get roomCode() : String
      {
         return _roomCode;
      }

      public function NetworkClient()
      {
         super();
         recvBuffer = new ByteArray();
      }

      // Connects and asks the relay to create a fresh room; the caller's
      // slot becomes the first turn slot. Fires NetworkEvent.ROOM_READY
      // with the generated room code once the server confirms.
      public function hostGame(host:String, port:int, slot:int) : void
      {
         _mySlots = [slot];
         _isHost = true;
         openSocket(host, port, function() : void
         {
            sendControl({
               "type":"create",
               "slot":slot
            });
         });
      }

      // Connects and joins an existing room by code.
      public function joinGame(host:String, port:int, code:String, slot:int) : void
      {
         _mySlots = [slot];
         _isHost = false;
         openSocket(host, port, function() : void
         {
            sendControl({
               "type":"join",
               "code":code,
               "slot":slot
            });
         });
      }

      public function disconnect() : void
      {
         if(socket != null && socket.connected)
         {
            socket.close();
         }
         _isNetworked = false;
         _roomCode = null;
         _isHost = false;
      }

      // Called once a network-controlled player's turn finishes; broadcasts
      // the serialized GameType so remote clients can pick up the next turn.
      public function publishTurn(state:ByteArray) : void
      {
         if(socket == null || !socket.connected)
         {
            return;
         }
         writeFrame(FRAME_STATE, state);
      }

      private function openSocket(host:String, port:int, onConnected:Function) : void
      {
         socket = new Socket();
         socket.addEventListener(Event.CONNECT, function(e:Event) : void
         {
            onConnected();
         });
         socket.addEventListener(ProgressEvent.SOCKET_DATA, onSocketData);
         socket.addEventListener(IOErrorEvent.IO_ERROR, onSocketError);
         socket.connect(host, port);
      }

      private function sendControl(msg:Object) : void
      {
         var json:String = JSON.stringify(msg);
         var payload:ByteArray = new ByteArray();
         payload.writeUTFBytes(json);
         writeFrame(FRAME_JSON, payload);
      }

      private function writeFrame(type:int, payload:ByteArray) : void
      {
         socket.endian = Endian.BIG_ENDIAN;
         socket.writeByte(type);
         socket.writeUnsignedInt(payload.length);
         socket.writeBytes(payload);
         socket.flush();
      }

      private function onSocketError(e:IOErrorEvent) : void
      {
         _isNetworked = false;
         dispatchEvent(new NetworkEvent(NetworkEvent.ERROR, null, {"message":e.text}));
      }

      private function onSocketData(e:ProgressEvent) : void
      {
         var chunk:ByteArray = new ByteArray();
         socket.readBytes(chunk);
         recvBuffer.position = recvBuffer.length;
         recvBuffer.writeBytes(chunk);
         drainFrames();
      }

      // Consumes every complete frame currently sitting in recvBuffer,
      // then compacts the buffer down to whatever partial frame remains.
      private function drainFrames() : void
      {
         recvBuffer.position = 0;
         while(recvBuffer.bytesAvailable >= HEADER_LEN)
         {
            var startPos:int = recvBuffer.position;
            var type:int = recvBuffer.readUnsignedByte();
            var len:uint = recvBuffer.readUnsignedInt();
            if(recvBuffer.bytesAvailable < len)
            {
               recvBuffer.position = startPos;
               break;
            }
            var payload:ByteArray = new ByteArray();
            recvBuffer.readBytes(payload, 0, len);
            handleFrame(type, payload);
         }
         var remaining:ByteArray = new ByteArray();
         if(recvBuffer.bytesAvailable > 0)
         {
            recvBuffer.readBytes(remaining);
         }
         recvBuffer = remaining;
      }

      private function handleFrame(type:int, payload:ByteArray) : void
      {
         if(type == FRAME_JSON)
         {
            payload.position = 0;
            var msg:Object = JSON.parse(payload.readUTFBytes(payload.length));
            handleControl(msg);
         }
         else if(type == FRAME_STATE)
         {
            dispatchEvent(new NetworkEvent(NetworkEvent.STATE_RECEIVED, payload));
         }
      }

      private function handleControl(msg:Object) : void
      {
         if(msg.type == "created" || msg.type == "joined")
         {
            _roomCode = msg.code;
            _isNetworked = true;
            dispatchEvent(new NetworkEvent(NetworkEvent.ROOM_READY, null, {"code":_roomCode}));
         }
         else if(msg.type == "peer-list")
         {
            dispatchEvent(new NetworkEvent(NetworkEvent.PEER_LIST, null, {
               "slots":msg.slots,
               "turnSlot":msg.turnSlot
            }));
         }
         else if(msg.type == "error")
         {
            dispatchEvent(new NetworkEvent(NetworkEvent.ERROR, null, {"message":msg.message}));
         }
      }
   }
}
