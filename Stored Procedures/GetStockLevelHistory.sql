USE [Intact_IQ_Behrens_Live]
GO
/****** Object:  StoredProcedure [dbo].[BEH_GetDivisionStockLevelHistory]    Script Date: 04/03/2021 10:41:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Thomas Loughrey
-- =============================================
	--The following is a standalone stored procedure to check the stock level history across the entire division, i just copied this to excel and plotted however this could easily be added
	-- to a javascript plot to check this easily.
-- =============================================
ALTER PROCEDURE [dbo].[BEH_GetDivisionStockLevelHistory]
	-- Add the parameters for the stored procedure here
	@divisioncode nvarchar(max)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

declare @division bigint
set @division = (SELECT C_ID FROM T_CT_DIVISION WHERE C_CODE = @divisioncode)

declare @temptable table(
       C_DateTime Datetime INDEX IX1 CLUSTERED
       ,C_Quantity numeric (18,5)
       ,C_StockLevel numeric (18,5)
)

--Sage Data
Insert INTO @temptable
SELECT
       CONVERT(CHAR(19),SML.[movement_date],120) as 'C_DateTime'
       ,[movement_quantity] as 'C_Quantity'
       ,0 as 'C_StockLevel'
FROM [SageData].[dbo].[stkhstm] as SML
Where product COLLATE SQL_Latin1_General_CP1_CI_AS IN (SELECT isnull(C_D_OLDSTOCKCODE,C_CODE) FROM T_PRODUCT WHERE C_D_PRODUCTDIVISION = @division)
and val_only_adj_ind != 'V'
order by SML.[movement_date], [movement_quantity] DESC

--Intact Data
Insert INTO @temptable
SELECT 
       CONVERT(CHAR(19),SM.C_DATE,120) as 'C_DateTime'
       ,C_QUANTITY as 'C_Quantity'
       ,0 as 'C_StockLevel'
FROM T_STOCKMOVEMENT_LINE as SML
JOIN T_STOCKMOVEMENT as SM on SML.C__OWNER_ = SM.C_ID
Where SML.C_PRODUCT IN (SELECT C_ID FROM T_PRODUCT WHERE C_D_PRODUCTDIVISION = @division) and (SM.C_DATE > '2017/10/01' or (SELECT COUNT(C_DateTime) FROM @temptable) = 0 ) --if sage data cannot be found use all intact data
order by SM.C_DATE, C_QUANTITY DESC

declare @total numeric (18,5)
set @total = 0.00

update @temptable set C_StockLevel = @total, @total = @total + C_Quantity 

select 
CONVERT(CHAR(19),C_DateTime,120) as 'C_DateTime'
,cast(cast(C_StockLevel as numeric(18,1) ) as nvarchar(50)) as 'C_StockLevel'
from @temptable
where year(C_DateTime) > 2014
order by DATEDIFF(second,'2000-01-01',C_DateTime), IIF(C_QUANTITY > 0,0,1)

END
