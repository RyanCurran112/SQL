USE [Intact_IQ_Behrens_Live]
GO
/****** Object:  StoredProcedure [dbo].[DD_DivisionStockLevelAtDate]    Script Date: 04/03/2021 10:46:20 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:				Ryan Curran
-- Date:				July 2019
-- Description:   		Stored Procedure to display stock level for division at submitted date
--						This was built for an Power BI.
-- Parameters:     		N/A
-- =============================================
ALTER PROCEDURE [dbo].[DD_DivisionStockLevelAtDate]
	 @divisioncode varchar(max)
	,@date datetime
AS
BEGIN

	SET NOCOUNT ON;
	DECLARE @Products TABLE 
	(
		 D_Date datetime
		,D_StockingStatus varchar(max)
		,D_Division varchar(max)
		,D_2018Division varchar(max)
		,D_Department varchar(max)
		,D_BuyingDepartment varchar(max)
		
		,ProductID bigint
		,ProductCode varchar(max)
		,ProductDescription varchar(max)

		--Analysis--
		,D_Class varchar(max)
		,D_Group varchar(max)
		,D_Category varchar(max)
		,D_Brand varchar(max)
		,D_Range varchar(max)
		,D_Style varchar(max)
		,D_Design varchar(max)
		,D_Season varchar(max)
		,D_Composition varchar(max)
		,D_Gender varchar(max)
		,D_Variety varchar(max)
		,D_Colour varchar(max)
		,D_Size varchar(max)
		,D_ABCClass varchar(max)
		
		,M_StockLevel decimal(18,3)
	)
	
	DECLARE @startdate datetime
	DECLARE @enddate datetime

	SET @startdate = DATEADD(day, 1, @date)
	SET @enddate = DATEADD(day, 1, @date)

	INSERT INTO @Products 
	SELECT
		 @date																																[Date]
		,ProductAnalysis.ProductStockingStatus																								[StockingStatus]

		,ProductAnalysis.ProductDivision																									[Division]
		,ProductAnalysis.Pre2019Division																									[2018Division]
		,ProductAnalysis.ProductDepartment																									[Department]
		,ProductAnalysis.ProductBuyingDepartment																							[BuyingDepartment]

		,ProductAnalysis.ProductID																											[ProductID]
		,ProductAnalysis.ProductCode																										[ProductCode]
		,ProductAnalysis.ProductDescription																									[ProductDescription]
		

		--Analysis--
		,ProductAnalysis.ProductCategoryClass																								[Class]
		,ProductAnalysis.ProductCategoryGroup																								[Group]
		,ProductAnalysis.ProductCategory																									[Category]
		,ProductAnalysis.ProductBrand 																										[Brand]
		,ProductAnalysis.ProductRange																										[Range]
		,ProductAnalysis.ProductStyle																										[Style]
		,ProductAnalysis.ProductDesignDescription																							[Design]
		,ProductAnalysis.ProductSeason																										[Season]
		,ProductAnalysis.ProductComposition																									[Composition]
		,ProductAnalysis.ProductGender																										[Gender]
		,ProductAnalysis.ProductVariety																										[Variety]
		,ProductAnalysis.ProductColourDescription																							[Colour]
		,ProductAnalysis.ProductSizeDescription																								[Size]
		,ProductAnalysis.ProductABCClass																									[ABCClass]

		,(SELECT dbo.fn_GetStockLevelAtDate(ProductAnalysis.ProductID, @date))																[StockLevel]
		FROM
		( 
			SELECT *
			FROM dbo.fn_GetProductAnalysis()

		) ProductAnalysis
	WHERE ProductAnalysis.ProductDivision = @divisioncode

	SELECT * 
	FROM @Products 
		
END
