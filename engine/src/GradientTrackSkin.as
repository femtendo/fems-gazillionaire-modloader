package
{
   import mx.core.IFlexModuleFactory;
   import mx.core.mx_internal;
   import mx.graphics.GradientEntry;
   import mx.graphics.LinearGradient;
   import mx.graphics.SolidColorStroke;
   import mx.skins.spark.ProgressBarTrackSkin;
   import spark.primitives.Rect;

   use namespace mx_internal;

   public class GradientTrackSkin extends ProgressBarTrackSkin
   {
      
      private var __moduleFactoryInitialized:Boolean = false;
      
      public function GradientTrackSkin()
      {
         super();
         mx_internal::_document = this;
         this.name = "GradientTrackSkin";
         this.mxmlContent = [this._GradientTrackSkin_Rect1_c()];
      }
      
      override public function set moduleFactory(param1:IFlexModuleFactory) : void
      {
         super.moduleFactory = param1;
         if(this.__moduleFactoryInitialized)
         {
            return;
         }
         this.__moduleFactoryInitialized = true;
      }
      
      override public function initialize() : void
      {
         super.initialize();
      }
      
      private function _GradientTrackSkin_Rect1_c() : Rect
      {
         var _loc1_:Rect = new Rect();
         _loc1_.radiusX = 2;
         _loc1_.radiusY = 2;
         _loc1_.left = 1;
         _loc1_.right = 1;
         _loc1_.top = 0;
         _loc1_.bottom = 1;
         _loc1_.fill = this._GradientTrackSkin_LinearGradient1_c();
         _loc1_.stroke = this._GradientTrackSkin_SolidColorStroke1_c();
         _loc1_.initialized(this,null);
         return _loc1_;
      }
      
      private function _GradientTrackSkin_LinearGradient1_c() : LinearGradient
      {
         var _loc1_:LinearGradient = new LinearGradient();
         _loc1_.rotation = 90;
         _loc1_.entries = [this._GradientTrackSkin_GradientEntry1_c(),this._GradientTrackSkin_GradientEntry2_c()];
         return _loc1_;
      }
      
      private function _GradientTrackSkin_GradientEntry1_c() : GradientEntry
      {
         var _loc1_:GradientEntry = new GradientEntry();
         _loc1_.color = 13500153;
         return _loc1_;
      }
      
      private function _GradientTrackSkin_GradientEntry2_c() : GradientEntry
      {
         var _loc1_:GradientEntry = new GradientEntry();
         _loc1_.color = 16775150;
         return _loc1_;
      }
      
      private function _GradientTrackSkin_SolidColorStroke1_c() : SolidColorStroke
      {
         var _loc1_:SolidColorStroke = new SolidColorStroke();
         _loc1_.color = 7263485;
         _loc1_.weight = 0;
         return _loc1_;
      }
   }
}

