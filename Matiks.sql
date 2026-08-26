
/*

TASK OBJECTIVE

	Analyze user-level behavioral and revenue data, and help us understand what's working, what’s not, and where the 
	opportunities lie.
*/

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'MatiksDB')
BEGIN
    CREATE DATABASE MatiksDB;
END

USE MatiksDB;

/*
load the file into a staging table before we put it into our user table, using a Varchar(100) datatype for all columns in the staging
table. Use the import flat file to create the staging table. Table_name: staging_users

*/

-- creating the real table

CREATE TABLE Matiks (
    User_ID                     UNIQUEIDENTIFIER PRIMARY KEY,
    Username                    VARCHAR(100),
    Email                       VARCHAR(150),
    Signup_Date                 DATE,
    Country                     VARCHAR(100),
    Age                         TINYINT,
    Gender                      VARCHAR(20),
    Device_Type                 VARCHAR(20),
    Game_Title                  VARCHAR(50),
    Total_Play_Sessions         INT,
    Avg_Session_Duration_Min    DECIMAL(6,2),
    Total_Hours_Played          DECIMAL(8,2),
    In_Game_Purchases_Count     INT,
    Total_Revenue_USD           DECIMAL(10,2),
    Last_Login                  DATE,
    Subscription_Tier           VARCHAR(20),
    Referral_Source             VARCHAR(30),
    Preferred_Game_Mode         VARCHAR(20),
    Rank_Tier                   VARCHAR(20),
    Achievement_Score           INT
);



INSERT INTO dbo.Matiks (
    User_ID,
    Username,
    Email,
    Signup_Date,
    Country,
    Age,
    Gender,
    Device_Type,
    Game_Title,
    Total_Play_Sessions,
    Avg_Session_Duration_Min,
    Total_Hours_Played,
    In_Game_Purchases_Count,
    Total_Revenue_USD,
    Last_Login,
    Subscription_Tier,
    Referral_Source,
    Preferred_Game_Mode,
    Rank_Tier,
    Achievement_Score
)
SELECT
    TRY_CAST(User_ID AS UNIQUEIDENTIFIER),
    Username,
    Email,
    TRY_CONVERT(DATE, Signup_Date, 106),
    Country,
    TRY_CAST(Age AS TINYINT),
    Gender,
    Device_Type,
    Game_Title,
    TRY_CAST(Total_Play_Sessions AS INT),
    TRY_CAST(Avg_Session_Duration_Min AS DECIMAL(6,2)),
    TRY_CAST(Total_Hours_Played AS DECIMAL(8,2)),
    TRY_CAST(In_Game_Purchases_Count AS INT),
    TRY_CAST(Total_Revenue_USD AS DECIMAL(10,2)),
    TRY_CONVERT(DATE, Last_Login, 106),
    Subscription_Tier,
    Referral_Source,
    Preferred_Game_Mode,
    Rank_Tier,
    TRY_CAST(Achievement_Score AS INT)
FROM dbo.Staging_Users;



-- checking if no date was parsed

SELECT COUNT(*) AS unparsed_dates
FROM Matiks
WHERE Signup_Date IS NULL OR Last_Login IS NULL;

-- checking the range of last login

/*
    The signup date has 731 unique values spanning 2 years and the last login has 30 unique values spanning 1 month. every user is a
    is a snapshot field and not an activitiy login.
*/

SELECT MIN(Signup_Date) AS min_signup_date, MAX(Signup_Date) AS max_signup_date, MIN(Last_login) AS min_last_login,
MAX(Last_login) AS max_last_login FROM Matiks;

SELECT Username, Signup_Date, Last_Login
FROM Matiks;

/*
creating a table for the last login date which is th most recent last login date. we will achor all our recency calculations 
to the last login.
*/

CREATE TABLE Ref_Date (Snapshot_Date DATE);
INSERT INTO dbo.Ref_Date SELECT MAX(Last_Login) FROM Matiks;

SELECT * FROM Ref_Date;

/*

COHORT LOGIC (by signup month): How do newer vs older cohort behave.
*/


CREATE VIEW vw_UserCohorts AS
SELECT
    u.User_ID,
    DATEFROMPARTS(YEAR(u.Signup_Date), MONTH(u.Signup_Date), 1) AS Signup_Cohort_Month,
    DATEDIFF(DAY, u.Signup_Date, r.Snapshot_Date)                AS Tenure_Days,
    DATEDIFF(MONTH, u.Signup_Date, r.Snapshot_Date)              AS Tenure_Months
FROM Matiks AS u
CROSS JOIN Ref_Date AS r;

SELECT * FROM vw_UserCohorts;

-- cohort revenue summary

