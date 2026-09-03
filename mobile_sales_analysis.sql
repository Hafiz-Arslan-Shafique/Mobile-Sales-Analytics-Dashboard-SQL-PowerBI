-- Mobile Sales Analysis
-- Database: Mydata
-- SQL Server
-- Purpose: Data quality checks, EDA, product performance analysis and ranking

USE Mydata;
GO

-- 1. Inspect the dataset
SELECT * FROM dbo.Mobile_sales_data;
GO

SELECT COUNT(*) AS TotalRows
FROM dbo.Mobile_sales_data;
GO

SELECT TOP 10 *
FROM dbo.Mobile_sales_data;
GO

-- 2. Check column names and data types
SELECT
    COLUMN_NAME,
    DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Mobile_sales_data';
GO

-- 3. Basic EDA: row count, year range and cardinality
SELECT
    COUNT(*) AS Total_Rows,
    MIN([Year]) AS Min_Year,
    MAX([Year]) AS Max_Year,
    COUNT(DISTINCT Brand) AS Unique_Brands,
    COUNT(DISTINCT Mobile_Model) AS Unique_Models,
    COUNT(DISTINCT City) AS Unique_Cities
FROM dbo.Mobile_sales_data;
GO

-- 4. NULL checks for important analytical columns
SELECT
    SUM(CASE WHEN Brand IS NULL THEN 1 ELSE 0 END) AS Null_Brand,
    SUM(CASE WHEN Mobile_Model IS NULL THEN 1 ELSE 0 END) AS Null_Model,
    SUM(CASE WHEN Total_Sales IS NULL THEN 1 ELSE 0 END) AS Null_Sales,
    SUM(CASE WHEN Sum_of_Units_Sold IS NULL THEN 1 ELSE 0 END) AS Null_Units
FROM dbo.Mobile_sales_data;
GO

-- 5. Duplicate check using Sr_No
SELECT
    [Sr_No],
    COUNT(*) AS Dup_Count
FROM dbo.Mobile_sales_data
GROUP BY [Sr_No]
HAVING COUNT(*) > 1;
GO

-- 6. Clean text fields by removing leading/trailing spaces
UPDATE dbo.Mobile_sales_data
SET Brand = LTRIM(RTRIM(Brand));

UPDATE dbo.Mobile_sales_data
SET Mobile_Model = LTRIM(RTRIM(Mobile_Model));

UPDATE dbo.Mobile_sales_data
SET City = LTRIM(RTRIM(City));

UPDATE dbo.Mobile_sales_data
SET Payment_Method = LTRIM(RTRIM(Payment_Method));
GO

-- 7. Create a reusable product performance summary view
DROP VIEW IF EXISTS dbo.vw_Product_Performance;
GO

CREATE VIEW dbo.vw_Product_Performance AS
SELECT
    Brand,
    Mobile_Model,
    COUNT(*) AS Num_Transactions,
    SUM(Sum_of_Units_Sold) AS Total_Units_Sold,
    SUM(Total_Sales) AS Total_Revenue,
    AVG(Sum_of_Price_Per_Unit) AS Avg_Price_Per_Unit,
    SUM(Total_Sales) * 1.0
        / NULLIF(SUM(Sum_of_Units_Sold), 0) AS Calculated_Avg_Price,
    AVG(Sum_of_Customer_Ratings * 1.0) AS Avg_Customer_Rating
FROM dbo.Mobile_sales_data
GROUP BY Brand, Mobile_Model;
GO

-- 8. Review top products by revenue
SELECT TOP 10 *
FROM dbo.vw_Product_Performance
ORDER BY Total_Revenue DESC;
GO

-- 9. Rank products by revenue and units sold
SELECT
    Brand,
    Mobile_Model,
    Total_Revenue,
    Total_Units_Sold,
    RANK() OVER (ORDER BY Total_Revenue DESC) AS Revenue_Rank,
    RANK() OVER (ORDER BY Total_Units_Sold DESC) AS Quantity_Rank,
    RANK() OVER (ORDER BY Total_Revenue DESC)
      - RANK() OVER (ORDER BY Total_Units_Sold DESC) AS Rank_Diff
FROM dbo.vw_Product_Performance
ORDER BY Total_Revenue DESC;
GO

-- 10. Calculate each product's revenue contribution and cumulative share
WITH ProductTotals AS (
    SELECT SUM(Total_Sales) AS Grand_Total
    FROM dbo.Mobile_sales_data
)
SELECT
    Brand,
    Mobile_Model,
    Total_Revenue,
    CAST(Total_Revenue * 100.0 / t.Grand_Total AS DECIMAL(5,2)) AS Revenue_Pct,
    SUM(Total_Revenue * 100.0 / t.Grand_Total)
        OVER (
            ORDER BY Total_Revenue DESC
            ROWS UNBOUNDED PRECEDING
        ) AS Cum_Revenue_Pct
FROM dbo.vw_Product_Performance
CROSS JOIN ProductTotals t
ORDER BY Total_Revenue DESC;
GO

-- 11. Identify where selected top products sell best
SELECT
    City,
    Brand,
    Mobile_Model,
    SUM(Total_Sales) AS City_Revenue,
    RANK() OVER (
        PARTITION BY City
        ORDER BY SUM(Total_Sales) DESC
    ) AS Rank_In_City
FROM dbo.Mobile_sales_data
WHERE Mobile_Model IN (
    'iPhone SE',
    'OnePlus Nord',
    'Galaxy Note 20',
    'Vivo Y51',
    'Galaxy S21'
)
GROUP BY City, Brand, Mobile_Model
ORDER BY City, Rank_In_City;
GO
