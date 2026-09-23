package
{
   import flash.display.Sprite;
   import flash.events.MouseEvent;
   import flash.text.TextField;
   import flash.text.TextFieldAutoSize;
   import flash.text.TextFormat;
   import mx.containers.TitleWindow;
   import mx.controls.Button;
   import mx.controls.Label;
   import mx.controls.TextInput;
   import mx.events.CloseEvent;
   import mx.managers.PopUpManager;

   // Standalone "Play Online" entry point. Deliberately built with plain
   // Flex API calls (PopUpManager/TitleWindow) instead of touching the
   // generated MXML-descriptor UI in Gazillionaire.as, which is far too
   // large and fragile to hand-edit safely for a whole new screen.
   // See docs/multiplayer-architecture.md.
   public class NetworkLobbyUI extends TitleWindow
   {

      private var hostField:TextInput;

      private var portField:TextInput;

      private var slotField:TextInput;

      private var statusLabel:Label;

      private var app:Gazillionaire;

      // Adds a small "Play Online" corner button, without touching the
      // declarative UI tree. Built from raw Sprite/TextField rather than
      // mx.controls.Button: attached at applicationComplete once (before
      // this was scoped to a single screen), the Flex StyleManager hadn't
      // necessarily finished loading _Gazillionaire_Styles yet, so a
      // themed halo Button was found (visually, via screenshot) to render
      // nothing at all. Plain display-list drawing has no such
      // dependency. Caller owns the returned Sprite and must
      // rawChildren.removeChild() it when the button should go away (see
      // __frm_HowManyPlayers_show/_hide in Gazillionaire.as - multiplayer
      // games are only startable/joinable from that screen).
      public static function attachTrigger(app:Gazillionaire) : Sprite
      {
         var button:Sprite = new Sprite();
         button.graphics.beginFill(0x2255aa);
         button.graphics.drawRect(0,0,90,20);
         button.graphics.endFill();
         var label:TextField = new TextField();
         label.autoSize = TextFieldAutoSize.LEFT;
         label.selectable = false;
         label.mouseEnabled = false;
         label.defaultTextFormat = new TextFormat("_sans",11,0xffffff,true);
         label.text = "Play Online";
         label.x = 6;
         label.y = 3;
         button.addChild(label);
         button.buttonMode = true;
         button.x = 8;
         button.y = 8;
         button.addEventListener(MouseEvent.CLICK,function(e:MouseEvent) : void
         {
            NetworkLobbyUI.show(app);
         });
         app.rawChildren.addChild(button);
         return button;
      }

      public static function show(app:Gazillionaire) : void
      {
         var lobby:NetworkLobbyUI = new NetworkLobbyUI();
         lobby.app = app;
         PopUpManager.addPopUp(lobby,app,true);
         PopUpManager.centerPopUp(lobby);
      }

      public function NetworkLobbyUI()
      {
         super();
         this.title = "Play Online";
         this.showCloseButton = true;
         this.width = 280;
         this.height = 320;
         this.addEventListener(CloseEvent.CLOSE,this.onClose);
      }

      override protected function createChildren() : void
      {
         super.createChildren();
         addChild(this.makeLabel("Port"));
         this.portField = new TextInput();
         this.portField.text = "8642";
         addChild(this.portField);
         addChild(this.makeLabel("Host's address (leave blank to host)"));
         this.hostField = new TextInput();
         addChild(this.hostField);
         addChild(this.makeLabel("Your player slot (0-5)"));
         this.slotField = new TextInput();
         this.slotField.text = "0";
         addChild(this.slotField);
         var goButton:Button = new Button();
         goButton.label = "Connect";
         goButton.addEventListener(MouseEvent.CLICK,this.onConnect);
         addChild(goButton);
         this.statusLabel = new Label();
         this.statusLabel.text = "";
         addChild(this.statusLabel);
         NetworkClient.instance.addEventListener(NetworkEvent.ROOM_READY,this.onRoomReady);
         NetworkClient.instance.addEventListener(NetworkEvent.ERROR,this.onNetworkError);
         NetworkClient.instance.addEventListener(NetworkEvent.PEER_LIST,this.onPeerList);
      }

      private function makeLabel(text:String) : Label
      {
         var label:Label = new Label();
         label.text = text;
         return label;
      }

      private function onConnect(event:MouseEvent) : void
      {
         var host:String = this.hostField.text;
         var port:int = int(this.portField.text);
         var slot:int = int(this.slotField.text);
         this.statusLabel.text = "Connecting...";
         if(host == null || host.length == 0)
         {
            NetworkClient.instance.hostGame(port,slot);
         }
         else
         {
            NetworkClient.instance.joinGame(host,port,slot);
         }
      }

      private function onRoomReady(event:NetworkEvent) : void
      {
         if(NetworkClient.instance.isHost)
         {
            // Host keeps configuring the game normally (opponents,
            // planets, ship selection) - the port is listening now, share
            // this machine's address (ipconfig on Windows) and the port
            // with whoever's joining, LAN or with it forwarded on your
            // router for over the internet.
            this.statusLabel.text = "Hosting on port " + event.data.port + ". If Windows Firewall just asked to allow this app, click Allow (both Private and Public) or guests can't reach you. Share your address and this port, then pick your player count below.";
         }
         else
         {
            // Guest never touches the local setup screens - the host
            // controls all of that and broadcasts it. Close this popup
            // and switch straight to a waiting screen.
            PopUpManager.removePopUp(this);
            if(this.app != null)
            {
               this.app.frm_Travel3_networkWait();
            }
         }
      }

      private function onNetworkError(event:NetworkEvent) : void
      {
         this.statusLabel.text = "Error: " + event.data.message;
      }

      // Only meaningful for the host - fires once a guest's socket
      // actually completes the connect+join handshake. Without this, a
      // guest that never reaches the host (firewall silently dropping
      // the inbound connection is the common case) leaves the host
      // sitting on an unchanged "Hosting on port N" message forever, in
      // directly the same way the guest's own connect can time out -
      // the host side needs its own positive signal, not just an absence
      // of errors, to tell "nobody has connected yet" apart from
      // "a guest is in and setup can proceed."
      private function onPeerList(event:NetworkEvent) : void
      {
         if(NetworkClient.instance.isHost)
         {
            this.statusLabel.text = "Guest connected (slot " + event.data.slot + "). If you were waiting and this just appeared, you're good - proceed to pick your player count.";
         }
      }

      private function onClose(event:CloseEvent) : void
      {
         PopUpManager.removePopUp(this);
      }
   }
}
