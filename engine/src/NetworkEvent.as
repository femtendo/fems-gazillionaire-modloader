package
{
   import flash.events.Event;
   import flash.utils.ByteArray;

   public class NetworkEvent extends Event
   {

      public static const STATE_RECEIVED:String = "networkStateReceived";

      public static const ROOM_READY:String = "networkRoomReady";

      public static const PEER_LIST:String = "networkPeerList";

      public static const ERROR:String = "networkError";

      public var state:ByteArray;

      public var data:Object;

      public function NetworkEvent(type:String, state:ByteArray = null, data:Object = null)
      {
         super(type);
         this.state = state;
         this.data = data;
      }

      override public function clone() : Event
      {
         return new NetworkEvent(type, state, data);
      }
   }
}
