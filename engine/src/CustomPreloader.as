package
{
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.events.ProgressEvent;
   import flash.events.TimerEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
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

      public var _timer:Timer;

      // DIAGNOSTIC ONLY — not shipped. Appends a line to
      // ~/Desktop/gaz_diag.log so we can see how far startup got and
      // capture any uncaught exception, since there is no working
      // debugger for this app on this machine.
      public static function diagLog(param1:String) : void
      {
         try
         {
            var _loc2_:File = new File("/tmp/gaz_diag.log");
            var _loc3_:FileStream = new FileStream();
            _loc3_.open(_loc2_,FileMode.APPEND);
            _loc3_.writeUTFBytes(new Date().toString() + "  " + param1 + "\n");
            _loc3_.close();
         }
         catch(e:Error)
         {
         }
      }

      public function CustomPreloader()
      {
         super();
         diagLog("CustomPreloader constructor start");
         NativeApplication.nativeApplication.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,this.onUncaughtError);
         this.ls = new LoadScreen();
         this.addChild(this.ls);
         diagLog("CustomPreloader constructor end");
      }

      private function onUncaughtError(param1:UncaughtErrorEvent) : void
      {
         var _loc2_:String = "UNCAUGHT ERROR: " + param1.error;
         if(param1.error is Error)
         {
            _loc2_ += "\nstack: " + (param1.error as Error).getStackTrace();
         }
         diagLog(_loc2_);
      }

      override public function set preloader(param1:Sprite) : void
      {
         diagLog("set preloader() called");
         param1.addEventListener(ProgressEvent.PROGRESS,this.SWFDownloadProgress);
         param1.addEventListener(Event.COMPLETE,this.SWFDownloadComplete);
         param1.addEventListener(FlexEvent.INIT_PROGRESS,this.FlexInitProgress);
         param1.addEventListener(FlexEvent.INIT_COMPLETE,this.FlexInitComplete);
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
      
      private function FlexInitProgress(param1:Event) : void
      {
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

