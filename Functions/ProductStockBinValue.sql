USE [Intact_IQ_Behrens_Live]
GO
/****** Object:  UserDefinedFunction [dbo].[fn_GetProductStockBinValue]    Script Date: 04/03/2021 10:55:34 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Ryan Curran
-- Create date: 14/10/2020
-- Description:	A function to return Product Stock Bin Value
-- =============================================
ALTER FUNCTION [dbo].[fn_GetProductStockBinValue]
(
	 @stockbin bigint
	,@product bigint
)
RETURNS numeric(18,5)
AS
BEGIN

	DECLARE @stocklevel decimal(18,6)
	DECLARE @averagecost decimal(18,6)
	
	DECLARE @totalcost decimal(18,6)

	SET @averagecost = (

		SELECT 
			C_AVERAGECOST
		FROM T_PRODUCT_BRANCHINFO PBI
		INNER JOIN T_PRODUCT_BRANCHINFO_COSTINGS PBIC ON PBI.C_COSTINGS = PBIC.C_ID
		WHERE PBI.C__OWNER_ = @product AND C_BRANCH = (SELECT SL.C_BRANCH 
														FROM T_STOCKBIN SB
														INNER JOIN T_STOCKLOCATION SL ON SB.C_LOCATION = SL.C_ID
														WHERE SB.C_ID = @stockbin)
	)
	
	SET @stocklevel = (
		SELECT
			SUM(StockBinStats.C_STOCKLEVEL) 
		FROM dbo.T_PRODUCTSTOCKBINSTATISTICS	StockBinStats
		INNER JOIN dbo.T_STOCKBIN				StockBin		ON StockBin.C_ID = StockBinStats.C_STOCKBIN
		WHERE C_PRODUCT = @product  AND C_STOCKBIN = @stockbin AND C_STOCKLEVEL > 0
	)

		-- Return the result of the function

	SET @totalcost = @averagecost * @stocklevel

	RETURN @totalcost

END
