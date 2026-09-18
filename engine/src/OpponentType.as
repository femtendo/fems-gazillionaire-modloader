package
{
   import flash.utils.ByteArray;
   
   public class OpponentType
   {
      
      public var netWorth:Number;
      
      public var engine:int;
      
      public var planet:int;
      
      public var planetLast:int;
      
      public var travelTime:Number;
      
      public var turnTaken:Boolean;
      
      public var comTag1:int;
      
      public var comTag2:int;
      
      public var comS:Number;
      
      public var shipTons:Number;
      
      public var cash:Number;
      
      public var iQ:int;
      
      public var history:Array;
      
      public var facility:Array;
      
      public var facilityFee:Array;
      
      public var facilityRevenue:Array;
      
      public var share:Array;
      
      public function OpponentType()
      {
         super();
      }
      
      public function serialize(param1:ByteArray) : void
      {
         var _loc2_:int = 0;
         param1.writeDouble(this.netWorth);
         param1.writeInt(this.engine);
         param1.writeInt(this.planet);
         param1.writeInt(this.planetLast);
         param1.writeDouble(this.travelTime);
         param1.writeBoolean(this.turnTaken);
         param1.writeInt(this.comTag1);
         param1.writeInt(this.comTag2);
         param1.writeDouble(this.comS);
         param1.writeDouble(this.shipTons);
         param1.writeDouble(this.cash);
         param1.writeInt(this.iQ);
         _loc2_ = 0;
         while(_loc2_ <= 20)
         {
            param1.writeDouble(this.history[_loc2_]);
            _loc2_++;
         }
         _loc2_ = 0;
         while(_loc2_ <= 6)
         {
            param1.writeInt(this.facility[_loc2_]);
            param1.writeDouble(this.facilityFee[_loc2_]);
            param1.writeDouble(this.facilityRevenue[_loc2_]);
            param1.writeDouble(this.share[_loc2_]);
            _loc2_++;
         }
      }
      
      public function deserialize(param1:ByteArray) : void
      {
         var _loc2_:int = 0;
         this.netWorth = param1.readDouble();
         this.engine = param1.readInt();
         this.planet = param1.readInt();
         this.planetLast = param1.readInt();
         this.travelTime = param1.readDouble();
         this.turnTaken = param1.readBoolean();
         this.comTag1 = param1.readInt();
         this.comTag2 = param1.readInt();
         this.comS = param1.readDouble();
         this.shipTons = param1.readDouble();
         this.cash = param1.readDouble();
         this.iQ = param1.readInt();
         this.history = new Array(21);
         _loc2_ = 0;
         while(_loc2_ <= 20)
         {
            this.history[_loc2_] = param1.readDouble();
            _loc2_++;
         }
         this.facility = new Array(7);
         this.facilityFee = new Array(7);
         this.facilityRevenue = new Array(7);
         this.share = new Array(7);
         _loc2_ = 0;
         while(_loc2_ <= 6)
         {
            this.facility[_loc2_] = param1.readInt();
            this.facilityFee[_loc2_] = param1.readDouble();
            this.facilityRevenue[_loc2_] = param1.readDouble();
            this.share[_loc2_] = param1.readDouble();
            _loc2_++;
         }
      }
      
      public function init(param1:int, param2:int, param3:GameStrings) : void
      {
         var _loc4_:int = 0;
         if(param2 == 1)
         {
            this.engine = 5;
         }
         else if(param2 == 2)
         {
            this.engine = 5;
         }
         else if(param2 == 3)
         {
            this.engine = 5;
         }
         else if(param2 == 4)
         {
            this.engine = 4;
         }
         else if(param2 == 5)
         {
            this.engine = 5;
         }
         else if(param2 == 6)
         {
            this.engine = 6;
         }
         if(param1 == 1)
         {
            this.cash = -50000;
            this.iQ = 50;
         }
         else if(param1 == 2)
         {
            this.cash = -85000;
            this.iQ = 75;
         }
         else if(param1 == 3)
         {
            this.cash = -120000;
            this.iQ = 100;
         }
         else if(param1 == 4)
         {
            this.cash = -130000;
            this.iQ = 125;
         }
         else if(param1 == 5)
         {
            this.cash = -140000;
            this.iQ = 150;
         }
         else if(param1 == 6)
         {
            this.cash = -150000;
            this.iQ = 175;
         }
         this.netWorth = this.cash;
         this.history = new Array(21);
         this.history[0] = this.netWorth + 0.01 * param2 * this.netWorth;
         this.history[1] = this.netWorth;
         this.planet = param2;
         this.planetLast = param2;
         this.travelTime = 0;
         this.turnTaken = false;
         this.comTag1 = 0;
         this.comTag2 = 0;
         this.comS = 0;
         this.shipTons = 400;
         this.facility = new Array(7);
         this.facilityFee = new Array(7);
         this.facilityRevenue = new Array(7);
         this.share = new Array(7);
         _loc4_ = 0;
         while(_loc4_ <= 6)
         {
            this.facility[_loc4_] = 0;
            this.facilityFee[_loc4_] = 0;
            this.facilityRevenue[_loc4_] = 0;
            this.share[_loc4_] = 0;
            _loc4_++;
         }
      }
   }
}

