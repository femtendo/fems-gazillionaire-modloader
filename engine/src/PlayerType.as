package
{
   import flash.utils.ByteArray;
   
   public class PlayerType
   {
      
      public var advertInvestedP:Number;
      
      public var advertInvestedC:Number;
      
      public var advertFixP:Number;
      
      public var advertFixC:Number;
      
      public var advertP:Number;
      
      public var age:int;
      
      public var bankrupt:Boolean;
      
      public var comS:Array;
      
      public var comPP:Array;
      
      public var cargoTons:Number;
      
      public var cargoCapacity:Number;
      
      public var cash:Number;
      
      public var crew:int;
      
      public var crewSalary:Number;
      
      public var crewWagesOwed:Number;
      
      public var engine:int;
      
      public var eventGood:int;
      
      public var eventLastGood:Boolean;
      
      public var facility:Array;
      
      public var facilityFee:Array;
      
      public var facilityRevenue:Array;
      
      public var fuel:Number;
      
      public var fuelCapacity:Number;
      
      public var history:Array;
      
      public var insurance:Boolean;
      
      public var insurancePriceRange:Number;
      
      public var insuranceCost:Number;
      
      public var loan:Number;
      
      public var loanRate:int;
      
      public var loanInterest:Number;
      
      public var loanMax:Number;
      
      public var netWorth:Number;
      
      public var planet:int;
      
      public var planetLast:int;
      
      public var playerShip:int;
      
      public var playerName:String;
      
      public var playerNameShort:String;
      
      public var quickWarehouse:Boolean;
      
      public var quickBuy:Boolean;
      
      public var quickDeposit:Boolean;
      
      public var quickBank:Boolean;
      
      public var quickLoan:Boolean;
      
      public var quickAdvertising:Boolean;
      
      public var quickCrew:Boolean;
      
      public var quickFuel:Boolean;
      
      public var quickExplore:Boolean;
      
      public var quickTravel:Boolean;
      
      public var quickPassengers:Boolean;
      
      public var quickTax:Boolean;
      
      public var quickInsurance:Boolean;
      
      public var random:int;
      
      public var sabotageDamage:Number;
      
      public var savings:Number;
      
      public var savingsRate:int;
      
      public var savingsInterest:Number;
      
      public var sharePrice:Array;
      
      public var share:Array;
      
      public var shipTons:int;
      
      public var supplyPlanet:int;
      
      public var travelTime:Number;
      
      public var travelDelayed:Number;
      
      public var turnTaken:Boolean;
      
      public var passengers:Number;
      
      public var passengerCapacity:Number;
      
      public var passT:Number;
      
      public var passTicketPrice:Number;
      
      public var profitPerPassenger:Number;
      
      public var passFlag:Boolean;
      
      public var planetSpecialFlag:Boolean;
      
      public var tariff:Number;
      
      public var tax:Number;
      
      public var warehouseSpace:Number;
      
      public var warehouse:Array;
      
      public var warehouseGoodsValue:Array;
      
      public var warehouseT:Array;
      
      public var zinnLoan:Number;
      
      public var zinnMax:Number;
      
      public var zinnRate:int;
      
      public var zinnInterest:Number;
      
      public function PlayerType()
      {
         super();
      }
      
      public function serialize(param1:ByteArray) : void
      {
         var _loc2_:int = 0;
         var _loc3_:int = 0;
         var _loc4_:int = 0;
         param1.writeDouble(this.advertInvestedP);
         param1.writeDouble(this.advertInvestedC);
         param1.writeDouble(this.advertFixP);
         param1.writeDouble(this.advertFixC);
         param1.writeDouble(this.advertP);
         param1.writeInt(this.age);
         param1.writeBoolean(this.bankrupt);
         _loc2_ = 0;
         while(_loc2_ <= 2)
         {
            _loc3_ = 0;
            while(_loc3_ <= 5)
            {
               param1.writeDouble(this.comS[_loc2_][_loc3_]);
               param1.writeDouble(this.comPP[_loc2_][_loc3_]);
               _loc3_++;
            }
            _loc2_++;
         }
         param1.writeDouble(this.cargoCapacity);
         param1.writeDouble(this.cash);
         param1.writeInt(this.crew);
         param1.writeDouble(this.crewSalary);
         param1.writeDouble(this.crewWagesOwed);
         param1.writeInt(this.engine);
         param1.writeInt(this.eventGood);
         param1.writeBoolean(this.eventLastGood);
         _loc2_ = 0;
         while(_loc2_ <= 6)
         {
            param1.writeInt(this.facility[_loc2_]);
            param1.writeDouble(this.facilityFee[_loc2_]);
            param1.writeDouble(this.facilityRevenue[_loc2_]);
            _loc2_++;
         }
         param1.writeDouble(this.fuel);
         param1.writeDouble(this.fuelCapacity);
         _loc2_ = 0;
         while(_loc2_ <= 20)
         {
            param1.writeDouble(this.history[_loc2_]);
            _loc2_++;
         }
         param1.writeBoolean(this.insurance);
         param1.writeDouble(this.insurancePriceRange);
         param1.writeDouble(this.insuranceCost);
         param1.writeDouble(this.loan);
         param1.writeInt(this.loanRate);
         param1.writeDouble(this.loanInterest);
         param1.writeDouble(this.loanMax);
         param1.writeDouble(this.netWorth);
         param1.writeInt(this.planet);
         param1.writeInt(this.planetLast);
         param1.writeInt(this.playerShip);
         param1.writeUTF(this.playerName);
         param1.writeUTF(this.playerNameShort);
         param1.writeBoolean(this.quickWarehouse);
         param1.writeBoolean(this.quickBuy);
         param1.writeBoolean(this.quickDeposit);
         param1.writeBoolean(this.quickBank);
         param1.writeBoolean(this.quickLoan);
         param1.writeBoolean(this.quickAdvertising);
         param1.writeBoolean(this.quickCrew);
         param1.writeBoolean(this.quickFuel);
         param1.writeBoolean(this.quickExplore);
         param1.writeBoolean(this.quickTravel);
         param1.writeBoolean(this.quickPassengers);
         param1.writeBoolean(this.quickTax);
         param1.writeBoolean(this.quickInsurance);
         param1.writeInt(this.random);
         param1.writeDouble(this.sabotageDamage);
         param1.writeDouble(this.savings);
         param1.writeInt(this.savingsRate);
         param1.writeDouble(this.savingsInterest);
         _loc2_ = 0;
         while(_loc2_ <= 6)
         {
            param1.writeDouble(this.sharePrice[_loc2_]);
            param1.writeDouble(this.share[_loc2_]);
            _loc2_++;
         }
         param1.writeInt(this.shipTons);
         param1.writeInt(this.supplyPlanet);
         param1.writeDouble(this.travelTime);
         param1.writeDouble(this.travelDelayed);
         param1.writeBoolean(this.turnTaken);
         param1.writeDouble(this.passengers);
         param1.writeDouble(this.passengerCapacity);
         param1.writeDouble(this.passT);
         param1.writeDouble(this.passTicketPrice);
         param1.writeDouble(this.profitPerPassenger);
         param1.writeBoolean(this.passFlag);
         param1.writeBoolean(this.planetSpecialFlag);
         param1.writeDouble(this.tariff);
         param1.writeDouble(this.tax);
         param1.writeDouble(this.warehouseSpace);
         _loc2_ = 0;
         while(_loc2_ <= 6)
         {
            _loc3_ = 0;
            while(_loc3_ <= 2)
            {
               _loc4_ = 0;
               while(_loc4_ <= 5)
               {
                  param1.writeDouble(this.warehouse[_loc2_][_loc3_][_loc4_]);
                  param1.writeDouble(this.warehouseGoodsValue[_loc2_][_loc3_][_loc4_]);
                  _loc4_++;
               }
               _loc3_++;
            }
            _loc2_++;
         }
         param1.writeDouble(this.zinnLoan);
         param1.writeDouble(this.zinnMax);
         param1.writeInt(this.zinnRate);
         param1.writeDouble(this.zinnInterest);
      }
      
      public function deserialize(param1:ByteArray) : void
      {
         var _loc2_:int = 0;
         var _loc3_:int = 0;
         var _loc4_:int = 0;
         this.advertInvestedP = param1.readDouble();
         this.advertInvestedC = param1.readDouble();
         this.advertFixP = param1.readDouble();
         this.advertFixC = param1.readDouble();
         this.advertP = param1.readDouble();
         this.age = param1.readInt();
         this.bankrupt = param1.readBoolean();
         this.cargoTons = 0;
         this.comS = new Array(3);
         this.comPP = new Array(3);
         _loc2_ = 0;
         while(_loc2_ <= 2)
         {
            this.comS[_loc2_] = new Array(6);
            this.comPP[_loc2_] = new Array(6);
            _loc3_ = 0;
            while(_loc3_ <= 5)
            {
               this.comS[_loc2_][_loc3_] = param1.readDouble();
               this.comPP[_loc2_][_loc3_] = param1.readDouble();
               this.cargoTons += this.comS[_loc2_][_loc3_];
               _loc3_++;
            }
            _loc2_++;
         }
         this.cargoCapacity = param1.readDouble();
         this.cash = param1.readDouble();
         this.crew = param1.readInt();
         this.crewSalary = param1.readDouble();
         this.crewWagesOwed = param1.readDouble();
         this.engine = param1.readInt();
         this.eventGood = param1.readInt();
         this.eventLastGood = param1.readBoolean();
         this.facility = new Array(7);
         this.facilityFee = new Array(7);
         this.facilityRevenue = new Array(7);
         _loc2_ = 0;
         while(_loc2_ <= 6)
         {
            this.facility[_loc2_] = param1.readInt();
            this.facilityFee[_loc2_] = param1.readDouble();
            this.facilityRevenue[_loc2_] = param1.readDouble();
            _loc2_++;
         }
         this.fuel = param1.readDouble();
         this.fuelCapacity = param1.readDouble();
         this.history = new Array(21);
         _loc2_ = 0;
         while(_loc2_ <= 20)
         {
            this.history[_loc2_] = param1.readDouble();
            _loc2_++;
         }
         this.insurance = param1.readBoolean();
         this.insurancePriceRange = param1.readDouble();
         this.insuranceCost = param1.readDouble();
         this.loan = param1.readDouble();
         this.loanRate = param1.readInt();
         this.loanInterest = param1.readDouble();
         this.loanMax = param1.readDouble();
         this.netWorth = param1.readDouble();
         this.planet = param1.readInt();
         this.planetLast = param1.readInt();
         this.playerShip = param1.readInt();
         this.playerName = param1.readUTF();
         this.playerNameShort = param1.readUTF();
         this.quickWarehouse = param1.readBoolean();
         this.quickBuy = param1.readBoolean();
         this.quickDeposit = param1.readBoolean();
         this.quickBank = param1.readBoolean();
         this.quickLoan = param1.readBoolean();
         this.quickAdvertising = param1.readBoolean();
         this.quickCrew = param1.readBoolean();
         this.quickFuel = param1.readBoolean();
         this.quickExplore = param1.readBoolean();
         this.quickTravel = param1.readBoolean();
         this.quickPassengers = param1.readBoolean();
         this.quickTax = param1.readBoolean();
         this.quickInsurance = param1.readBoolean();
         this.random = param1.readInt();
         this.sabotageDamage = param1.readDouble();
         this.savings = param1.readDouble();
         this.savingsRate = param1.readInt();
         this.savingsInterest = param1.readDouble();
         this.sharePrice = new Array(7);
         this.share = new Array(7);
         _loc2_ = 0;
         while(_loc2_ <= 6)
         {
            this.sharePrice[_loc2_] = param1.readDouble();
            this.share[_loc2_] = param1.readDouble();
            _loc2_++;
         }
         this.shipTons = param1.readInt();
         this.supplyPlanet = param1.readInt();
         this.travelTime = param1.readDouble();
         this.travelDelayed = param1.readDouble();
         this.turnTaken = param1.readBoolean();
         this.passengers = param1.readDouble();
         this.passengerCapacity = param1.readDouble();
         this.passT = param1.readDouble();
         this.passTicketPrice = param1.readDouble();
         this.profitPerPassenger = param1.readDouble();
         this.passFlag = param1.readBoolean();
         this.planetSpecialFlag = param1.readBoolean();
         this.tariff = param1.readDouble();
         this.tax = param1.readDouble();
         this.warehouseSpace = param1.readDouble();
         this.warehouse = new Array(7);
         this.warehouseGoodsValue = new Array(7);
         this.warehouseT = new Array(7);
         _loc2_ = 0;
         while(_loc2_ <= 6)
         {
            this.warehouse[_loc2_] = new Array(3);
            this.warehouseGoodsValue[_loc2_] = new Array(3);
            this.warehouseT[_loc2_] = 0;
            _loc3_ = 0;
            while(_loc3_ <= 2)
            {
               this.warehouse[_loc2_][_loc3_] = new Array(6);
               this.warehouseGoodsValue[_loc2_][_loc3_] = new Array(6);
               _loc4_ = 0;
               while(_loc4_ <= 5)
               {
                  this.warehouse[_loc2_][_loc3_][_loc4_] = param1.readDouble();
                  this.warehouseGoodsValue[_loc2_][_loc3_][_loc4_] = param1.readDouble();
                  this.warehouseT[_loc2_] += this.warehouse[_loc2_][_loc3_][_loc4_];
                  _loc4_++;
               }
               _loc3_++;
            }
            _loc2_++;
         }
         this.zinnLoan = param1.readDouble();
         this.zinnMax = param1.readDouble();
         this.zinnRate = param1.readInt();
         this.zinnInterest = param1.readDouble();
      }
      
      public function f_rnd(param1:Number, param2:Number) : int
      {
         return Math.floor(param1 + Math.random() * (param2 - param1 + 1));
      }
      
      public function init(param1:int, param2:int) : void
      {
         var _loc3_:int = 0;
         var _loc4_:int = 0;
         var _loc5_:int = 0;
         if(param1 == 1)
         {
            this.cash = 50000;
            this.eventGood = 85;
            this.zinnLoan = 100000;
         }
         else if(param1 == 2)
         {
            this.cash = 25000;
            this.eventGood = 75;
            this.zinnLoan = 110000;
         }
         else if(param1 == 3)
         {
            this.cash = 0;
            this.eventGood = 65;
            this.zinnLoan = 120000;
         }
         else if(param1 == 4)
         {
            this.cash = 0;
            this.eventGood = 55;
            this.zinnLoan = 130000;
         }
         else if(param1 == 5)
         {
            this.cash = 0;
            this.eventGood = 50;
            this.zinnLoan = 140000;
         }
         else
         {
            this.cash = 0;
            this.eventGood = 50;
            this.zinnLoan = 150000;
         }
         this.age = this.f_rnd(17,50);
         this.advertInvestedP = 0;
         this.advertInvestedC = 0;
         this.advertFixP = 0;
         this.advertFixC = 0;
         this.advertP = 0;
         this.bankrupt = false;
         this.comS = new Array(3);
         this.comPP = new Array(3);
         _loc3_ = 0;
         while(_loc3_ <= 2)
         {
            this.comS[_loc3_] = new Array(6);
            this.comPP[_loc3_] = new Array(6);
            _loc4_ = 0;
            while(_loc4_ <= 5)
            {
               this.comS[_loc3_][_loc4_] = 0;
               this.comPP[_loc3_][_loc4_] = 0;
               _loc4_++;
            }
            _loc3_++;
         }
         this.cargoTons = 0;
         this.cargoCapacity = 100;
         this.crew = 4;
         this.crewSalary = 1500;
         this.crewWagesOwed = 0;
         this.engine = 5;
         this.eventLastGood = true;
         this.facility = new Array(7);
         this.facilityFee = new Array(7);
         this.facilityRevenue = new Array(7);
         _loc4_ = 0;
         while(_loc4_ <= 6)
         {
            this.facility[_loc4_] = 0;
            this.facilityFee[_loc4_] = 0;
            this.facilityRevenue[_loc4_] = 0;
            _loc4_++;
         }
         this.fuel = 50;
         this.fuelCapacity = 50;
         this.netWorth = this.cash - this.zinnLoan;
         this.history = new Array(21);
         this.history[0] = this.netWorth + 0.01 * param2 * this.netWorth;
         this.history[1] = this.netWorth;
         this.insurance = false;
         this.insurancePriceRange = 15;
         this.insuranceCost = this.f_rnd(this.insurancePriceRange,this.insurancePriceRange * 1000);
         this.loan = 0;
         this.loanRate = 5;
         this.loanInterest = 0;
         this.loanMax = 100000;
         this.passengers = 0;
         this.passengerCapacity = 8;
         this.passT = 0;
         this.passTicketPrice = 1000;
         this.profitPerPassenger = 1000;
         this.passFlag = false;
         this.planet = param2;
         this.planetLast = param2 + 1;
         this.planetSpecialFlag = false;
         this.playerName = "";
         this.playerNameShort = "";
         this.playerShip = 0;
         this.quickWarehouse = false;
         this.quickBuy = false;
         this.quickDeposit = false;
         this.quickBank = false;
         this.quickLoan = false;
         this.quickAdvertising = false;
         this.quickCrew = false;
         this.quickFuel = false;
         this.quickExplore = false;
         this.quickTravel = false;
         this.quickPassengers = false;
         this.quickTax = false;
         this.quickInsurance = false;
         this.random = this.f_rnd(1,100);
         this.sabotageDamage = 0;
         this.savings = 0;
         this.savingsRate = 1;
         this.savingsInterest = 0;
         this.sharePrice = new Array(7);
         this.share = new Array(7);
         _loc3_ = 0;
         while(_loc3_ <= 6)
         {
            this.sharePrice[_loc3_] = 0;
            this.share[_loc3_] = 0;
            _loc3_++;
         }
         this.shipTons = 400;
         this.supplyPlanet = -1;
         this.tariff = 0;
         this.tax = 0;
         this.travelTime = 0;
         this.travelDelayed = 1;
         this.turnTaken = false;
         this.warehouseSpace = 50;
         this.warehouse = new Array(7);
         this.warehouseGoodsValue = new Array(7);
         this.warehouseT = new Array(7);
         _loc3_ = 0;
         while(_loc3_ <= 6)
         {
            this.warehouse[_loc3_] = new Array(3);
            this.warehouseGoodsValue[_loc3_] = new Array(3);
            _loc4_ = 0;
            while(_loc4_ <= 2)
            {
               this.warehouse[_loc3_][_loc4_] = new Array(6);
               this.warehouseGoodsValue[_loc3_][_loc4_] = new Array(6);
               _loc5_ = 0;
               while(_loc5_ <= 5)
               {
                  this.warehouse[_loc3_][_loc4_][_loc5_] = 0;
                  this.warehouseGoodsValue[_loc3_][_loc4_][_loc5_] = 0;
                  _loc5_++;
               }
               _loc4_++;
            }
            this.warehouseT[_loc3_] = 0;
            _loc3_++;
         }
         this.zinnMax = 200000;
         this.zinnRate = 4;
         this.zinnInterest = 0;
      }
   }
}

