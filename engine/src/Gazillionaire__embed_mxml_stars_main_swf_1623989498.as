package
{
   import flash.utils.ByteArray;
   import mx.core.MovieClipLoaderAsset;
   
   public class Gazillionaire__embed_mxml_stars_main_swf_1623989498 extends MovieClipLoaderAsset
   {
      
      private static var bytes:ByteArray = null;
      
      public var dataClass:Class = Gazillionaire__embed_mxml_stars_main_swf_1623989498_dataClass;
      
      public function Gazillionaire__embed_mxml_stars_main_swf_1623989498()
      {
         super();
         initialWidth = 15200 / 20;
         initialHeight = 11400 / 20;
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

