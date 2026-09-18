package
{
   import flash.utils.ByteArray;
   import mx.core.MovieClipLoaderAsset;
   
   public class _class_embed_css_f_endred_swf_735613634_1127775762 extends MovieClipLoaderAsset
   {
      
      private static var bytes:ByteArray = null;
      
      public var dataClass:Class = _class_embed_css_f_endred_swf_735613634_1127775762_dataClass;
      
      public function _class_embed_css_f_endred_swf_735613634_1127775762()
      {
         super();
         initialWidth = 880 / 20;
         initialHeight = 7160 / 20;
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

