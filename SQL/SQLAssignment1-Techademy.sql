-------------------------------------ASSIGNMENT 1 SQL --------------------------------------

-- Sample Dataset 
CREATE TABLE Customer (
    CustomerID INT PRIMARY KEY,
    FirstName VARCHAR(50),
    LastName VARCHAR(50),
    Email VARCHAR(100),
    RegistrationDate DATE
);

INSERT INTO Customer (CustomerID, FirstName, LastName, Email, RegistrationDate)
VALUES
    (1, 'John', 'Doe', 'john.doe@example.com', '2023-01-15'),
    (2, 'Jane', 'Smith', 'jane.smith@example.com', '2022-11-30'),
    (3, 'Michael', 'Johnson', 'michael.johnson@example.com', '2022-12-05'),
    (4, 'Emily', 'Brown', 'emily.brown@example.com', '2023-02-20'),
    (5, 'David', 'Williams', 'david.williams@example.com', '2023-01-10');


--1 . Query to display all FIRST_NAME in upper case:
SELECT UPPER(FirstName) AS FIRST_NAME
FROM Customer;


--2 . Extract first 3 characters of last names:
SELECT LastName, SUBSTRING(LastName, 1, 3) AS FirstThreeChars
FROM Customer;


--3 Date Functions: YEAR, MONTH, DAY
-- 3.1 Extract year from registration dates
select RegistrationDate, year(RegistrationDate) as YearOfRegistration from Customer

-- 3.2 Extract month and day from registration dates
select RegistrationDate, month(RegistrationDate) as MonthOfRegistration from Customer


--4. Aggregate Functions: COUNT and COUNT DISTINCT
-- 4.1 Count total number of customers:
SELECT COUNT(*) AS TotalCustomers
FROM Customer;

-- 4.2 Count distinct email domains:
SELECT COUNT(DISTINCT SUBSTRING(Email, CHARINDEX('@', Email) + 1, LEN(Email))) AS DistinctEmailDomains
FROM Customer;




