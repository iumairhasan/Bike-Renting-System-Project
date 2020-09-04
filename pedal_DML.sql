-------------------------------------------------------------------------
-- DML 
--Stored procedure for BikeCategory
CREATE PROCEDURE dbo.AddUpdateBikeCategory
  @BikeCategoryID INT = NULL,
  @Name Varchar(30)
  AS
      BEGIN
          IF @BikeCategoryID IS NOT NULL
              BEGIN
              DECLARE @check int; 
              SELECT @check = (select BikeCategoryID FROM Bikecategory WHERE BikeCategoryID=@BikeCategoryID)
                  IF @check IS NOT NULL
                      UPDATE [dbo].[BikeCategory]
                      SET
                          [Name] = @Name
                      WHERE BikecategoryID = @BikeCategoryID;
                  ELSE 
                      PRINT('No bike cagtegory ID found')
              END
          ELSE 
              INSERT INTO [dbo].[BikeCategory] ([Name])
              VALUES(@Name)
      END

EXECUTE dbo.AddUpdateBikeCategory @Name="Gear"
DROP PROCEDURE dbo.AddUpdateBikeCategory

--------------------------------------------------------------------------
-- Stored Procedure for Start Trip for User
CREATE PROCEDURE dbo.StartTrip
  @BookingID INT,
  @StationID INT,
  @BikeID INT,
  @TripType Varchar(10)
  AS
    BEGIN
      DECLARE @BikeStatus Varchar(30);
      -- Check Bike is Available at BikeStation
      IF (SELECT [BikeStatus] FROM [dbo].[BikeStations] WHERE StationID = @StationID AND BikeID = @BikeID) = 'Available'
        BEGIN
        -- Insert Trip
          DECLARE @StartBikeStationID INT;
          SELECT @StartBikeStationID = [BikeStationID] FROM [dbo].[BikeStations] WHERE StationID = @StationID AND BikeID = @BikeID
          
          INSERT INTO [dbo].[Trips] ([BookingID], [StartBikeStationID], [TripType])
          VALUES (@BookingID, @StartBikeStationID, @TripType);
          BEGIN
            -- Update BikeStation
            IF (@TripType = 'By User')
              SET @BikeStatus = 'Not Available';
            ELSE IF (@TripType = 'By Owner')
              SET @BikeStatus = 'Available';
              
            UPDATE [dbo].[BikeStations]
            SET
              [BikeStatus] = @BikeStatus,
              [AvailableTime] = CURRENT_TIMESTAMP
            WHERE BikeStationID = @StartBikeStationID
          END
        END
      ELSE 
        PRINT('Bike At This Station Is not Available')
    END

EXECUTE dbo.StartTrip @BookingID=25, @StationID=3, @BikeID= 1, @TripType='By User'
DROP PROCEDURE dbo.StartTrip

--------------------------------------------------------------------------
-- Stored Procedure for End Trip For User and Owner
CREATE PROCEDURE dbo.EndTrip 
  @TripID Int,
  @StationID Int
  AS
    BEGIN
      DECLARE @BikeStatus VARCHAR(30);
      DECLARE @TripType Varchar(20);
      --Check If Bike is available at particular station. If NOT available create a new bike station else update
      DECLARE @BikeID INT;
      SELECT @BikeID = [BikeID] , @TripType=[TripType] FROM Trips t INNER JOIN BikeStations s ON t.StartBikeStationID = s.BikeStationID Where TripID = @TripID
      IF Exists (SELECT StationID,BikeID FROM BikeStations s WHERE (s.BikeID = @BikeID AND s.StationID = @StationID))
        -- Update BikeStation
        BEGIN
          IF (@TripType = 'By User')
            SET @BikeStatus ='Available'
          ELSE IF(@TripType = 'By Owner')
            SET @BikeStatus = 'Not Available'
          UPDATE [dbo].[BikeStations]
          SET
            [BikeStatus] = @BikeStatus,
            [AvailableTime] = CURRENT_TIMESTAMP
          WHERE StationID = @StationID AND BikeID = @BikeID
        END
      ELSE
        --Create/ Insert BikeStation
        BEGIN
          IF (@TripType = 'By User')
            SET @BikeStatus ='Available'
          ELSE IF(@TripType = 'By Owner')
            SET @BikeStatus = 'Not Available'
          INSERT INTO [dbo].[BikeStations]([BikeID],[StationID],[BikeStatus],[AvailableTime]) 
          values(@BikeID,@StationID,@BikeStatus,CURRENT_TIMESTAMP)
		    END
	    --Update Trip
		  UPDATE [dbo].[Trips]
		  SET
			[TripStatus] = 'Completed',
			[EndDateTime] = CURRENT_TIMESTAMP,
			[EndBikeStationID] = (SELECT BikeStationID FROM BikeStations WHERE StationID = @StationID AND BikeID = @BikeID)
		  WHERE TripID = @TripID;
		END

EXECUTE dbo.EndTrip @TripID=11 , @StationID=4;
DROP PROCEDURE [dbo].[EndTrip]

