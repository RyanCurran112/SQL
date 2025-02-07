USE [Intact_IQ_Behrens_Live]
GO
/****** Object:  UserDefinedFunction [dbo].[fn_GetProductStockingStatus]    Script Date: 04/03/2021 10:55:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Ryan Curran
-- Create date: 03/09/2019
-- Description:	A function to return Product Stocking Status
-- =============================================
ALTER FUNCTION [dbo].[fn_GetProductStockingStatus]
(
	@stockingstatus bigint
)
RETURNS nvarchar(200)
AS
BEGIN
	RETURN (
		SELECT 
			CASE 
				WHEN @stockingstatus = 0 THEN 'Stocked'
				WHEN @stockingstatus = 1 THEN 'Non Stocked'
				WHEN @stockingstatus = 2 THEN 'Superseeded'
				WHEN @stockingstatus = 3 THEN 'Superseeded Immediately'
				WHEN @stockingstatus = 4 THEN 'Discontinued After Sold'
				WHEN @stockingstatus = 5 THEN 'Discontinued Immediately'
				WHEN @stockingstatus = 6 THEN 'End of Life'
				WHEN @stockingstatus = 7 THEN 'Not Applicable'
				WHEN @stockingstatus = 8 THEN 'Run Down'
			
				ELSE 'Not Defined - Speak to SysAdmin'
			END
	)

END