SELECT
    Signup_Cohort_Month,
    COUNT(*) AS Users_In_Cohort,
    ROUND(SUM(Total_Revenue_USD), 2) AS Cohort_Lifetime_Revenue,
    CAST(AVG(Total_Revenue_USD) AS DECIMAL(10,2)) AS Avg_Revenue_Per_User,
    CAST(
        SUM(Total_Revenue_USD) / NULLIF(SUM(Tenure_Days), 0) * 30
        AS DECIMAL(10,2)
    ) AS Avg_Revenue_Per_User_Per_30Days
FROM vw_UserCohorts as C
JOIN Matiks m ON m.User_ID = c.User_ID
GROUP BY Signup_Cohort_Month
ORDER BY Signup_Cohort_Month;

/*
RECENCY/CHURN PROXY (based on last login gap)
*/

CREATE VIEW vw_UserRecency AS
SELECT
    u.USER_ID,
    DATEDIFF(DAY, u.Last_Login, r.Snapshot_Date) AS Days_Since_Last_Login,
    CASE
        WHEN DATEDIFF(DAY, u.Last_Login, r.Snapshot_Date) <= 7  THEN 'Active (0-7d)'
        WHEN DATEDIFF(DAY, u.Last_Login, r.Snapshot_Date) <= 14 THEN 'Declining Activity (8-14d)'
        WHEN DATEDIFF(DAY, u.Last_Login, r.Snapshot_Date) <= 21 THEN 'Disengaging (15-21d)'
        ELSE 'Severely Disengaged (22-30d)'
    END AS Recency_Segment
FROM Matiks AS u
CROSS JOIN Ref_Date AS r;


SELECT * FROM vw_UserRecency;

-- Recency segment summary: size, engagement, revenue by segment



SELECT
    rc.Recency_Segment,
    COUNT(*)    AS Users,
    CAST(AVG(m.Total_Play_Sessions) AS DECIMAL(10,2))  AS Avg_Sessions,
    CAST(AVG(m.Total_Hours_Played) AS DECIMAL(10,2))   AS Avg_Hours_Played,
    CAST(AVG(m.Total_Revenue_USD) AS DECIMAL(10,2))    AS Avg_Revenue,
    SUM(m.Total_Revenue_USD)    AS Total_Revenue
FROM vw_UserRecency as rc
JOIN Matiks m ON m.User_ID = rc.User_ID
GROUP BY rc.Recency_Segment
ORDER BY MIN(rc.Days_Since_Last_Login); -- find it lowest inactive days and use it to arrange the groups from lowest to highest

/*

    HIGH-VALUE / HIGH-RETENTION USER SEGMENT
*/

SELECT
    m.User_ID,
    m.Username,
    c.Signup_Cohort_Month,
    c.Tenure_Days,
    rc.Days_Since_Last_Login,
    rc.Recency_Segment,
    m.Total_Play_Sessions,
    m.Total_Hours_Played,
    m.In_Game_Purchases_Count,
    m.Total_Revenue_USD,
    m.Rank_Tier,
    NTILE(4) OVER (ORDER BY m.Total_Revenue_USD DESC) AS Revenue_Quartile -- 1 = top spenders
FROM Matiks m
JOIN vw_UserCohorts c  ON c.User_ID = m.User_ID
JOIN vw_UserRecency rc ON rc.User_ID = m.User_ID
ORDER BY m.Total_Revenue_USD DESC;

-- User Segmentation (frequency vs revenue)

SELECT
    User_ID,
    Total_Play_Sessions,
    Total_Revenue_USD,
    NTILE(3) OVER (ORDER BY Total_Play_Sessions) AS Frequency_Tercile, -- 1=low,3=high
    NTILE(3) OVER (ORDER BY Total_Revenue_USD)   AS Revenue_Tercile -- 1= low, 3= high
FROM Matiks
ORDER BY Total_Revenue_USD DESC;
 

SELECT
    'Signed Up' AS Funnel_Stage, COUNT(*) AS Users, 1 AS Stage_Order
FROM Matiks
UNION ALL
SELECT 'Played First Game', COUNT(*), 2
FROM Matiks WHERE Total_Play_Sessions >= 1
UNION ALL
SELECT 'Repeat Session', COUNT(*), 3
FROM Matiks WHERE Total_Play_Sessions >= 2
UNION ALL
SELECT 'Engaged User (5+ sessions)', COUNT(*), 4
FROM Matiks WHERE Total_Play_Sessions >= 5
UNION ALL
SELECT 'Monetized (Made a Purchase)', COUNT(*), 5
FROM Matiks WHERE In_Game_Purchases_Count >= 1
ORDER BY Stage_Order;