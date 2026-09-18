package
{
   import flash.utils.ByteArray;
   import mx.core.MovieClipLoaderAsset;
   
   public class Gazillionaire__embed_mxml_VEXX1_SWF_1452207462 extends MovieClipLoaderAsset
   {
      
      private static var bytes:ByteArray = null;
      
      public var dataClass:Class = Gazillionaire__embed_mxml_VEXX1_SWF_1452207462_dataClass;
      
      public function Gazillionaire__embed_mxml_VEXX1_SWF_1452207462()
      {
         super();
         initialWidth = 5000 / 20;
         initialHeight = 5000 / 20;
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