---------------------------------------------------------------------------
-- Stored Procedure for Billing Of User or Owner
CREATE PROCEDURE [dbo].[AddBilling]
  @TripID INT
  AS
    BEGIN
      DECLARE @Hours FLOAT, @Minutes FLOAT, @Rate FLOAT, @Time FLOAT;
      DECLARE @BillingType Varchar(20), @TripType Varchar(20);
      DECLARE @RentalRatesID INT, @TotalAmount FLOAT, @TAmount FLOAT, @UserID INT;
      DECLARE @StartTime DATETIME, @EndTime DATETIME;
      DECLARE @BillingStatus Varchar(20) = 'Successful';
	    DECLARE @Percentage FLOAT;
	    DECLARE @BookingID INT
      SELECT @UserID=[UserID], @TripType=[TripType], @StartTime=[StartDateTime], @EndTime=[EndDateTime]  
      FROM Trips t INNER JOIN Bookings b ON t.BookingID = b.BookingID 
      WHERE t.TripID = @TripID
      SET @Minutes = DATEDIFF(Minute, @StartTime, @EndTime);
	    SET @Hours = @Minutes/60
      IF (@TripType = 'By User')
        BEGIN
          SET @BillingType = 'Debit'
          IF (@Hours < 24)
            BEGIN
            SET @Time = @Hours; 
            SET @RentalRatesID = 1 ;
            END
          ELSE
            BEGIN
            SET @Time = @Hours/24;
            SET @RentalRatesID = 2;
            END
        END
      ELSE IF (@TripType = 'By Owner')
        BEGIN
          SET @BillingType = 'Credit'
          IF (@Hours < 24) 
            BEGIN
            SET @Time = @Hours; SET @RentalRatesID = 3;
            END
          ELSE
            BEGIN
            SET @Time = @Hours/24; SET @RentalRatesID = 4;
            END
        END
      -- can be done using function
      -- SELECT @BookingID = (SELECT b.BookingID FROM Trips t INNER JOIN Bookings b ON t.BookingID = b.BookingID WHERE t.TripID = @TripID)
      -- SELECT @Percentage = (SELECT [Percentage] FROM Discount d INNER JOIN Bookings b ON d.DiscountID = b.DiscountID WHERE b.BookingID = @BookingID )
      -- IF @Percentage IS NULL 
      --   SET @Percentage = 0.0
      -- SELECT @Rate = (SELECT Rate FROM RentalRates WHERE RentalRatesID = @RentalRatesID)
      -- SET @TAmount = @Rate * @Time 
      -- SET @TotalAmount = @TAmount - (@Percentage*@TAmount)/100
  ​
      INSERT INTO [dbo].[Billing] ([TripID], [RateID], [UserID], [BillingStatus], [BillingType])
      VALUES (@TripID, @RentalRatesID, @UserID, @BillingStatus, @BillingType)
    END

EXECUTE [dbo].[AddBilling] @TripID=1;

DELETE FROM [dbo].[Billing] WHERE TripID=1
DROP PROCEDURE [dbo].[AddBilling]
UPDATE [dbo].[Trips] SET [EndDateTime] = dateadd(HOUR, 1, getdate()) WHERE TripID= 11
SELECT * FROM BILLING
DELETE FROM [dbo].[Billing] WHERE TripID=1
SELECT * FROM RentalRates

----------------------------------------------------------------------------
--Stored Procedure for Addtransactions :
CREATE Procedure dbo.AddTransactions
	@TransactionBy INT,
	@TransactionAmount Float,
  @TransactionType Varchar(20)
  AS
  BEGIN
      DECLARE @TransactionStatus Varchar(20) = 'Successful';
      DECLARE @WalletAmount FLOAT;

      IF @TransactionType = 'Debit'
        BEGIN
          Select @WalletAmount = [WalletAmount] FROM [Wallet] WHERE UserID = @TransactionBy
          IF @TransactionAmount > @WalletAmount
            RAISERROR('Transaction Failed ! You are trying t0 withdraw more amount than your wallet amount',16,1)
        END
      
      INSERT INTO [dbo].[Transactions] ([TransactionBy],[TransactionAmount],[TransactionType],[Transactionstatus])
      VALUES (@TransactionBy,@TransactionAmount,@TransactionType,@TransactionStatus)

      IF @TransactionType = 'Debit'
        UPDATE [dbo].[Wallet] SET [WalletAmount] = [WalletAmount] - @TransactionAmount WHERE UserID = @TransactionBy
      ELSE 
        UPDATE [dbo].[Wallet] SET [WalletAmount] = [WalletAmount] + @TransactionAmount WHERE UserID = @TransactionBy
  END

EXECUTE dbo.AddTransactions @TransactionBy= 13, @TransactionAmount = 500, @TransactionType = 'Credit';

DROP PROCEDURE dbo.AddTransactions;

----------------------------------------------------------------------------
-- Stored Procedure for User

CREATE PROCEDURE dbo.AddUpdateUser
  @UserID INT = NULL,
  @ContactNumber Varchar(15),
  @FirstName Varchar(20),
  @LastName Varchar(20),
  @DOB date,
  @Username varchar(30),
  @Password varchar(30),
  @AadharID varchar(30),
  @AddressID INT
  ​
  AS
    BEGIN
      IF @UserID IS NOT NULL
        --update the row in table "TableName" in schema [dbo]
        UPDATE [dbo].[Users]
        SET
          [ContactNumber] = @ContactNumber,
          [FirstName] = @FirstName,
          [LastName] = @LastName,
          [DOB] = @DOB,
          --[IsActive] = @IsActive
          [Username] = @UserName,
          [Password] = @Password,
          [AadharID] = @AadharID,
          [AddressID] =@AddressID
        WHERE UserID = @UserID;
  ​
      ELSE
        --Insert row into table "TableName" in Schema '[dbo]'.
        INSERT INTO [dbo].[Users] ([ContactNumber],[FirstName],[LastName],[DOB],[Username],[Password],[AadharID],[AddressID])
          VALUES (@ContactNumber,@FirstName,@LastName,@DOB,@UserName,@Password,@AadharID,@AddressID)
    END

