package
{
   import flash.utils.ByteArray;
   import mx.core.MovieClipLoaderAsset;
   
   public class Gazillionaire_PlanetStye1Class extends MovieClipLoaderAsset
   {
      
      private static var bytes:ByteArray = null;
      
      public var dataClass:Class = Gazillionaire_PlanetStye1Class_dataClass;
      
      public function Gazillionaire_PlanetStye1Class()
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

