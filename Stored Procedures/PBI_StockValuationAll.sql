USE [Intact_IQ_Behrens_Live]
GO
/****** Object:  StoredProcedure [dbo].[PBI_StockValuationAll]    Script Date: 04/03/2021 10:49:23 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Description :	Procedure to show stock valuation total
Author:			Ryan Curran
Date:			Jun 2019
*/

ALTER PROCEDURE [dbo].[PBI_StockValuationAll]

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT
		 ProductAnalysis.ProductStockingStatus		[D_StockingStatus]
		
		,ProductAnalysis.ProductDivision			[D_ProductDivision]
		,ProductAnalysis.Pre2019Division			[D_2018Division]
		,ProductAnalysis.ProductDepartment			[D_Department]
		,ProductAnalysis.ProductBuyingDepartment	[D_BuyingDepartment]

		,ProductAnalysis.ProductCode				[D_ProductCode]
		,ProductAnalysis.ProductDescription			[D_ProductDescription]

		,ProductAnalysis.ProductCategoryClass		[D_Class]
		,ProductAnalysis.ProductCategoryGroup		[D_Group]
		,ProductAnalysis.ProductCategory			[D_Category]
		,ProductAnalysis.ProductBrand				[D_Brand]
		,ProductAnalysis.ProductRange				[D_Range]
		,ProductAnalysis.ProductStyle				[D_Style]

		,ProductAnalysis.ProductDesignDescription	[D_Design]
		,ProductAnalysis.ProductSeason   			[D_Season]
		,ProductAnalysis.ProductComposition   		[D_Composition]
		,ProductAnalysis.ProductGender   			[D_Gender]
		,ProductAnalysis.ProductVariety   			[D_Variety]
		,ProductAnalysis.ProductColourDescription	[D_Colour]
		,ProductAnalysis.ProductSizeDescription		[D_Size]
		,ProductAnalysis.ProductABCClass			[D_ABCClass]

		,ProductAnalysis.ProductWriteDown2015		[D_WriteDown2015]
		,ProductAnalysis.ProductWriteDown2016		[D_WriteDown2016]
		,ProductAnalysis.ProductWriteDown2017		[D_WriteDown2017]
		,ProductAnalysis.ProductWriteDown2018		[D_WriteDown2018]
		,ProductAnalysis.ProductWriteDown2019		[D_WriteDown2019]
		,ProductAnalysis.ProductWriteDown2020		[D_WriteDown2020]

		,branchstats.C_STOCKLEVEL					[M_StockLevel]

		,ReplenishmentSetup.C_MINIMUMSTOCKLEVEL		[M_MinimumStockLevel]
		,ReplenishmentSetup.C_MAXIMUMSTOCKLEVEL		[M_MaximumStockLevel]

		,branchstats.C_STOCKLEVEL * ProductAnalysis.ProductVolume	[M_StockLevelVolume]
		,ReplenishmentSetup.C_MINIMUMSTOCKLEVEL * ProductAnalysis.ProductVolume	[M_SafetyStockLevelVolume]
		,ReplenishmentSetup.C_MAXIMUMSTOCKLEVEL * ProductAnalysis.ProductVolume	[M_MaxStockLevelVolume]

		FROM dbo.T_PRODUCTBRANCHSTATISTICS	branchstats		
		LEFT JOIN dbo.T_PRODUCT				product								(nolock)	ON branchstats.C_PRODUCT		= product.C_ID
		LEFT JOIN (SELECT * FROM fn_GetProductAnalysis()) ProductAnalysis					ON ProductAnalysis.ProductID	= Product.C_ID
		LEFT JOIN dbo.T_PRODUCT_REPLENISHMENTSETUP		ReplenishmentSetup		(nolock)	ON Product.C_REPLENISHMENTSETUP	 = ReplenishmentSetup.C_ID
		LEFT JOIN dbo.T_BRANCH							branch					(nolock)	ON branch.C_ID = branchstats.C_BRANCH

		WHERE ProductAnalysis.ProductDivision <> 'TEST' AND branchstats.C_STOCKLEVEL != 0 AND branch.C_CODE = 'HQ'
END