DROP PROCEDURE dbo.AddUpdateUser
EXECUTE [dbo].[AddUpdateUser] @ContactNumber = '7338873269',@FirstName = 'Eshwar',@LastName = 'Jayaprakash',@DOB = '1996-10-27' ,@UserName = 'eshwar123' ,@Password = '123141',@AadharID = '230492952984',@AddressID = 6;

----------------------------------------------------------------------------
-- Trigger for billing of user and owner when he ends trip
CREATE Trigger [dbo].[AfterEndTrip]
  ON Trips
  AFTER UPDATE
  AS
    BEGIN
      DECLARE @LatestEndedTripID INT;
      SELECT  TOP 1 @LatestEndedTripID = inserted.TripID FROM inserted
      EXECUTE [dbo].[AddBilling] @LatestEndedTripID;
    END
  
----------------------------------------------------------------------------
-- Trigger for Booking of user and owner, contraints for wallet amount and 

CREATE TRIGGER [dbo].[AfterBookingUpdates]
  ON Bookings
  AFTER INSERT,UPDATE
  AS
    BEGIN
      DECLARE @WalletAmount FLOAT
      DECLARE @BookingStatus Varchar(30)
      DECLARE @TransactionBy INT
      DECLARE @TransactionAmount FLOAT
	    DECLARE @TransactionType Varchar(20)
      DECLARE @BookingID INT

      Select @WalletAmount= [WalletAmount] FROM [Wallet] WHERE UserID = (SELECT inserted.UserID FROM inserted)

      IF EXISTS (SELECT inserted.BookingID FROM inserted) AND EXISTS (SELECT deleted.BookingID FROM deleted)
        BEGIN
          SELECT @BookingStatus=[BookingStatus], @TransactionBy=[UserID] FROM Bookings WHERE BookingID = (SELECT inserted.BookingID FROM inserted)
          IF @BookingStatus = 'Cancelled'
            EXECUTE dbo.AddTransactions @TransactionBy, @TransactionAmount = 10, @TransactionType = 'Debit';
        END
      ELSE
        BEGIN
          IF @WalletAmount < 500
            BEGIN
              ROLLBACK TRAN
              RAISERROR('Booking Failed ! Wallet Amount is less than 500, add money to your wallet',16,1)
            END
        END
    END

DROP Trigger [AfterBookingUpdates]

-- supporting DML
DROP Trigger [dbo].[AfterBooking]
SELECT * from Wallet
INSERT INTO [dbo].[Wallet] ([WalletAmount], [UserID]) VALUES ( 700, 4)
UPDATE [dbo].[Wallet] SET [WalletAmount] = 505 WHERE WalletID = 1

Select * FROM Bookings
SELECT * FROM Trips
SELECT * FROM BikeStations
INSERT INTO [Bookings] (Purpose, BookingStatus, UserID,RideDate, RideTime) VALUES ('office', 'Booked',13,'2020-08-07','06:30:00')
UPDATE [dbo].[Bookings] SET [BookingStatus] = 'Cancelled' WHERE BookingID = 20
DELETE FROM [dbo].[Bookings] WHERE BookingID = 4

-------------------------------------------------------------------------------
-- Trigger for creating transaction After Billing
CREATE Trigger [dbo].[AfterBillingUpdates]
  ON Billing
  AFTER INSERT
  AS
    BEGIN
      DECLARE @LatestBillingID INT;
      DECLARE @TransactionBy INT;
      DECLARE @TransactionAmount FLOAT;
      DECLARE @TransactionType Varchar(20);
      SELECT  TOP 1 @LatestBillingID = inserted.BillID FROM inserted
      SELECT @TransactionBy= [UserID], @TransactionAmount = [TotalAmount], @TransactionType = [BillingType] FROM Billing WHERE BillID = @LatestBillingID 
      EXECUTE dbo.AddTransactions @TransactionBy, @TransactionAmount, @TransactionType ;
    END

DROP TRIGGER [dbo].[AfterBillingUpdates]
-------------------------------------------------------------------------------
-- Trigger for Creating wallet when user registers first time
CREATE Trigger [dbo].[AfterUserInsert]
  ON [dbo].[Users]
  AFTER Insert,Delete
  AS
    BEGIN
		DECLARE @User INT;
		SELECT  TOP 1  @User = inserted.UserID FROM inserted
		IF(@User IS NOT NULL)
		INSERT INTO [dbo].[Wallet] ([WalletAmount],[UserID]) VALUES (0, @User) 
		ELSE
			BEGIN 
				SELECT  TOP 1  @User = deleted.UserID FROM deleted
				DELETE FROM [dbo].[Wallet] WHERE UserID = @User
			END
	END

--------------------------------------------------------------------------------
DELETE FROM [dbo].[BikeStations] WHERE BikeStationID=12

--------------------------------------------------------------------------------
-- VIEWS
-- Busiest Route
CREATE VIEW Busiest_Route
  AS
  SELECT s.StationID, s.Name [Station Name], COUNT(s.StationID) AS [Frequency]
  FROM Trips t
  INNER JOIN BikeStations bs
  ON bs.BikeStationID = t.StartBikeStationID
  INNER JOIN Stations s
  ON s.StationID = bs.StationID
  GROUP BY s.StationID, s.Name

SELECT * FROM Busiest_Route
-- TALLY Views
SELECT StationID, StartBikeStationID
FROM Trips t
INNER JOIN BikeStations bs
ON bs.BikeStationID = t.StartBikeStationID


