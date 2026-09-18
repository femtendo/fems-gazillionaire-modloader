package
{
   import flash.utils.ByteArray;
   import mx.core.MovieClipLoaderAsset;
   
   public class _class_embed_css_b_x3_dn_swf_1820202694_745722986 extends MovieClipLoaderAsset
   {
      
      private static var bytes:ByteArray = null;
      
      public var dataClass:Class = _class_embed_css_b_x3_dn_swf_1820202694_745722986_dataClass;
      
      public function _class_embed_css_b_x3_dn_swf_1820202694_745722986()
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

