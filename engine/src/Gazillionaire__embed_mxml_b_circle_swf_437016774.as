package
{
   import flash.utils.ByteArray;
   import mx.core.MovieClipLoaderAsset;
   
   public class Gazillionaire__embed_mxml_b_circle_swf_437016774 extends MovieClipLoaderAsset
   {
      
      private static var bytes:ByteArray = null;
      
      public var dataClass:Class = Gazillionaire__embed_mxml_b_circle_swf_437016774_dataClass;
      
      public function Gazillionaire__embed_mxml_b_circle_swf_437016774()
      {
         super();
         initialWidth = 480 / 20;
         initialHeight = 480 / 20;
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