-- Bike Available
Create View [Bike_Available]
  AS
  SELECT DISTINCT B.StationID [StationID], S.Name,
  STUFF((SELECT  DISTINCT ', '+RTRIM(CAST(BikeID as char))
    FROM BikeStations BS
    WHERE BS.StationID = B.StationID AND BikeStatus ='Available'
    FOR XML PATH('')) ,1, 1, '') AS 'Bike IDs'
  FROM BikeStations B
  INNER JOIN Stations S
  ON S.StationID = B.StationID

SELECT * FROM [Bike_Available]
ORDER BY StationID ASC

DROP VIEW [Bike_Available]
-- TALLY 
select StationID, BikeID 
from BikeStations 
where BikeStatus ='Available'

-- User Wallet View
create view User_Wallet 
  as
  select u.UserID, w.WalletID, u.FirstName, u.LastName, w.WalletAmount
  from users u
  join wallet w
  on u.UserID = w.UserID;

select * from user_wallet;

-- User booking Details
create view User_Booking_Details
  AS
  Select u.userid, u.username, b.bookingid
  , b.purpose, b.ridedate, t.Startbikestationid, t.endbikestationid
  from users u
  join bookings b
  on u.userid = b.userid
  join trips t
  on b.bookingid = t.bookingid;

select * from [User_Booking_Details];


---------------------------------------------------------------------------
-- Computed Column Functions
-- Age

CREATE FUNCTION CalculateAge(@UserID INT)
  RETURNS INT
  BEGIN
    DECLARE @age INT;
    SET @age = (SELECT DATEDIFF(hour,u.DOB,GETDATE())/8766 FROM Users u WHERE u.UserID = @UserID);
    
    RETURN @age;
  END

ALTER TABLE dbo.Users
ADD Age AS (dbo.CalculateAge(UserID));

-- Total Amount 
CREATE FUNCTION CalculateTotalAmount(@TripID INT, @RentalRatesID INT)
RETURNS FLOAT
AS
	BEGIN
	  DECLARE @Hours FLOAT, @Minutes FLOAT, @Rate FLOAT, @Time FLOAT;
      DECLARE @TripType Varchar(20);
      DECLARE @TotalAmount FLOAT, @TAmount FLOAT, @UserID INT;
      DECLARE @StartTime DATETIME, @EndTime DATETIME;
	  DECLARE @Percentage FLOAT;
	  DECLARE @BookingID INT

	  SELECT @StartTime=[StartDateTime], @EndTime=[EndDateTime] , @BookingID = b.BookingID, @TripType=[TripType] FROM Trips t INNER JOIN Bookings b ON t.BookingID = b.BookingID 
	  WHERE t.TripID = @TripID

	  SELECT @Percentage = (SELECT [Percentage] FROM Discount d INNER JOIN Bookings b ON d.DiscountID = b.DiscountID WHERE b.BookingID = @BookingID)

		SET @Minutes = DATEDIFF(Minute, @StartTime, @EndTime);
		SET @Hours = @Minutes/60
		IF (@Hours < 24)
			SET @Time = @Hours;
		ELSE
			SET @Time = @Hours/24;
	
		IF @Percentage IS NULL SET @Percentage = 0.0
		SELECT @Rate = (SELECT Rate FROM RentalRates WHERE RentalRatesID = @RentalRatesID)
		SET @TAmount = @Rate * @Time 
		SET @TotalAmount = @TAmount - (@Percentage*@TAmount)/100
		RETURN @TotalAmount
	END

DROP FUNCTION dbo.CalculateTotalAmount;

---------------------------------------------------------------------------
-- Table level constraints
-- check age > 14 for user
CREATE FUNCTION CheckAge (@UserID INT)
  RETURNS INT
  AS
  BEGIN
    DECLARE @Age INT;
    SET @Age = dbo.CalculateAge(@UserID)
    
      RETURN @Age
  END;

  ALTER TABLE Users
  ADD CONSTRAINT CheckAgeOfUser CHECK (dbo.CheckAge(UserID) > 14)

ALTER TABLE Users
DROP CONSTRAINT CheckAgeOfUser;

-- Wallet Balance before booking
CREATE FUNCTION WalletBalanceCheck (@UserID INT)
  RETURNS FLOAT
  AS 
  BEGIN
    DECLARE  @Balance FLOAT;
    (SELECT @Balance = WalletAmount FROM dbo.Wallet WHERE UserID = @UserID)
    Return @Balance
  END;

drop function WalletBalanceCheck
PRINT(dbo.WalletBalanceCheck(10))

ALTER TABLE dbo.Bookings
ADD CONSTRAINT WalletBalanceOfUser CHECK (dbo.WalletBalanceCheck(UserID) > 500)

ALTER TABLE dbo.Bookings
DROP CONSTRAINT WalletBalance;

-------------------------------------------------------------------------------
-- Other Supporting queries
  select * from Users
  select * from UserMemberships
  select * from Groups
  select * from UserGroups
  select * from Memberships
  Select * from [Address]

  select * from Bikes
  select * from Stations
  select * from BikeStations
  select * from Bikecategory

  select * from discount
  select * from Bookings
  select * from Trips
  select * from RentalRates

  select * from billing
  SELECT * FROM Transactions
  select * from wallet



