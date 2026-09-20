package
{
   import flash.desktop.NativeApplication;
   import flash.display.MovieClip;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.events.ProgressEvent;
   import flash.events.TimerEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.text.TextField;
   import flash.text.TextFieldAutoSize;
   import flash.text.TextFormat;
   import flash.text.TextFormatAlign;
   import flash.utils.Timer;
   import mx.events.FlexEvent;
   import mx.preloaders.DownloadProgressBar;

   public class CustomPreloader extends DownloadProgressBar
   {

      // DIAGNOSTIC ONLY — static initializers run the instant the class is
      // loaded/verified by the VM, before any constructor anywhere runs.
      // This is the earliest possible hook into whether our compiled ABC
      // is even being executed at all.
      private static var _diagBoot:Boolean = _bootLog();

      private static function _bootLog() : Boolean
      {
         diagLog("CustomPreloader class static-init ran (VM is executing our code)");
         return true;
      }

      public var ls:LoadScreen;

      public var statusText:TextField;

      public var _timer:Timer;

      public var _pollTimer:Timer;

      public var _pollCount:int = 0;

      private function onPollLoaderInfo(param1:TimerEvent) : void
      {
         this._pollCount++;
         diagLog("poll " + this._pollCount + ": bytesLoaded=" + (this.root ? this.root.loaderInfo.bytesLoaded : "no root") +
            " bytesTotal=" + (this.root ? this.root.loaderInfo.bytesTotal : "no root") +
            " framesLoaded=" + (this.root ? MovieClip(this.root).framesLoaded : "n/a"));
         if(this._pollCount >= 10)
         {
            this._pollTimer.stop();
         }
      }

      // DIAGNOSTIC ONLY — not shipped. Appends a line to
      // ~/Desktop/gaz_diag.log so we can see how far startup got and
      // capture any uncaught exception, since there is no working
      // debugger for this app on this machine.
      public static function diagLog(param1:String) : void
      {
         try
         {
            // Try /tmp first
            var _loc2_:File = new File("/tmp/gaz_diag.log");
            var _loc3_:FileStream = new FileStream();
            _loc3_.open(_loc2_,FileMode.APPEND);
            _loc3_.writeUTFBytes(new Date().getTime() + "  " + param1 + "\n");
            _loc3_.close();
         }
         catch(e:Error)
         {
            // If /tmp fails, try home directory
            try
            {
               var homeFile:File = File.documentsDirectory.resolvePath("../gaz_diag.log");
               var homeStream:FileStream = new FileStream();
               homeStream.open(homeFile, FileMode.APPEND);
               homeStream.writeUTFBytes(new Date().getTime() + "  " + param1 + " [home]\n");
               homeStream.close();
            }
            catch(e2:Error)
            {
               // Give up silently
            }
         }
      }

      public function CustomPreloader()
      {
         super();
         diagLog("CustomPreloader constructor start");
         NativeApplication.nativeApplication.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,this.onUncaughtError);
         this.ls = new LoadScreen();
         this.addChild(this.ls);
         this.addEventListener(Event.ADDED_TO_STAGE,this.onAddedToStage);
         diagLog("CustomPreloader constructor end");
      }

      // Mod-loader status line: mod count, build hash, and validation
      // status, shown bottom-of-screen during boot like most mod loaders
      // do. ModLoaderInfo is generated fresh by build.js on every build
      // from the actually-resolved enabled mod set — see
      // tools/modloader/build.js's writeModLoaderInfo().
      private function setupStatusText() : void
      {
         this.statusText = new TextField();
         this.statusText.autoSize = TextFieldAutoSize.CENTER;
         this.statusText.selectable = false;
         this.statusText.mouseEnabled = false;
         var fmt:TextFormat = new TextFormat();
         fmt.font = "_sans";
         fmt.size = 11;
         fmt.color = ModLoaderInfo.VALIDATED ? 0x8FE58F : 0xE58F8F;
         fmt.align = TextFormatAlign.CENTER;
         this.statusText.defaultTextFormat = fmt;
         var modWord:String = ModLoaderInfo.MOD_COUNT == 1 ? "mod" : "mods";
         this.statusText.text = ModLoaderInfo.MOD_COUNT + " " + modWord + " loaded  |  build " +
            ModLoaderInfo.BUILD_HASH + "  |  " +
            (ModLoaderInfo.VALIDATED ? "modloader validated" : "modloader FAILED");
         this.addChild(this.statusText);
      }

      private function onAddedToStage(param1:Event) : void
      {
         diagLog("CustomPreloader added to stage");
         try
         {
            diagLog("root.loaderInfo bytesLoaded=" + (this.root ? this.root.loaderInfo.bytesLoaded : "no root") +
               " bytesTotal=" + (this.root ? this.root.loaderInfo.bytesTotal : "no root") +
               " totalFrames=" + (this.root ? MovieClip(this.root).totalFrames : "n/a") +
               " framesLoaded=" + (this.root ? MovieClip(this.root).framesLoaded : "n/a"));
            this._pollTimer = new Timer(50);
            this._pollTimer.addEventListener(TimerEvent.TIMER,this.onPollLoaderInfo);
            this._pollTimer.start();
            this.setupStatusText();
            if(this.stage)
            {
               this.statusText.x = this.stage.stageWidth / 2 - this.statusText.width / 2;
               this.statusText.y = this.stage.stageHeight - this.statusText.height - 6;
               // Real Steam-launched instances (unlike direct-exec test
               // launches) leave the native window created but never
               // ordered front/marked onscreen — AIR/Flex's own show
               // handshake doesn't complete reliably under Steam's launch
               // path. Force it directly, same as this project's original
               // bug-1-era workaround; confirmed necessary again via a
               // real Steam launch after the MXML/verification-timeout fix
               // (which fixed a separate, now-resolved crash-on-boot bug).
               if(this.stage.nativeWindow)
               {
                  this.stage.nativeWindow.visible = true;
                  this.stage.nativeWindow.activate();
                  diagLog("forced nativeWindow.visible=true, activate()");
               }
            }
         }
         catch(e:Error)
         {
            diagLog("onAddedToStage THREW: " + e + "\nstack: " + e.getStackTrace());
         }
      }

      private function onUncaughtError(param1:UncaughtErrorEvent) : void
      {
         var _loc2_:String = "UNCAUGHT ERROR: " + param1.error;
         if(param1.error is Error)
         {
            _loc2_ += "\nstack: " + (param1.error as Error).getStackTrace();
         }
         diagLog(_loc2_);
         param1.preventDefault();
      }

      override public function set preloader(param1:Sprite) : void
      {
         diagLog("set preloader() called");
         try
         {
            param1.addEventListener(ProgressEvent.PROGRESS,this.SWFDownloadProgress);
            param1.addEventListener(Event.COMPLETE,this.SWFDownloadComplete);
            param1.addEventListener(FlexEvent.INIT_PROGRESS,this.FlexInitProgress);
            param1.addEventListener(FlexEvent.INIT_COMPLETE,this.FlexInitComplete);
            diagLog("set preloader() finished adding listeners");
         }
         catch(e:Error)
         {
            diagLog("set preloader() THREW: " + e + "\nstack: " + e.getStackTrace());
         }
      }
      
      private function SWFDownloadProgress(param1:ProgressEvent) : void
      {
         var _loc2_:Number = param1.bytesLoaded / param1.bytesTotal;
         if(this.ls)
         {
            this.ls.progress = _loc2_;
         }
      }
      
      private function SWFDownloadComplete(param1:Event) : void
      {
         diagLog("SWFDownloadComplete fired");
         if(this.ls)
         {
            this.ls.progress = 0;
         }
         this._timer = new Timer(100);
         this._timer.addEventListener(TimerEvent.TIMER,this.AdvanceLoadScreen);
         this._timer.start();
      }
      
      private function AdvanceLoadScreen(param1:TimerEvent) : void
      {
         if(this.ls)
         {
            if(this.ls.progress > 0.9)
            {
               this.ls.progress = 0;
            }
            else
            {
               this.ls.progress += 0.1;
            }
         }
      }
      
      private var _initProgressCount:int = 0;

      private function FlexInitProgress(param1:Event) : void
      {
         this._initProgressCount++;
         diagLog("FlexInitProgress fired (#" + this._initProgressCount + ")");
      }
      
      private function FlexInitComplete(param1:Event) : void
      {
         diagLog("FlexInitComplete fired — dispatching preloader COMPLETE");
         this._timer.stop();
         this.ls.ready = true;
         dispatchEvent(new Event(Event.COMPLETE));
      }
   }
}

