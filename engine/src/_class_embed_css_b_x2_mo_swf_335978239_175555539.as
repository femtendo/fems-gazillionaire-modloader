package
{
   import flash.utils.ByteArray;
   import mx.core.MovieClipLoaderAsset;
   
   public class _class_embed_css_b_x2_mo_swf_335978239_175555539 extends MovieClipLoaderAsset
   {
      
      private static var bytes:ByteArray = null;
      
      public var dataClass:Class = _class_embed_css_b_x2_mo_swf_335978239_175555539_dataClass;
      
      public function _class_embed_css_b_x2_mo_swf_335978239_175555539()
      {
         super();
         initialWidth = 440 / 20;
         initialHeight = 440 / 20;
      }
      
      override public function get movieClipData() : ByteArray
      {
         if(bytes == null)
         {
            bytes = ByteArray(new this.dataClass());
         }
         return bytes;
      }
   }
}

