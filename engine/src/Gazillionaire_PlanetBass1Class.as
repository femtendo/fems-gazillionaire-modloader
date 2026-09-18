package
{
   import flash.utils.ByteArray;
   import mx.core.MovieClipLoaderAsset;
   
   public class Gazillionaire_PlanetBass1Class extends MovieClipLoaderAsset
   {
      
      private static var bytes:ByteArray = null;
      
      public var dataClass:Class = Gazillionaire_PlanetBass1Class_dataClass;
      
      public function Gazillionaire_PlanetBass1Class()
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

