package
{
   import flash.utils.ByteArray;
   
   public class GameType
   {
      
      public var p:Array;
      
      public var o:Array;
      
      public var activateTurn:int;
      
      public var activateZinn:int;
      
      public var activateSupply:int;
      
      public var activateLoan:int;
      
      public var activateInsurance:int;
      
      public var activateViewCity:int;
      
      public var activateFuel:int;
      
      public var activatePassengers:int;
      
      public var activateCrew:int;
      
      public var activateAdvertising:int;
      
      public var activateTax:int;
      
      public var activateBank:int;
      
      public var activateWarehouse:int;
      
      public var activateExplore:int;
      
      public var activateDistance:int;
      
      public var activateFacility:int;
      
      public var activateStock:int;
      
      public var advertC:Array;
      
      public var auction:int;
      
      public var auctionLast:int;
      
      public var auctionCompany:int;
      
      public var auctionNextCompany:int;
      
      public var auctionCompanyLast:int;
      
      public var auctionNextCompanyLast:int;
      
      public var auctionHighBid:Number;
      
      public var auctionNextBid:Number;
      
      public var auctionHighBidLast:Number;
      
      public var auctionNextBidLast:Number;
      
      public var auctionFacilityType:int;
      
      public var auctionFacilityPlanet:int;
      
      public var auctionFacilityFee:Number;
      
      public var auctionFacilityTypeLast:int;
      
      public var auctionFacilityPlanetLast:int;
      
      public var auctionFacilityFeeLast:Number;
      
      public var comR:Array;
      
      public var comP:Array;
      
      public var comA:Array;
      
      public var difficulty:int;
      
      public var dateYear:Number;
      
      public var exportTariff:int;
      
      public var fuelPriceRange:Number;
      
      public var fuelCost:Array;
      
      public var game:int;
      
      public var gameEvent:int;
      
      public var importTariff:int;
      
      public var isMidTurn:Boolean;
      
      public var level:int;
      
      public var news:int;
      
      public var newsData:int;
      
      public var newsPlanet:int;
      
      public var opNumberOf:int;
      
      public var passTax:int;
      
      public var planetIndex:Array;
      
      public var planetX:Array;
      
      public var planetY:Array;
      
      public var player:int;
      
      public var playerOrder:Array;
      
      public var playerNumberOf:int;
      
      public var playerTurnCounter:int;
      
      public var sellingProfit:Number;
      
      public var stockCrash:Array;
      
      public var stockFlag:Boolean;
      
      public var stockPrice:Array;
      
      public var stockTrend:Array;
      
      public var turn:Number;
      
      public var tutor:Boolean;
      
      public var weather:int;
      
      public var weatherPlanet:int;
      
      public var winner:Number;
      
      public var winningPoint:Number;
      
      public function GameType()
      {
         super();
      }
      
      public function serialize() : ByteArray
      {
         var _loc1_:int = 0;
         var _loc2_:int = 0;
         var _loc3_:int = 0;
         var _loc4_:ByteArray = null;
         _loc4_ = new ByteArray();
         _loc4_.writeInt(this.playerNumberOf);
         _loc4_.writeInt(this.opNumberOf);
         _loc1_ = 0;
         while(_loc1_ < this.playerNumberOf)
         {
            this.p[_loc1_].serialize(_loc4_);
            _loc1_++;
         }
         _loc1_ = 1;
         while(_loc1_ <= this.opNumberOf)
         {
            this.o[_loc1_].serialize(_loc4_);
            _loc1_++;
         }
         _loc4_.writeInt(this.activateTurn);
         _loc4_.writeInt(this.activateZinn);
         _loc4_.writeInt(this.activateSupply);
         _loc4_.writeInt(this.activateLoan);
         _loc4_.writeInt(this.activateInsurance);
         _loc4_.writeInt(this.activateViewCity);
         _loc4_.writeInt(this.activateFuel);
         _loc4_.writeInt(this.activatePassengers);
         _loc4_.writeInt(this.activateCrew);
         _loc4_.writeInt(this.activateAdvertising);
         _loc4_.writeInt(this.activateTax);
         _loc4_.writeInt(this.activateBank);
         _loc4_.writeInt(this.activateWarehouse);
         _loc4_.writeInt(this.activateExplore);
         _loc4_.writeInt(this.activateDistance);
         _loc4_.writeInt(this.activateFacility);
         _loc4_.writeInt(this.activateStock);
         _loc1_ = 0;
         while(_loc1_ <= 6)
         {
            _loc4_.writeDouble(this.advertC[_loc1_]);
            _loc1_++;
         }
         _loc4_.writeInt(this.auction);
         _loc4_.writeInt(this.auctionLast);
         _loc4_.writeInt(this.auctionCompany);
         _loc4_.writeInt(this.auctionNextCompany);
         _loc4_.writeInt(this.auctionCompanyLast);
         _loc4_.writeInt(this.auctionNextCompanyLast);
         _loc4_.writeDouble(this.auctionHighBid);
         _loc4_.writeDouble(this.auctionNextBid);
         _loc4_.writeDouble(this.auctionHighBidLast);
         _loc4_.writeDouble(this.auctionNextBidLast);
         _loc4_.writeInt(this.auctionFacilityType);
         _loc4_.writeInt(this.auctionFacilityPlanet);
         _loc4_.writeDouble(this.auctionFacilityFee);
         _loc4_.writeInt(this.auctionFacilityTypeLast);
         _loc4_.writeInt(this.auctionFacilityPlanetLast);
         _loc4_.writeDouble(this.auctionFacilityFeeLast);
         _loc1_ = 0;
         while(_loc1_ <= 6)
         {
            _loc2_ = 0;
            while(_loc2_ <= 2)
            {
               _loc3_ = 0;
               while(_loc3_ <= 5)
               {
                  _loc4_.writeDouble(this.comR[_loc1_][_loc2_][_loc3_]);
                  _loc4_.writeDouble(this.comP[_loc1_][_loc2_][_loc3_]);
                  _loc4_.writeDouble(this.comA[_loc1_][_loc2_][_loc3_]);
                  _loc3_++;
               }
               _loc2_++;
            }
            _loc1_++;
         }
         _loc4_.writeInt(this.difficulty);
         _loc4_.writeDouble(this.dateYear);
         _loc4_.writeInt(this.exportTariff);
         _loc4_.writeDouble(this.fuelPriceRange);
         _loc1_ = 0;
         while(_loc1_ <= 6)
         {
            _loc4_.writeDouble(this.fuelCost[_loc1_]);
            _loc1_++;
         }
         _loc4_.writeInt(this.game);
         _loc4_.writeInt(this.gameEvent);
         _loc4_.writeInt(this.importTariff);
         _loc4_.writeBoolean(this.isMidTurn);
         _loc4_.writeInt(this.level);
         _loc4_.writeInt(this.news);
         _loc4_.writeInt(this.newsData);
         _loc4_.writeInt(this.newsPlanet);
         _loc4_.writeInt(this.passTax);
         _loc1_ = 0;
         while(_loc1_ <= 6)
         {
            _loc4_.writeInt(this.planetIndex[_loc1_]);
            _loc4_.writeInt(this.planetX[_loc1_]);
            _loc4_.writeInt(this.planetY[_loc1_]);
            _loc1_++;
         }
         _loc4_.writeInt(this.player);
         _loc1_ = 0;
         while(_loc1_ < this.playerNumberOf + this.opNumberOf)
         {
            _loc4_.writeInt(this.playerOrder[_loc1_]);
            _loc1_++;
         }
         _loc4_.writeInt(this.playerTurnCounter);
         _loc4_.writeDouble(this.sellingProfit);
         _loc1_ = 0;
         while(_loc1_ <= 6)
         {
            _loc4_.writeBoolean(this.stockCrash[_loc1_]);
            _loc2_ = 1;
            while(_loc2_ <= 15)
            {
               _loc4_.writeDouble(this.stockPrice[_loc1_][_loc2_]);
               _loc2_++;
            }
            _loc4_.writeInt(this.stockTrend[_loc1_]);
            _loc1_++;
         }
         _loc4_.writeBoolean(this.stockFlag);
         _loc4_.writeDouble(this.turn);
         _loc4_.writeBoolean(this.tutor);
         _loc4_.writeInt(this.weather);
         _loc4_.writeInt(this.weatherPlanet);
         _loc4_.writeDouble(this.winner);
         _loc4_.writeDouble(this.winningPoint);
         return _loc4_;
      }
      
      public function deserialize(param1:ByteArray) : void
      {
         var _loc2_:int = 0;
         var _loc3_:int = 0;
         var _loc4_:int = 0;
         param1.position = 0;
         this.playerNumberOf = param1.readInt();
         this.opNumberOf = param1.readInt();
         this.p = new Array(this.playerNumberOf);
         _loc2_ = 0;
         while(_loc2_ < this.playerNumberOf)
         {
            this.p[_loc2_] = new PlayerType();
            this.p[_loc2_].deserialize(param1);
            _loc2_++;
         }
         this.o = new Array(this.opNumberOf + 1);
         _loc2_ = 1;
         while(_loc2_ <= this.opNumberOf)
         {
            this.o[_loc2_] = new OpponentType();
            this.o[_loc2_].deserialize(param1);
            _loc2_++;
         }
         this.activateTurn = param1.readInt();
         this.activateZinn = param1.readInt();
         this.activateSupply = param1.readInt();
         this.activateLoan = param1.readInt();
         this.activateInsurance = param1.readInt();
         this.activateViewCity = param1.readInt();
         this.activateFuel = param1.readInt();
         this.activatePassengers = param1.readInt();
         this.activateCrew = param1.readInt();
         this.activateAdvertising = param1.readInt();
         this.activateTax = param1.readInt();
         this.activateBank = param1.readInt();
         this.activateWarehouse = param1.readInt();
         this.activateExplore = param1.readInt();
         this.activateDistance = param1.readInt();
         this.activateFacility = param1.readInt();
         this.activateStock = param1.readInt();
         this.advertC = new Array(7);
         _loc2_ = 0;
         while(_loc2_ <= 6)
         {
            this.advertC[_loc2_] = param1.readDouble();
            _loc2_++;
         }
         this.auction = param1.readInt();
         this.auctionLast = param1.readInt();
         this.auctionCompany = param1.readInt();
         this.auctionNextCompany = param1.readInt();
         this.auctionCompanyLast = param1.readInt();
         this.auctionNextCompanyLast = param1.readInt();
         this.auctionHighBid = param1.readDouble();
         this.auctionNextBid = param1.readDouble();
         this.auctionHighBidLast = param1.readDouble();
         this.auctionNextBidLast = param1.readDouble();
         this.auctionFacilityType = param1.readInt();
         this.auctionFacilityPlanet = param1.readInt();
         this.auctionFacilityFee = param1.readDouble();
         this.auctionFacilityTypeLast = param1.readInt();
         this.auctionFacilityPlanetLast = param1.readInt();
         this.auctionFacilityFeeLast = param1.readDouble();
         this.comR = new Array(7);
         this.comP = new Array(7);
         this.comA = new Array(7);
         _loc2_ = 0;
         while(_loc2_ <= 6)
         {
            this.comR[_loc2_] = new Array(3);
            this.comP[_loc2_] = new Array(3);
            this.comA[_loc2_] = new Array(3);
            _loc3_ = 0;
            while(_loc3_ <= 2)
            {
               this.comR[_loc2_][_loc3_] = new Array(6);
               this.comP[_loc2_][_loc3_] = new Array(6);
               this.comA[_loc2_][_loc3_] = new Array(6);
               _loc4_ = 0;
               while(_loc4_ <= 5)
               {
                  this.comR[_loc2_][_loc3_][_loc4_] = param1.readDouble();
                  this.comP[_loc2_][_loc3_][_loc4_] = param1.readDouble();
                  this.comA[_loc2_][_loc3_][_loc4_] = param1.readDouble();
                  _loc4_++;
               }
               _loc3_++;
            }
            _loc2_++;
         }
         this.difficulty = param1.readInt();
         this.dateYear = param1.readDouble();
         this.exportTariff = param1.readInt();
         this.fuelPriceRange = param1.readDouble();
         this.fuelCost = new Array(7);
         _loc2_ = 0;
         while(_loc2_ <= 6)
         {
            this.fuelCost[_loc2_] = param1.readDouble();
            _loc2_++;
         }
         this.game = param1.readInt();
         this.gameEvent = param1.readInt();
         this.importTariff = param1.readInt();
         this.isMidTurn = param1.readBoolean();
         this.level = param1.readInt();
         this.news = param1.readInt();
         this.newsData = param1.readInt();
         this.newsPlanet = param1.readInt();
         this.passTax = param1.readInt();
         this.planetIndex = new Array(7);
         this.planetX = new Array(7);
         this.planetY = new Array(7);
         _loc2_ = 0;
         while(_loc2_ <= 6)
         {
            this.planetIndex[_loc2_] = param1.readInt();
            this.planetX[_loc2_] = param1.readInt();
            this.planetY[_loc2_] = param1.readInt();
            _loc2_++;
         }
         this.player = param1.readInt();
         this.playerOrder = new Array(this.playerNumberOf + this.opNumberOf);
         _loc2_ = 0;
         while(_loc2_ < this.playerNumberOf + this.opNumberOf)
         {
            this.playerOrder[_loc2_] = param1.readInt();
            _loc2_++;
         }
         this.playerTurnCounter = param1.readInt();
         this.sellingProfit = param1.readDouble();
         this.stockCrash = new Array(7);
         this.stockPrice = new Array(7);
         this.stockTrend = new Array(7);
         _loc2_ = 0;
         while(_loc2_ <= 6)
         {
            this.stockCrash[_loc2_] = param1.readBoolean();
            this.stockPrice[_loc2_] = new Array(16);
            _loc3_ = 1;
            while(_loc3_ <= 15)
            {
               this.stockPrice[_loc2_][_loc3_] = param1.readDouble();
               _loc3_++;
            }
            this.stockTrend[_loc2_] = param1.readInt();
            _loc2_++;
         }
         this.stockFlag = param1.readBoolean();
         this.turn = param1.readDouble();
         this.tutor = param1.readBoolean();
         this.weather = param1.readInt();
         this.weatherPlanet = param1.readInt();
         this.winner = param1.readDouble();
         this.winningPoint = param1.readDouble();
      }
   }
}

