CREATE TABLE OWNER (
OWNER_ID INT(8) NOT NULL PRIMARY KEY,
OWNER_TYPE VARCHAR(30) NOT NULL
); 

CREATE TABLE MODEL (
MODELNAME VARCHAR(30) NOT NULL, 
MODELYEAR  INT(4) NOT NULL, 
PRIMARY KEY(MODELNAME, MODELYEAR)
);

CREATE TABLE BANK (
BANKNAME VARCHAR(30) NOT NULL PRIMARY KEY,
OID INT(8) NOT NULL,
B_ADDRESS VARCHAR(300),
CONSTRAINT FKEY_OID
FOREIGN KEY (OID) REFERENCES OWNER(OWNER_ID));

CREATE TABLE RENTAL_COMPANY (
CNAME VARCHAR(30) NOT NULL PRIMARY KEY,
OID INT(8) NOT NULL,
RC_ADDRESS VARCHAR(300),
CONSTRAINT FKEY_RC
FOREIGN KEY (OID) REFERENCES OWNER(OWNER_ID));

CREATE TABLE CUSTOMER (
CUSTOMER_ID INT(8) NOT NULL PRIMARY KEY,
CUST_TYPE VARCHAR(30) NOT NULL);

CREATE TABLE INDIVIDUAL (
SSN CHAR(255) NOT NULL PRIMARY KEY, 
CUSTOMER_ID INT(8) NOT NULL, 
NAME VARCHAR(30) NOT NULL,
DOB DATE,
I_PH_NO long,
OID INT(8),
CONSTRAINT FKEY_CID
FOREIGN KEY (CUSTOMER_ID) REFERENCES CUSTOMER(CUSTOMER_ID),
CONSTRAINT FKEY_IOID
FOREIGN KEY (OID) REFERENCES OWNER(OWNER_ID)
);

CREATE TABLE COMPANY (
CNAME VARCHAR(30) NOT NULL PRIMARY KEY,
CUSTOMER_ID INT(8) NOT NULL, 
C_ADDRESS VARCHAR(300), 
CONSTRAINT FKEY_CCID
FOREIGN KEY (CUSTOMER_ID) REFERENCES CUSTOMER(CUSTOMER_ID)
);

CREATE TABLE CARS (
VEHICLE_ID INT(8) NOT NULL PRIMARY KEY,
COLOR VARCHAR(15),  
VOWNER_ID INT(8) NOT NULL, 
PURCHASE_DATE DATE NOT NULL,
LEASE_START_DATE DATE,
LEASE_TERM INT(4),
END_DATE DATE, 
VMODEL_NAME VARCHAR(30) NOT NULL,
VMODEL_YEAR INT(4) NOT NULL, 
VTYPE VARCHAR(30) NOT NULL, 
WRATE INT(10) NOT NULL, 
DRATE INT(10) NOT NULL,
CONSTRAINT FKEY_COID
FOREIGN KEY (VOWNER_ID) REFERENCES OWNER(OWNER_ID),
CONSTRAINT FKEY_MNAME
FOREIGN KEY (VMODEL_NAME, VMODEL_YEAR) REFERENCES MODEL(MODELNAME,MODELYEAR),
CONSTRAINT CAR_YEAR CHECK(VMODEL_YEAR>PURCHASE_DATE),
CONSTRAINT START_DAY CHECK(LEASE_START_DATE>PURCHASE_DATE)
);

CREATE TABLE RENTALS (
RENTAL_ID INT(10) NOT NULL PRIMARY KEY,
CUSTOMER_ID INT(8) NOT NULL,
VEHICLE_ID INT(8) NOT NULL,
RSTART_DATE DATE NOT NULL,
RENTAL_TYPE VARCHAR(30) NOT NULL, 
REND_DATE DATE , 
NO_OF_DAYS INT(2), 
NO_OF_WEEKS INT(2), 
AMT_DUE INT(10),
Act_Ret_Date date,
flag boolean,
CONSTRAINT FKEY_C
FOREIGN KEY (CUSTOMER_ID) REFERENCES CUSTOMER(CUSTOMER_ID),
CONSTRAINT FKEY_v
FOREIGN KEY (VEHICLE_ID) REFERENCES CARS(VEHICLE_ID),
CONSTRAINT CHHH
CHECK ((RENTAL_TYPE = "DAILY"
AND
NO_OF_DAYS IS NOT NULL) 
OR
(RENTAL_TYPE = "WEEKLY"
AND
NO_OF_WEEKS IS NOT NULL))
); 

