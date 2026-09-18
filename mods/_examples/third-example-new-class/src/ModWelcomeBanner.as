package
{
   // Demonstrates a mod adding a brand new class that doesn't exist in the
   // base engine at all, rather than overriding an existing one. Nothing in
   // the base game references this class, so it compiles in but is inert
   // unless another mod (or a future engine hook) calls into it.
   public class ModWelcomeBanner
   {
      public static const MESSAGE:String = "third-example mod loaded";
   }
}
