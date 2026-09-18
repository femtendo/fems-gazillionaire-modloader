package
{
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.events.ProgressEvent;
   import flash.events.TimerEvent;
   import flash.utils.Timer;
   import mx.events.FlexEvent;
   import mx.preloaders.DownloadProgressBar;
   
   public class CustomPreloader extends DownloadProgressBar
   {
      
      public var ls:LoadScreen;
      
      public var _timer:Timer;
      
      public function CustomPreloader()
      {
         super();
         this.ls = new LoadScreen();
         this.addChild(this.ls);
      }
      
      override public function set preloader(param1:Sprite) : void
      {
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
         this._timer.stop();
         this.ls.ready = true;
         dispatchEvent(new Event(Event.COMPLETE));
      }
   }
}

