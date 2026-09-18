package
{
   import flash.utils.ByteArray;
   import mx.core.MovieClipLoaderAsset;
   
   public class Gazillionaire__embed_mxml_Frame_help3_swf_987142362 extends MovieClipLoaderAsset
   {
      
      private static var bytes:ByteArray = null;
      
      public var dataClass:Class = Gazillionaire__embed_mxml_Frame_help3_swf_987142362_dataClass;
      
      public function Gazillionaire__embed_mxml_Frame_help3_swf_987142362()
      {
         super();
         initialWidth = 6000 / 20;
         initialHeight = 6000 / 20;
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

