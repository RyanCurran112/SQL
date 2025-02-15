USE [Intact_IQ_Behrens_Live]
GO
/****** Object:  UserDefinedFunction [dbo].[fn_GetStockLevelHistory]    Script Date: 04/03/2021 10:54:13 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Ryan Curran
-- Create date: 23/09/2020
-- Description:	A function to retrieve Stock Level History of a product
-- =============================================
ALTER FUNCTION [dbo].[fn_GetStockLevelHistory]
(	
	@productid bigint
)
RETURNS @T_StockLevelHistory TABLE( 
									 C_DateTime Datetime INDEX IX1 CLUSTERED
									,C_StockMovementShortTypeName varchar(max)
									,C_Quantity numeric (18,5)
									,C_StockLevel numeric (18,5)
								) 
AS
BEGIN 
	DECLARE @total numeric (18,5)

	INSERT INTO @T_StockLevelHistory
		SELECT 
			 SM.C_DATE								'C_DateTime'
			,SM.C_SHORTTYPENAME						'C_StockMovementShortTypeName'
			,C_QUANTITY 							'C_Quantity'
			,0										'C_StockLevel'
		FROM T_STOCKMOVEMENT_LINE	SML
		INNER JOIN T_STOCKMOVEMENT	SM ON SML.C__OWNER_ = SM.C_ID
		WHERE SML.C_PRODUCT = @productid AND (SM.C_DATE >= '2017/10/01' or (SELECT COUNT(C_DateTime) FROM @T_StockLevelHistory) = 0 ) 
		ORDER BY SM.C_DATE, C_QUANTITY DESC

	SET @total = 0.00

	--Calculate Running Total
	UPDATE @T_StockLevelHistory SET C_StockLevel = @total, @total = @total + C_Quantity 


	RETURN 
END