DELIMITER $$
CREATE TRIGGER END_CALCULATION
before
INSERT ON RENTALS
for each row
BEGIN
SET NEW.FLAG = 0;
IF(NEW.RENTAL_TYPE='DAILY')
THEN
SET NEW.REND_DATE =  DATE_ADD(new.RSTART_DATE,INTERVAL new.NO_OF_DAYS DAY);
SET NEW.Act_Ret_Date =  DATE_ADD(new.RSTART_DATE,INTERVAL new.NO_OF_DAYS DAY);
ELSE
SET NEW.REND_DATE =  DATE_ADD(new.RSTART_DATE,INTERVAL new.NO_OF_WEEKS WEEK);
SET NEW.Act_Ret_Date =  DATE_ADD(new.RSTART_DATE,INTERVAL new.NO_OF_WEEKS WEEK);
END IF;
END $$
DELIMITER ; 

DELIMITER $$
CREATE TRIGGER DUEAMT 
BEFORE INSERT
ON RENTALS 
FOR EACH ROW 
BEGIN
SET NEW.AMT_DUE = (NEW.NO_OF_DAYS * (SELECT DRATE FROM CARS WHERE VEHICLE_ID = NEW.VEHICLE_ID)) + 
(NEW.NO_OF_WEEKS * (SELECT WRATE FROM CARS WHERE VEHICLE_ID = NEW.VEHICLE_ID)); 
END$$
DELIMITER ;

CREATE DEFINER=`root`@`localhost` PROCEDURE `avCars2`()
BEGIN
SELECT I.NAME AS OwnerName, SUM(R.AMT_DUE)
FROM individual AS I, RENTALS AS R, CARS AS C
WHERE I.OID=C.VOWNER_ID
AND C.VEHICLE_ID=R.VEHICLE_ID
group by OwnerName
UNION
SELECT B.BANKNAME AS OwnerName,SUM(R.AMT_DUE)
FROM BANK AS B,RENTALS AS R,CARS AS C
WHERE B.OID=C.VOWNER_ID
AND  C.VEHICLE_ID=R.VEHICLE_ID
GROUP BY OwnerName
union
select RA.CNAME AS OwnerName,SUM(R.AMT_DUE)
FROM rental_company AS RA,rentals AS R,CARS AS C
WHERE RA.OID=C.VOWNER_ID
AND C.VEHICLE_ID=R.VEHICLE_ID
group by OwnerName;
END

CREATE DEFINER=`root`@`localhost` PROCEDURE `avCars5`(IN SD Date, IN ED date)
BEGIN
select SUM(AMT_DUE)
from rentals
where (REND_Date between SD and ED
and REND_DATE>=Act_Ret_Date 
and flag=1);
END

CREATE DEFINER=`root`@`localhost` PROCEDURE `avCars`(IN SD Date, IN ED date)
BEGIN

select VEHICLE_ID, COLOR, VMODEL_NAME, VMODEL_YEAR from cars 
WHERE 
VEHICLE_ID NOT IN(SELECT VEHICLE_ID FROM RENTALS)
UNION
SELECT VEHICLE_ID, (SELECT COLOR FROM CARS WHERE RENTALS.VEHICLE_ID = CARS.VEHICLE_ID) as Color, 
(SELECT VMODEL_NAME FROM CARS WHERE RENTALS.VEHICLE_ID = CARS.VEHICLE_ID) as Model_Name, 
(SELECT VMODEL_YEAR FROM CARS WHERE RENTALS.VEHICLE_ID = CARS.VEHICLE_ID) as Model_year 
FROM RENTALS
WHERE (SD<= RSTART_DATE AND ED <= REND_DATE)
OR
(SD>= RSTART_DATE AND ED >= REND_DATE);
END

CREATE DEFINER=`root`@`localhost` PROCEDURE `exist`(IN v int, out flag boolean)
BEGIN

	if exists(select rental_id from rentals where rental_id = v)
    then
	set flag = 1 ;
	else 
	set flag = 0 ;
	END IF; 
END

CREATE DEFINER=`root`@`localhost` PROCEDURE `retCar`(in id int, in d date, out amt int)
BEGIN

declare a int default 0; 
declare s int default 0;
declare b int default 0;

update rentals 
set Act_Ret_Date = d
where rental_id = id;

select AMT_DUE into s from rentals where rental_id = id;
select vehicle_id into a from rentals where rental_id = id; 

select DRATE into b from cars where vehicle_id = a;

if ((d > (select REND_DATE from rentals where rental_id = id)) AND ((select flag from rentals where rental_id = id) = 0))
then
update rentals 
set AMT_DUE = s + b * (select datediff(Act_Ret_Date, REND_DATE) where rental_id = id) where rental_id = id;
end if ;

select AMT_DUE into amt from rentals where rental_id = id;

update rentals 
set flag = 1
where rental_id = id;


END
