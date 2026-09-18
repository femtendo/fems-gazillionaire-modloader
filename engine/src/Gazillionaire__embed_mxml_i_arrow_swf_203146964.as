package
{
   import flash.utils.ByteArray;
   import mx.core.MovieClipLoaderAsset;
   
   public class Gazillionaire__embed_mxml_i_arrow_swf_203146964 extends MovieClipLoaderAsset
   {
      
      private static var bytes:ByteArray = null;
      
      public var dataClass:Class = Gazillionaire__embed_mxml_i_arrow_swf_203146964_dataClass;
      
      public function Gazillionaire__embed_mxml_i_arrow_swf_203146964()
      {
         super();
         initialWidth = 640 / 20;
         initialHeight = 400 / 20;
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