------------------------------------------------------------------------------
-- DML
-- Inserting into Address table

  SELECT * FROM ADDRESS

  insert into ADDRESS( Area, Pincode, City, State)
  values( 'Marathahalli', 560014, 'Bangalore', 'Karnataka');

  insert into ADDRESS( Area, Pincode, City, State)
  values( 'Govindpura', 560017, 'Bangalore', 'Karnataka');

  insert into ADDRESS( Area, Pincode, City, State)
  values( 'Kalyannagar', 560019, 'Bangalore', 'Karnataka');

  insert into ADDRESS( Area, Pincode, City, State)
  values( 'Thanisandra', 560024, 'Bangalore', 'Karnataka');

  insert into ADDRESS( Area, Pincode, City, State)
  values( 'Head Quaters', 510010, 'Bangalore', 'Karnataka');

  insert into ADDRESS( Area, Pincode, City, State)
  values( 'Marathahalli', 560024, 'Bangalore', 'Karnataka');

  insert into ADDRESS( Area, Pincode, City, State)
  values( 'Govindpura', 560019, 'Bangalore', 'Karnataka');

  insert into ADDRESS( Area, Pincode, City, State)
  values( 'Kalyannagar', 560017, 'Bangalore', 'Karnataka');

  insert into ADDRESS( Area, Pincode, City, State)
  values( 'Thanisandra', 560014, 'Bangalore', 'Karnataka');

  insert into ADDRESS( Area, Pincode, City, State)
  values( 'Skywardstech', 560075, 'Bangalore', 'Karnataka');

  insert into ADDRESS( Area, Pincode, City, State)
  values( 'Skywardstech big city', 560075, 'Bangalore', 'Karnataka');


-- Insert into Users
 
  EXECUTE [dbo].[AddUpdateUser] @ContactNumber = '8888888888',@FirstName = 'Pedal Pvt Ltd',@LastName = 'Cylcing Unit',@DOB = '01-01-1997' ,@UserName = 'pedal18' ,@Password = '111pedal@137111',@AadharID = '784356275623',@AddressID = 1;
  EXECUTE [dbo].[AddUpdateUser] @ContactNumber = '9818696735',@FirstName = 'Adithya',@LastName = 'Vardhan',@DOB = '06-06-1997' ,@UserName = 'adithya369' ,@Password = '111111',@AadharID = '784356275623',@AddressID = 1;
  EXECUTE [dbo].[AddUpdateUser] @ContactNumber = '8527255850',@FirstName = 'ManojKumar',@LastName = 'Bochu',@DOB = '06-06-1997' ,@UserName = 'pikachu23' ,@Password = '16567674',@AadharID = '348543285743',@AddressID = 2;
  EXECUTE [dbo].[AddUpdateUser] @ContactNumber = '8985648729',@FirstName = 'Akhil Vinay',@LastName = 'Pendyala',@DOB = '02-09-1997' ,@UserName = 'pvva455' ,@Password = '1657674',@AadharID = '344579834739',@AddressID = 3;
  EXECUTE [dbo].[AddUpdateUser] @ContactNumber = '9292832129',@FirstName = 'bhogi',@LastName = 'Baadshah',@DOB = '02-09-1992' ,@UserName = 'BB10' ,@Password = '165767432',@AadharID = '344579837363',@AddressID = 4;
  EXECUTE [dbo].[AddUpdateUser] @ContactNumber = '7777777777',@FirstName = 'james',@LastName = 'bond',@DOB = '07-07-1997' ,@UserName = 'jb007' ,@Password = '1878666',@AadharID = '344364816828',@AddressID = 5;
  EXECUTE [dbo].[AddUpdateUser] @ContactNumber = '9837874943',@FirstName = 'Donald',@LastName = 'trump',@DOB = '01-10-1997' ,@UserName = 'dt007' ,@Password = '123456',@AadharID = '787829816828',@AddressID = 5;                                                                                                                                       
  EXECUTE [dbo].[AddUpdateUser] @ContactNumber = '9787877292',@FirstName = 'Barak',@LastName = 'obama',@DOB = '07-10-1992' ,@UserName = 'bo992' ,@Password = '18786',@AadharID = '443364816828',@AddressID = 6;
  EXECUTE [dbo].[AddUpdateUser] @ContactNumber = '9827389222',@FirstName = 'Super',@LastName = 'man',@DOB = '27-07-1991' ,@UserName = 'su981' ,@Password = 'superman11',@AadharID = '765397203720',@AddressID = 7;  
  EXECUTE [dbo].[AddUpdateUser] @ContactNumber = '9197384628',@FirstName = 'Spider',@LastName = 'man',@DOB = '15-02-1993' ,@UserName = 'spiderman2' ,@Password = '1878666',@AadharID = '637292083013',@AddressID = 8;  
  EXECUTE [dbo].[AddUpdateUser] @ContactNumber = '7777777777',@FirstName = 'Christopher',@LastName = 'Nolan',@DOB = '09-09-1990' ,@UserName = 'nolan00' ,@Password = '000000',@AadharID = '828614863443',@AddressID = 9;
  EXECUTE [dbo].[AddUpdateUser] @ContactNumber = '1231232133',@FirstName = 'Batman',@LastName = 'Colam',@DOB = '09-09-1990' ,@UserName = 'batman2' ,@Password = '000000',@AadharID = '828614863443',@AddressID = 10;

-- Insert into Groups
  INSERT INTO Groups VALUES ('Owner')
  INSERT INTO Groups VALUES ('Customer')
  INSERT INTO Groups VALUES ('Group 3')
  INSERT INTO Groups VALUES ('Group 4')
  INSERT INTO Groups VALUES ('Group 5')
  INSERT INTO Groups VALUES ('Group 6')
  INSERT INTO Groups VALUES ('Group 7')
  INSERT INTO Groups VALUES ('Group 8')
  INSERT INTO Groups VALUES ('Group 9')
  INSERT INTO Groups VALUES ('Group 10')
  INSERT INTO Groups VALUES ('Group 11')
  INSERT INTO Groups VALUES ('Group 12')

