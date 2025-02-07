USE [Intact_IQ_Behrens_Live]
GO
/****** Object:  StoredProcedure [dbo].[DD_StockValuationAll]    Script Date: 04/03/2021 10:48:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Description :	Procedure to show stock valuation total
Author:			Ryan Curran
Date:			Jun 2019
*/

ALTER PROCEDURE [dbo].[DD_StockValuationAll]

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;


	DECLARE @StockValuation TABLE
	(
		 D_BranchDescription varchar(max)
		,D_BinLocation varchar(max)
		,D_StockBin varchar(max)
		,D_StockBinType varchar(max)
		,D_ProductBatch varchar(max)
		,D_BatchAltRef varchar(max)
		,D_StockingStatus varchar(max)
		
		,D_Division varchar(max)
		,D_2018Division varchar(max)
		,D_Department varchar(max)
		,D_BuyingDepartment varchar(max)

		,D_ProductCode varchar(max)
		,D_ProductDescription varchar(max)

		--Analysis--
		,D_Class varchar(max)
		,D_Group varchar(max)
		,D_Category varchar(max)
		,D_Brand varchar(max)
		,D_Range varchar(max)
		,D_Style varchar(max)
		,D_IndexProductOwner varchar(max)
		,D_IndexProductOwnerDescription varchar(max)
		,D_Design varchar(max)
		,D_Season varchar(max)
		,D_Composition varchar(max)
		,D_Gender varchar(max)
		,D_Variety varchar(max)
		,D_Colour varchar(max)
		,D_Size varchar(max)
		,D_ABCClass varchar(max)
		
		--Write Down Info--
		,D_WriteDown2015 varchar(max)
		,D_WriteDown2016 varchar(max)
		,D_WriteDown2017 varchar(max)
		,D_WriteDown2018 varchar(max)
		,D_WriteDown2019 varchar(max)
		,D_WriteDown2020 varchar(max)
		
		--Measures--
		,M_StockLevel [decimal](15, 6)
		,M_AverageCost [decimal](15, 6)
		,M_StandardCost [decimal](15,6)
		,M_Value [decimal](15, 6)
		,M_StandardCostValue [decimal](15, 6)
	)

    -- Insert statements for procedure here
	INSERT INTO @StockValuation
		SELECT
			 Source.Branch						[D_Branch]
			,Source.BinLocation					[D_Location]
			,Source.StockBin					[D_StockBin]
			,CASE 
				WHEN Source.StockBinType = 0 THEN 'Stocked' 
				WHEN Source.StockBinType = 1 THEN 'Non Stocked' 
				WHEN Source.StockBinType = 2 THEN 'Consignment' 
				END								[D_StockBinType]
			,batch.C_NUMBER						[D_BatchNumber]
			,batch.C_ALTERNATEREFERENCE			[D_BatchAltRef]

			,ProductAnalysis.ProductStockingStatus		[D_StockingStatus]
		
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

			,indexproductowner.C_CODE					[D_IndexProductOwnerCode]
			,indexproductowner.C_DESCRIPTION			[D_IndexProductOwnerDescription]

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

			,source.StockLevel									[M_StockLevel]
			,source.AverageCost									[M_AverageCost]
			,source.StandardCost								[M_StandardCost]
			,source.StockLevel * source.AverageCost				[M_AverageCostStockValue]
			,source.StockLevel * source.StandardCost			[M_StandardCostStockValue]

			FROM (SELECT
					 branch.C_CODE													[Branch]
					,binlocation.C_DESCRIPTION										[BinLocation]
					,stockbin.C_DESCRIPTION											[StockBin]
					,stockbin.C_STOCKBINTYPE										[StockBinType]
					,product.C_ID													[ProductID]
					,stockbinstats.C_STOCKLEVEL										[StockLevel]
					,branchinfocostings.C_AVERAGECOST								[AverageCost]
					,productcostings.C_STANDARDCOST									[StandardCost]
					,stockbinstats.C_STOCKLEVEL * branchinfocostings.C_AVERAGECOST	[TotalAverageCost]
					,stockbinstats.C_STOCKLEVEL * productcostings.C_STANDARDCOST	[TotalStandardCost]
					,stockbinstats.C_PRODUCTBATCH									[ProductBatch]
					FROM
					dbo.T_PRODUCT_BRANCHINFO_COSTINGS			branchinfocostings
					INNER JOIN dbo.T_PRODUCT_BRANCHINFO			branchinfo			(nolock)	ON branchinfo.C_COSTINGS		= branchinfocostings.C_ID
					INNER JOIN dbo.T_PRODUCT					product				(nolock)
					INNER JOIN dbo.T_PRODUCT_COSTINGS			productcostings		(nolock)	ON product.C_COSTINGS			= productcostings.C_ID 
					INNER JOIN dbo.T_STOCKBIN					stockbin			(nolock)
					INNER JOIN dbo.T_PRODUCTSTOCKBINSTATISTICS	stockbinstats		(nolock)	ON stockbinstats.C_STOCKBIN		= stockbin.C_ID
					INNER JOIN dbo.T_STOCKLOCATION				binlocation			(nolock)	ON stockbin.C_LOCATION			= binlocation.C_ID
																								ON stockbinstats.C_PRODUCT		= product.C_ID
																								ON branchinfo.C__OWNER_			= product.C_ID 
					INNER JOIN dbo.T_BRANCH branch									(nolock)	ON binlocation.C_BRANCH			= branch.C_ID 
																								AND branchinfo.C_BRANCH			= branch.C_ID 	
				) Source
				LEFT JOIN dbo.T_PRODUCT product											(nolock)	ON Source.ProductID				= product.C_ID
				LEFT JOIN dbo.T_PRODUCTBATCH batch										(nolock)	ON Source.ProductBatch			= batch.C_ID 
				LEFT JOIN dbo.T_PRODUCT indexproductowner								(nolock)	ON product.C_INDEXPRODUCTOWNER	= indexproductowner.C_ID
				LEFT JOIN (SELECT * FROM fn_GetProductAnalysis()) ProductAnalysis					ON ProductAnalysis.ProductID	= Product.C_ID

			WHERE ProductAnalysis.ProductDivision <> 'TEST' AND Source.StockLevel != 0	
		END

DROP table IF EXISTS Intact_IQ_Behrens_Live_Archive.dbo.StockValuation

SELECT * INTO Intact_IQ_Behrens_Live_Archive.dbo.StockValuation FROM (
	SELECT * FROM @StockValuation
) AS nest
ORDER BY D_ProductCode


