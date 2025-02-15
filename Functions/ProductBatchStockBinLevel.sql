USE [Intact_IQ_Behrens_Live]
GO
/****** Object:  UserDefinedFunction [dbo].[fn_GetProductBatchStockBinLevel]    Script Date: 04/03/2021 10:54:57 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Ryan Curran
-- Create date: 14/10/2020
-- Description:	A function to return Product Batch Stock Bin Level
-- =============================================
ALTER FUNCTION [dbo].[fn_GetProductBatchStockBinLevel]
(
	 @stockbin bigint
	,@product bigint
	,@productbatch bigint
)
RETURNS numeric(18,5)
AS
BEGIN

	RETURN(
		SELECT
			 SUM(StockBinStats.C_STOCKLEVEL)
		FROM dbo.T_PRODUCTSTOCKBINSTATISTICS	StockBinStats
		WHERE C_PRODUCT = @product  AND C_STOCKBIN = @stockbin AND C_PRODUCTBATCH = @productbatch

	)
END