-- Insert into Memberships
  INSERT INTO Memberships  VALUES ('Regular')
  INSERT INTO Memberships  VALUES ('Gold')
  INSERT INTO Memberships  VALUES ('Premium')
  INSERT INTO Memberships  VALUES ('Star')
  INSERT INTO Memberships  VALUES ('Honoury')
  INSERT INTO Memberships  VALUES ('Loyal')
  INSERT INTO Memberships  VALUES ('Super')
  INSERT INTO Memberships  VALUES ('Paid')
  INSERT INTO Memberships  VALUES ('Subscribed')
  INSERT INTO Memberships  VALUES ('Active')

-- Insert into UserGroups
  INSERT INTO UserGroups  VALUES (1, 1)
  INSERT INTO UserGroups  VALUES (2, 2)
  INSERT INTO UserGroups  VALUES (3, 2)
  INSERT INTO UserGroups  VALUES (4, 2)
  INSERT INTO UserGroups  VALUES (5, 2)
  INSERT INTO UserGroups  VALUES (6, 2)
  INSERT INTO UserGroups  VALUES (7, 2)
  INSERT INTO UserGroups  VALUES (8, 2)
  INSERT INTO UserGroups  VALUES (9, 2)
  INSERT INTO UserGroups  VALUES (10, 2)

-- Insert Into UserMemberships
  INSERT INTO UserMemberships (UserID, MembershipID, StartDate, EndDate) VALUES (2,1,'2020-01-01', '2020-12-12')
  INSERT INTO UserMemberships (UserID, MembershipID, StartDate, EndDate) VALUES (3,1,'2020-04-01', '2020-06-30')
  INSERT INTO UserMemberships (UserID, MembershipID, StartDate, EndDate) VALUES (4,1,'2020-01-01', '2020-03-31')
  INSERT INTO UserMemberships (UserID, MembershipID, StartDate, EndDate) VALUES (5,2,'2020-04-01', '2020-09-30')
  INSERT INTO UserMemberships (UserID, MembershipID, StartDate, EndDate) VALUES (6,2,'2020-07-01', '2020-12-31')
  INSERT INTO UserMemberships (UserID, MembershipID, StartDate, EndDate) VALUES (7,2,'2020-01-01', '2020-06-30')
  INSERT INTO UserMemberships (UserID, MembershipID, StartDate, EndDate) VALUES (8,3,'2020-01-01', '2020-03-31')
  INSERT INTO UserMemberships (UserID, MembershipID, StartDate, EndDate) VALUES (9,3,'2020-01-01', '2020-09-30')
  INSERT INTO UserMemberships (UserID, MembershipID, StartDate, EndDate) VALUES (10,3,'2020-04-01', '2020-12-31')
  INSERT INTO UserMemberships (UserID, MembershipID, StartDate, EndDate) VALUES (1,3,'2020-04-01', '2020-09-30')

-- Inserting into Stations table 

  insert into Stations( Name, AddressID)
  values  ('pedal 1', 1);

  insert into Stations( Name, AddressID)
  values  ('pedal 2', 2);

  insert into Stations( Name, AddressID)
  values  ('pedal 3', 3);

  insert into Stations( Name, AddressID)
  values  ('pedal 4', 4);

  insert into Stations( Name, AddressID)
  values  ('pedal 5', 5);

  insert into Stations( Name, AddressID)
  values  ('pedal 6', 6);

  insert into Stations( Name, AddressID)
  values  ('pedal 7', 7);

  insert into Stations( Name, AddressID)
  values  ('pedal 8', 8);

  insert into Stations( Name, AddressID)
  values  ('pedal 9', 9);

  insert into Stations( Name, AddressID)
  values  ('pedal 10', 10);


-- Insert into Bike categories 
  EXECUTE dbo.AddUpdateBikeCategory @Name='gear'
  EXECUTE dbo.AddUpdateBikeCategory @Name='Non Gear'
  EXECUTE dbo.AddUpdateBikeCategory @Name='Super Gear'
  EXECUTE dbo.AddUpdateBikeCategory @Name='Mountain Bike'
  EXECUTE dbo.AddUpdateBikeCategory @Name='Trick Bike'
  EXECUTE dbo.AddUpdateBikeCategory @Name='Dirt Bike'
  EXECUTE dbo.AddUpdateBikeCategory @Name='Trick Bike'
  EXECUTE dbo.AddUpdateBikeCategory @Name='Commuting Bike'
  EXECUTE dbo.AddUpdateBikeCategory @Name='Cyclo'
  EXECUTE dbo.AddUpdateBikeCategory @Name='CrossCyclo'
  EXECUTE dbo.AddUpdateBikeCategory @Name='Trial Bike'
  EXECUTE dbo.AddUpdateBikeCategory @Name='BMX Bike'

-- Inserting into BIKES

  insert into bikes(Model, SerialNumber, OwnerID, BikeCategoryID)
  values('GTX100', 'MU28434', 1, 1)

  insert into bikes(Model, SerialNumber, OwnerID, BikeCategoryID)
  values('BOSS350', 'BK3602', 5, 1)

  insert into bikes(Model, SerialNumber, OwnerID, BikeCategoryID)
  values('GTX100', 'MU28465', 4, 1)

  insert into bikes(Model, SerialNumber, OwnerID, BikeCategoryID)
  values('GTX100', 'MU28280', 4, 1)

  insert into bikes(Model, SerialNumber, OwnerID, BikeCategoryID)
  values('GTX100', 'MU28450', 5, 1)

  insert into bikes(Model, SerialNumber, OwnerID, BikeCategoryID)
  values('BOSS350', 'BK2806', 6, 3)

  insert into bikes(Model, SerialNumber, OwnerID, BikeCategoryID)
  values('BOSS350', 'BK28062', 1, 1)

  insert into bikes(Model, SerialNumber, OwnerID, BikeCategoryID)
  values('BOSS350', 'BK280261', 1, 2)

  insert into bikes(Model, SerialNumber, OwnerID, BikeCategoryID)
  values('GTX100', 'MU28001', 1, 2)

  insert into bikes(Model, SerialNumber, OwnerID, BikeCategoryID)
  values('GTX100', 'MU28754', 1, 1)

  insert into bikes(Model, SerialNumber, OwnerID, BikeCategoryID)
  values('BOSS350', 'BK28061', 1, 1)

