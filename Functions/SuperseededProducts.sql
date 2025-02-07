USE [Intact_IQ_Behrens_Live]
GO
/****** Object:  UserDefinedFunction [dbo].[fn_GetSupersessionProducts]    Script Date: 04/03/2021 10:54:33 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
ALTER FUNCTION [dbo].[fn_GetSupersessionProducts]
(	
	-- Add the parameters for the function here
	@productid bigint
)
RETURNS TABLE 
AS
RETURN 
(
	-- Add the SELECT statement with parameter references here
	SELECT C_ID, C_CODE, ISNULL(NULLIF(C_D_OLDSTOCKCODE, ''),C_CODE) C_D_OLDSTOCKCODE 
	FROM T_PRODUCT 
	WHERE C_SUPERSEDEDBY = @productid or C_ID = @productid

	/*
	--Recursive Version - Finds the supersessions of supersessions of supersessions etc (Slow)
	with SupercessionProducts
	as(
		--anchor
		SELECT
			 C_ID
			,C_CODE
			,ISNULL(NULLIF(C_D_OLDSTOCKCODE, ''),C_CODE) C_D_OLDSTOCKCODE
		FROM T_PRODUCT 
		WHERE C_ID = @productid

		--recursion
		union all
		SELECT P.C_ID, P.C_CODE, ISNULL(NULLIF(P.C_D_OLDSTOCKCODE, ''),P.C_CODE)
		FROM T_PRODUCT P
		JOIN SupercessionProducts as SP on P.C_SUPERSEDEDBY = SP.C_ID

	)

	SELECT 
	 C_ID
	,C_CODE
	,C_D_OLDSTOCKCODE
	FROM SupercessionProducts --option (maxrecursion 0) cannot be called here so is called when using the table
	*/
)
