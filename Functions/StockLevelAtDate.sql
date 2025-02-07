USE [Intact_IQ_Behrens_Live]
GO
/****** Object:  UserDefinedFunction [dbo].[fn_GetStockLevelAtDate]    Script Date: 04/03/2021 10:56:35 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Ryan Curran
-- Create date: 23/09/2020
-- Description:	A function to retreive Stock Level at a period in time
-- =============================================
ALTER FUNCTION [dbo].[fn_GetStockLevelAtDate]
(
	 @productid bigint
	,@dateintime datetime
)
RETURNS decimal(18,3)
AS
BEGIN
	DECLARE @temptable table(
							 DateTime datetime
							,StockMovementType varchar(max)
							,Quantity decimal(18,3)
							,StockLevel decimal(18,3)
						)

	DECLARE @temptable2 table(
							 DateTime datetime
							,StockLevel decimal(18,3)
						)

	INSERT INTO @temptable
		SELECT * 
		FROM dbo.fn_GetStockLevelHistory(@productid)

	INSERT INTO @temptable2
		SELECT 
			TOP 1 datediff(dd, DateTime, DATEADD(day, 1, @dateintime)), StockLevel
		FROM @temptable 
		WHERE DateTime <= DATEADD(day, -1, @dateintime)  AND StockMovementType != 'SC/Tfr'
		ORDER BY 1 ASC

	RETURN 
	(
		SELECT StockLevel 
		FROM @temptable2
	)		
END