-- Inserting into Bike Station

  INSERT INTO BikeStations(StationID, BikeID, BikeStatus, AvailableTime)
  values(1, 1, 'Available', CURRENT_TIMESTAMP)

  INSERT INTO BikeStations(StationID, BikeID, BikeStatus, AvailableTime)
  values(1, 2, 'Available', CURRENT_TIMESTAMP)

  INSERT INTO BikeStations(StationID, BikeID, BikeStatus, AvailableTime)
  values(1, 3, 'Available', CURRENT_TIMESTAMP)

  INSERT INTO BikeStations(StationID, BikeID, BikeStatus, AvailableTime)
  values(1, 4, 'Available', CURRENT_TIMESTAMP)

  INSERT INTO BikeStations(StationID, BikeID, BikeStatus, AvailableTime)
  values(1, 6, 'Available', CURRENT_TIMESTAMP)

  INSERT INTO BikeStations(StationID, BikeID, BikeStatus, AvailableTime)
  values(1, 5, 'Available', CURRENT_TIMESTAMP)

  INSERT INTO BikeStations(StationID, BikeID, BikeStatus, AvailableTime)
  values(1, 14, 'Available', CURRENT_TIMESTAMP)

  INSERT INTO BikeStations(StationID, BikeID, BikeStatus, AvailableTime)
  values(1, 13, 'Available', CURRENT_TIMESTAMP)

  INSERT INTO BikeStations(StationID, BikeID, BikeStatus, AvailableTime)
  values(1, 9, 'Available', CURRENT_TIMESTAMP)

  INSERT INTO BikeStations(StationID, BikeID, BikeStatus, AvailableTime)
  values(1, 10, 'Available', CURRENT_TIMESTAMP)




-- Insert Into wallet , update wallet amount as it is already created using trigger
  UPDATE [dbo].[Wallet]
  SET [WalletAmount] = 505
  WHERE WalletID = 1

  UPDATE [dbo].[Wallet]
  SET [WalletAmount] = 510
  WHERE WalletID = 2

  UPDATE [dbo].[Wallet]
  SET [WalletAmount] = 530
  WHERE WalletID = 3

  UPDATE [dbo].[Wallet]
  SET [WalletAmount] = 610
  WHERE WalletID = 4

  UPDATE [dbo].[Wallet]
  SET [WalletAmount] = 800
  WHERE WalletID = 5

  UPDATE [dbo].[Wallet]
  SET [WalletAmount] = 906
  WHERE WalletID = 6

  UPDATE [dbo].[Wallet]
  SET [WalletAmount] = 598
  WHERE WalletID = 7

  UPDATE [dbo].[Wallet]
  SET [WalletAmount] = 932
  WHERE WalletID = 8

  UPDATE [dbo].[Wallet]
  SET [WalletAmount] = 1699
  WHERE WalletID = 9

  UPDATE [dbo].[Wallet]
  SET [WalletAmount] = 1532
  WHERE WalletID = 10

-- Inserting into Discount

  INSERT INTO Discount( CouponName, [Percentage], StartDate, EndDate, MembershipID)
  VALUES ('PEDAL10','10','05-05-2020','08-05-2020','1');

  INSERT INTO Discount( CouponName, [Percentage], StartDate, EndDate, MembershipID)
  VALUES ('PEDAL25','25','07-10-2020','09-10-2020','1');

  INSERT INTO Discount( CouponName, [Percentage], StartDate, EndDate, MembershipID)
  VALUES ('PEDAL40','40','03-01-2020','04-15-2020','1');

  INSERT INTO Discount( CouponName, [Percentage], StartDate, EndDate, MembershipID)
  VALUES ('PEDAL50','50','01-01-2020','02-01-2020','1');

  INSERT INTO Discount( CouponName, [Percentage], StartDate, EndDate, MembershipID)
  VALUES ('PEDAL20','20','12-05-2019','12-31-2019','1');

  INSERT INTO Discount( CouponName, [Percentage], StartDate, EndDate, MembershipID)
  VALUES ('FIT35','35','08-15-2020','09-20-2020','3');

  INSERT INTO Discount( CouponName, [Percentage], StartDate, EndDate, MembershipID)
  VALUES ('FIT50','50','04-01-2020','05-20-2020','3');

  INSERT INTO Discount( CouponName, [Percentage], StartDate, EndDate, MembershipID)
  VALUES ('FIRSTTRIP30','30','01-01-2019','12-31-2020','1');

  INSERT INTO Discount( CouponName, [Percentage], StartDate, EndDate, MembershipID)
  VALUES ('ADVENTURE20','20','06-01-2019','06-20-2019','2');

  INSERT INTO Discount( CouponName, [Percentage], StartDate, EndDate, MembershipID)
  VALUES ('ADVENTURE30','30','10-01-2020','10-31-2020','2');

