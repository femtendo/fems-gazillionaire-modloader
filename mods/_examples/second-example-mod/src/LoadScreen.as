package
{
   import flash.display.Loader;
   import flash.events.TimerEvent;
   import flash.utils.ByteArray;
   import flash.utils.Timer;

   public class LoadScreen extends Loader
   {

      public var LoadScreenGraphic:Class = LoadScreen_LoadScreenGraphic;

      public var timer:Timer;

      public var ready:Boolean = false;

      public var progress:Number = 0;

      public function LoadScreen()
      {
         super();
         this.visible = false;
         this.alpha = 0;
         // second-example mod: ticks every 10ms instead of 1ms — same fade,
         // noticeably fewer updateView calls, easy to eyeball that this mod took.
         this.timer = new Timer(10);
         this.timer.addEventListener(TimerEvent.TIMER,this.updateView);
         this.timer.start();
         this.loadBytes(new this.LoadScreenGraphic() as ByteArray);
      }

      public function updateView(param1:TimerEvent) : void
      {
         if(this.progress <= 1 / 2)
         {
            this.alpha = 2 * (1 / 2 - this.progress);
         }
         else
         {
            this.alpha = 2 * (this.progress - 1 / 2);
         }
         this.stage.addChild(this);
         this.x = this.stage.stageWidth / 2 - this.width / 2;
         this.y = this.stage.stageHeight / 2 - this.height / 2;
         this.visible = true;
         if(this.ready)
         {
            this.timer.removeEventListener(TimerEvent.TIMER,this.updateView);
            this.timer.stop();
            this.parent.removeChild(this);
         }
      }
   }
}
