package
{
   import flash.utils.ByteArray;
   import mx.core.MovieClipLoaderAsset;
   
   public class Gazillionaire__embed_mxml_stars_bg_main_swf_835323288 extends MovieClipLoaderAsset
   {
      
      private static var bytes:ByteArray = null;
      
      public var dataClass:Class = Gazillionaire__embed_mxml_stars_bg_main_swf_835323288_dataClass;
      
      public function Gazillionaire__embed_mxml_stars_bg_main_swf_835323288()
      {
         super();
         initialWidth = 5720 / 20;
         initialHeight = 4600 / 20;
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

