package
{
   import flash.utils.ByteArray;
   import mx.core.MovieClipLoaderAsset;
   
   public class Gazillionaire__embed_mxml_i_target_swf_976591674 extends MovieClipLoaderAsset
   {
      
      private static var bytes:ByteArray = null;
      
      public var dataClass:Class = Gazillionaire__embed_mxml_i_target_swf_976591674_dataClass;
      
      public function Gazillionaire__embed_mxml_i_target_swf_976591674()
      {
         super();
         initialWidth = 600 / 20;
         initialHeight = 600 / 20;
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

