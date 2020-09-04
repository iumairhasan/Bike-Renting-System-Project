-- DDL FOR PEDAL ---------------------------------------
USE PROJECT_GROUP_18;

CREATE TABLE [Address] (
  [AddressID] INT IDENTITY NOT NULL PRIMARY KEY,
  [Area] Varchar(20) NOT NULL,
  [PinCode] INT NOT NULL,
  [City] Varchar(20) NOT NULL,
  [State] Varchar(20) NOT NULL,
);

CREATE TABLE [Users] (
  [UserID] INT IDENTITY NOT NULL PRIMARY KEY ,
  [ContactNumber] Varchar(15) NOT NULL,
  [FirstName] Varchar(20),
  [LastName] Varchar(20),
  [DOB] Date,
  [IsActive] BIT DEFAULT '1' NOT NULL,
  [Username] Varchar(30) NOT NULL UNIQUE,
  [Password] Varchar(30) NOT NULL,
  [AadharID] Varchar(30) NOT NULL,
  [AddressID] INT NOT NULL REFERENCES [Address](AddressID)
);


CREATE TABLE [Wallet] (
  [WalletID] INT IDENTITY NOT NULL PRIMARY KEY,
  [WalletAmount] FLOAT NOT NULL,
  [UserID] INT NOT NULL UNIQUE REFERENCES Users(UserID),
);

CREATE TABLE [Transactions] (
  [TransactionID] INT IDENTITY NOT NULL PRIMARY KEY ,
  [TransactionBy] INT NOT NULL REFERENCES Users(UserID),
  [TransactionAmount] FLOAT NOT NULL,
  [TransactionType] Varchar(20) NOT NULL
  CHECK(TransactionType IN ('Debit','Credit')),
  [CreatedAt] DateTime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  [TransactionStatus] Varchar(20) NOT NULL
  CHECK(TransactionStatus IN ('Successful','Failed'))
);

CREATE TABLE [Groups] (
  [GroupID] INT IDENTITY NOT NULL PRIMARY KEY,
  [Name] Varchar(20) NOT NULL
);

CREATE TABLE [Memberships] (
  [MembershipID] INT IDENTITY NOT NULL PRIMARY KEY,
  [MembershipType] Varchar(20) NOT NULL
);

CREATE TABLE [UserMemberships] (
  [UserID] INT NOT NULL REFERENCES Users(UserID),
  [MembershipID] INT NOT NULL REFERENCES Memberships(MembershipID),
  [StartDate] Date NOT NULL DEFAULT GETDATE(), 
  [EndDate] Date NOT NULL,
  CONSTRAINT PK_UserMemberships PRIMARY KEY CLUSTERED
 (UserID,MembershipID)
);

CREATE TABLE [UserGroups] (
  [UserID] INT NOT NULL REFERENCES Users(UserID),
  [GroupID] INT IDENTITY NOT NULL REFERENCES Groups(GroupID),
  [isActive] BIT default '1' NOT NULL,
  CONSTRAINT PK_UserGroups PRIMARY KEY CLUSTERED
 (UserID,GroupID)
);

CREATE TABLE [Discount] (
  [DiscountID] INT IDENTITY NOT NULL PRIMARY KEY,
  [CouponName] Varchar(30) NOT NULL,
  [Percentage] FLOAT NOT NULL,
  [StartDate] Date NOT NULL,
  [EndDate] Date NOT NULL,
  [IsActive] BIT default '1' NOT NULL,
  [MembershipID] INT NOT NULL REFERENCES Memberships(MembershipID)
);

CREATE TABLE [Bookings] (
  [BookingID] INT IDENTITY NOT NULL PRIMARY KEY,
  [CreatedAt] DateTime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  [Purpose] Varchar(30) NOT NULL, 
  [BookingStatus] Varchar(30) NOT NULL
  CHECK(BookingStatus IN ('Cancelled','Booked')),
  [UserID] INT NOT NULL REFERENCES Users(UserID),
  [RideDate] Date NOT NULL,
  [RideTime] Time NOT NULL,
  [DiscountID] INT REFERENCES Discount(DiscountID)
);

CREATE TABLE [BikeCategory] (
  [BikeCategoryID] INT IDENTITY NOT NULL PRIMARY KEY,
  [Name] Varchar(20) NOT NULL
);

CREATE TABLE [Bikes] (
  [BikeID] INT IDENTITY NOT NULL PRIMARY KEY,
  [Model] Varchar(30) NOT NULL,
  [SerialNumber] Varchar(20) NOT NULL UNIQUE,
  [IsActive] BIT default '1' NOT NULL,
  [OwnerID] INT NOT NULL REFERENCES Users(UserID),
  [BikeCategoryID] INT NOT NULL REFERENCES Bikecategory(BikeCategoryID)
);

CREATE TABLE [Stations] (
  [StationID] INT IDENTITY NOT NULL PRIMARY KEY,
  [Name] Varchar(20) NOT NULL,
  [AddressID] INT NOT NULL UNIQUE REFERENCES [Address](AddressID)
);

CREATE TABLE [BikeStations] (
  [BikeStationID] INT NOT NULL IDENTITY PRIMARY KEY,
  [BikeID] INT NOT NULL REFERENCES Bikes(BikeID),
  [StationID] INT NOT NULL REFERENCES Stations(StationID),
  [BikeStatus] Varchar(30) NOT NULL CHECK(BikeStatus IN ('Available','Not Available')),
  [AvailableTime] DateTime
);

CREATE TABLE [Trips] (
  [TripID] INT IDENTITY NOT NULL PRIMARY KEY,
  [TripStatus] Varchar(20) NOT NULL CHECK(TripStatus IN ('On Trip', 'Completed', 'Cancelled')) DEFAULT 'On Trip' ,
  [StartDateTime] DateTime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  [EndDateTime] DateTime,
  [BookingID] INT NOT NULL UNIQUE,
  [CreatedAt] DateTime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  [StartBikeStationID] INT NOT NULL REFERENCES BikeStations(BikeStationID),
  [EndBikeStationID] INT REFERENCES BikeStations(BikeStationID),
  [TripType] Varchar(20) NOT NULL CHECK(TripType IN ('By User','By Owner')),
  );

CREATE TABLE [RentalRates] (
  [RentalRatesID] INT IDENTITY NOT NULL PRIMARY KEY,
  [RentType] Varchar(20) NOT NULL,
  [Rate] FLOAT NOT NULL
);

CREATE TABLE [Billing] (
  [BillID] INT IDENTITY NOT NULL PRIMARY KEY,
  [TripID] INT NOT NULL UNIQUE REFERENCES Trips(TripID),
  [RateID] INT NOT NULL REFERENCES RentalRates(RentalRatesID),
  [UserID] INT NOT NULL REFERENCES Users(UserID),
  [BillingStatus] Varchar(20)
  CHECK(BillingStatus IN ('Successful','Failed')),
  [TotalAmount] FLOAT NOT NULL,
  [CreatedAt] Date NOT NULL DEFAULT CURRENT_TIMESTAMP,
  [BillingType] Varchar(20) NOT NULL
  CHECK(BillingType IN ('Debit','Credit')),
);

ALTER TABLE dbo.Billing
DROP COLUMN TotalAmount

ALTER TABLE dbo.Billing
ADD TotalAmount AS (dbo.CalculateTotalAmount(TripID, RateID));