-- Insert into Bookings 

  INSERT INTO [Bookings] (Purpose, BookingStatus, UserID,RideDate, RideTime) VALUES ('home', 'Booked',2,'2020-08-07','06:30:00')
  INSERT INTO [Bookings] (Purpose, BookingStatus, UserID,RideDate, RideTime) VALUES ('office', 'Booked',3,'2020-05-01','06:00:00')
  INSERT INTO [Bookings] (Purpose, BookingStatus, UserID,RideDate, RideTime) VALUES ('office', 'Booked',4,'2020-08-10','01:30:00')
  INSERT INTO [Bookings] (Purpose, BookingStatus, UserID,RideDate, RideTime) VALUES ('office', 'Booked',5,'2020-02-07','05:30:00')
  INSERT INTO [Bookings] (Purpose, BookingStatus, UserID,RideDate, RideTime) VALUES ('home', 'Booked',6,'2020-01-07','03:30:00')
  INSERT INTO [Bookings] (Purpose, BookingStatus, UserID,RideDate, RideTime) VALUES ('office', 'Booked',7,'2019-12-25','06:40:00')
  INSERT INTO [Bookings] (Purpose, BookingStatus, UserID,RideDate, RideTime) VALUES ('office', 'Booked',8,'2020-08-19','01:30:00')
  INSERT INTO [Bookings] (Purpose, BookingStatus, UserID,RideDate, RideTime) VALUES ('office', 'Booked',9,'2020-08-07','02:30:00')
  INSERT INTO [Bookings] (Purpose, BookingStatus, UserID,RideDate, RideTime) VALUES ('office', 'Booked',10,'2019-10-04','05:10:00')
  INSERT INTO [Bookings] (Purpose, BookingStatus, UserID,RideDate, RideTime) VALUES ('office', 'Booked',2,'2020-03-15','09:00:00')

-- Insert into Trip
-- start trip
  EXECUTE dbo.StartTrip @BookingID=1, @StationID=1, @BikeID= 1, @TripType='By User'
  EXECUTE dbo.StartTrip @BookingID=2, @StationID=1, @BikeID= 2, @TripType='By User'
  EXECUTE dbo.StartTrip @BookingID=3, @StationID=1, @BikeID= 3, @TripType='By User'
  EXECUTE dbo.StartTrip @BookingID=4, @StationID=1, @BikeID= 4, @TripType='By User'
  EXECUTE dbo.StartTrip @BookingID=5, @StationID=1, @BikeID= 5, @TripType='By User'
  EXECUTE dbo.StartTrip @BookingID=6, @StationID=1, @BikeID= 6, @TripType='By User'
  EXECUTE dbo.StartTrip @BookingID=7, @StationID=1, @BikeID= 13, @TripType='By User'
  EXECUTE dbo.StartTrip @BookingID=8, @StationID=1, @BikeID= 14, @TripType='By User'
  EXECUTE dbo.StartTrip @BookingID=9, @StationID=1, @BikeID= 9, @TripType='By User'
  EXECUTE dbo.StartTrip @BookingID=13, @StationID=1, @BikeID= 10, @TripType='By User'

-- Insert into Rental Rates
  insert into RentalRates values('User_Hourly_Rate', 7)
  insert into RentalRates values('User_Daily_Rate', 5)
  insert into RentalRates values('Owner_Hourly_Rate', 4)
  insert into RentalRates values('Owner_Daily_Rate', 3.5)

-- end trip
  EXECUTE dbo.EndTrip @TripID=1 , @StationID=3;
  EXECUTE dbo.EndTrip @TripID=2 , @StationID=2;
  EXECUTE dbo.EndTrip @TripID=3 , @StationID=1;
  EXECUTE dbo.EndTrip @TripID=4 , @StationID=2;
  EXECUTE dbo.EndTrip @TripID=5 , @StationID=4;
  EXECUTE dbo.EndTrip @TripID=6 , @StationID=5;
  EXECUTE dbo.EndTrip @TripID=7 , @StationID=6;
  EXECUTE dbo.EndTrip @TripID=8 , @StationID=8;
  EXECUTE dbo.EndTrip @TripID=9 , @StationID=7;
  EXECUTE dbo.EndTrip @TripID=10 , @StationID=9;

-- Billing auto generated
-- Transaction Auto generated
-- Wallet auto updated

------------------------------------------------------------------------
-- STEPS FOR EXECUTING PEDAL SYSTEM

  -- ADD USER : 
  EXECUTE [dbo].[AddUpdateUser] @ContactNumber = '8888888888',@FirstName = 'Pedal Pvt Ltd',@LastName = 'Cylcing Unit',@DOB = '01-01-1997' ,@UserName = 'pedal18' ,@Password = '111pedal@137111',@AadharID = '784356275623',@AddressID = 1;
      -- Trigger for creating Wallet with 0 balance 
      -- Computed column to calculate users age

  -- ADD BOOKING :
  INSERT INTO [Bookings] (Purpose, BookingStatus, UserID,RideDate, RideTime) VALUES ('office', 'Booked',13,'2020-08-07','06:30:00')
    -- Trigger for checking user has wallet amount > 500

  -- UPDATE MONEY TO WALLET
  UPDATE [dbo].[Wallet] SET [WalletAmount] = 505 WHERE WalletID = 16

  -- START TRIP
  EXECUTE dbo.StartTrip @BookingID=25, @StationID=3, @BikeID= 1, @TripType='By User'

  -- END TRIP
  EXECUTE dbo.EndTrip @TripID=11 , @StationID=4;
    -- Trigger for automate bill generate
    -- Computed column function to calculate TotalAmount
    -- Trigger for automatic transaction to debit/credit money from users wallet
    
  -- CANCEL BOOKING
  UPDATE [dbo].[Bookings] SET [BookingStatus] = 'Cancelled' WHERE BookingID = 20
    -- Trigger for cancel booking and if he cancels booking deduct money from his wallet