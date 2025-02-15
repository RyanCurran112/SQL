USE [Intact_IQ_Behrens_Live]
GO
/****** Object:  StoredProcedure [dbo].[DD_StockValuationAgedAll]    Script Date: 04/03/2021 10:48:07 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/*
Description :	Procedure to show stock valuation using transaction movements
Author:			Dale Dickins and Jaco Jacobs
Date:			Sept 2017

Amendment #1:	2nd November 2017 Jaco Jacobs
				Changes made as there were transactions that were missing as they were part of initial import that was done.

Amendment #2:	10 May 2019 Ryan Curran
				Changes made to add further information to datadrill
*/


ALTER proc [dbo].[DD_StockValuationAgedAll] --(@Branch as varchar(20))  
as

DECLARE @Branch AS varchar(max)

DECLARE @Branches TABLE
(BRANCHCODE varchar(max))

INSERT INTO @Branches 
	SELECT C_CODE FROM T_BRANCH
		DECLARE @AgedStock TABLE
		(
			 D_BranchDescription varchar(max)
			,D_StockingStatus varchar(max)
			,D_BatchNo varchar(max)
			,D_BatchAltRef varchar(max)

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
			,D_Design varchar(max)
			,D_Season varchar(max)
			,D_Composition varchar(max)
			,D_Gender varchar(max)
			,D_Variety varchar(max)
			,D_Colour varchar(max)
			,D_Size varchar(max)
			,D_ABCClass varchar(max)
			,D_CustomerOwner varchar(max)

			--Movement Dates--
			,D_MovementDate datetime
			,D_Month Varchar(max)
			,D_Quarter varchar(max)
			,D_Year varchar(max)

			--Measures--
			,M_MovementQTY [decimal](15, 6)
			,M_Cost [decimal](15, 6)
			,M_StandardCost [decimal](15,6)
			,M_Value [decimal](15, 6)
			,M_StandardCostValue [decimal](15, 6)
		)

WHILE (SELECT COUNT(*) FROM @Branches) > 0
BEGIN

	SELECT TOP 1 @Branch = BRANCHCODE FROM @Branches

	INSERT INTO @AgedStock
		SELECT
			 Source2.BranchDescription															[BranchDescription]
			,ProductAnalysis.ProductStockingStatus												[StockingStatus]

			,productbatch.C_NUMBER																[BatchNo]
			,productbatch.C_ALTERNATEREFERENCE													[BatchAltRef]
			
			,ProductAnalysis.ProductDivision													[Division]
			,ProductAnalysis.Pre2019Division													[2018Division]
			,ProductAnalysis.ProductDepartment													[Department]
			,ProductAnalysis.ProductBuyingDepartment											[BuyingDepartment]
			
			,ProductAnalysis.ProductCode														[ProductCode]
			,ProductAnalysis.ProductDescription													[ProductDescription]
			
			--Analysis--
			,ProductAnalysis.ProductCategoryClass												[Class]
			,ProductAnalysis.ProductCategoryGroup												[Group]
			,ProductAnalysis.ProductCategory													[Category]
			,ProductAnalysis.ProductBrand 														[Brand]
			,ProductAnalysis.ProductRange														[Range]
			,ProductAnalysis.ProductStyle														[Style]
			,ProductAnalysis.ProductDesignDescription											[Design]
			,ProductAnalysis.ProductSeason														[Season]
			,ProductAnalysis.ProductComposition													[Composition]
			,ProductAnalysis.ProductGender														[Gender]
			,ProductAnalysis.ProductVariety														[Variety]
			,ProductAnalysis.ProductColourDescription											[Colour]
			,ProductAnalysis.ProductSizeDescription												[Size]
			,ProductAnalysis.ProductABCClass													[ABCClass]
			,customer.C_NAME 																	[CustomerOwner]
		
			--Movement Dates--			
			,Source2.MovementDate																	[MovementDate]
			,CONCAT(DATEPART(yyyy,source2.movementdate),'-',DATENAME(MONTH,source2.movementdate))	[Month]
			,CONCAT(DATEPART(yyyy,source2.movementdate),'Q',DATEPART(q,source2.movementdate))		[Quarter]
			,DATEPART(yyyy,source2.movementdate)													[Year]
		
			--Measures--
			,CASE 
				WHEN Source2.RunningTotal > (CASE		
													WHEN (StockLevel-RunningTotal) > 0				THEN RunningTotal
													ELSE RunningTotal+(StockLevel-RunningTotal)
												END )												THEN Source2.MovementAmount-(RunningTotal-(CASE	 
																																					WHEN (StockLevel-RunningTotal) > 0  THEN RunningTotal
																																					ELSE RunningTotal+(StockLevel-RunningTotal)
																																				END ))
				ELSE Source2.MovementAmount
				END																					[MovementQTY]
			,pbc.C_AVERAGECOST																		[Cost]
			,Costings.C_STANDARDCOST																[StandardCost]
			,((CASE 
					WHEN Source2.RunningTotal > (CASE  
													WHEN (StockLevel-RunningTotal) > 0				THEN RunningTotal
													ELSE RunningTotal+(StockLevel-RunningTotal)
												END )												THEN Source2.MovementAmount-(RunningTotal-(CASE		
																																					WHEN (StockLevel-RunningTotal) > 0 THEN Source2.RunningTotal
																																					ELSE RunningTotal+(StockLevel-RunningTotal)
																																				END ))
				ELSE Source2.MovementAmount
				END)*pbc.C_AVERAGECOST)																[Value]
			,((CASE 
					WHEN Source2.RunningTotal > (CASE  
													WHEN (StockLevel-RunningTotal) > 0				THEN RunningTotal
													ELSE RunningTotal+(StockLevel-RunningTotal)
												END )												THEN Source2.MovementAmount-(RunningTotal-(CASE		
																																					WHEN (StockLevel-RunningTotal) > 0 THEN Source2.RunningTotal
																																					ELSE RunningTotal+(StockLevel-RunningTotal)
																																				END ))
				ELSE Source2.MovementAmount
				END)*Costings.C_STANDARDCOST)														[StandardCostValue]
		
		FROM 
			(SELECT TOP 100 PERCENT
				CASE 
					WHEN (StockLevel-RunningTotal) > 0 AND Source.RowNum = 1		THEN RunningTotal
					WHEN (StockLevel-RunningTotal) > 0 AND Source.RowNum <> 1		THEN (StockLevel-RunningTotal)
					ELSE RunningTotal+(StockLevel-RunningTotal)
				END																				[StockLevelAsAt]
	   			,row_number () over(Partition by BranchCode, ProductCode, (CASE	WHEN (StockLevel-RunningTotal) > 0 
																				THEN RunningTotal
																				ELSE RunningTotal+(StockLevel-RunningTotal)
																		  END)
				,MovementDate
					ORDER BY ProductCode) STKLRowNum 
				,*
				FROM (
					SELECT TOP 100 PERCENT
						 row_number () over(Partition by tb.C_CODE,tp.C_CODE ORDER BY tb.C_CODE)	[RowNum]
						,tb.C_CODE																	[BranchCode]
						,tb.C_DESCRIPTION															[BranchDescription]
						,tp.C_CODE																	[ProductCode]
						,tp.C_DESCRIPTION															[ProductDescription]
						,C_DATE																		[MovementDate]
						,C_QUANTITY																	[MovementAmount]
						,SUM(C_QUANTITY) OVER(partition by tp.C_CODE ORDER BY C_DATE desc
							ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)						[RunningTotal]
						,tp2.C_STOCKLEVEL															[StockLevel]
						,tsl.C_PRODUCTBATCH															[ProductBatch]
					FROM dbo.T_STOCKMOVEMENT					ts
					INNER JOIN dbo.T_STOCKMOVEMENT_LINE			tsl	(NOLOCK) ON ts.C_ID = tsl.C__OWNER_
					INNER JOIN dbo.T_STOCKBIN					ts2	(NOLOCK) ON tsl.C_STOCKBIN = ts2.C_ID
					INNER JOIN dbo.T_STOCKLOCATION				ts3	(NOLOCK) ON ts3.C_ID = ts2.C_LOCATION
					INNER JOIN dbo.T_BRANCH						tb	(NOLOCK) ON tb.C_ID = ts3.C_BRANCH
					INNER JOIN dbo.T_PRODUCT					tp	(NOLOCK) ON tp.C_ID = tsl.C_PRODUCT
					INNER JOIN dbo.T_PRODUCTBRANCHSTATISTICS	tp2	(NOLOCK) ON tsl.C_PRODUCT = tp2.C_PRODUCT AND tb.C_ID = tp2.C_BRANCH
					WHERE tp2.C_STOCKLEVEL > 0	
						AND C_QUANTITY > 0 
						AND ts.C_SHORTTYPENAME <> 'SC/Tfr' 
						AND tb.C_CODE = @Branch
					ORDER BY tb.C_CODE
				) Source
			) Source2
			LEFT JOIN T_PRODUCT Product						(NOLOCK) ON Product.C_CODE = Source2.ProductCode
			LEFT JOIN T_BRANCH Branch						(NOLOCK) ON Branch.C_CODE = source2.BranchCode
			LEFT JOIN T_PRODUCT_BRANCHINFO pb				(NOLOCK) ON pb.C__OWNER_ = Product.C_ID and pb.C_BRANCH = branch.C_ID
			LEFT JOIN T_PRODUCT_BRANCHINFO_COSTINGS pbc		(NOLOCK) ON pbc.C_ID = pb.C_COSTINGS
			LEFT JOIN T_PRODUCTBATCH ProductBatch			(NOLOCK) ON Source2.ProductBatch = ProductBatch.C_ID
			LEFT JOIN T_CUSTOMER Customer					(NOLOCK) ON Product.C_D_CUSTOMEROWNER = Customer.C_ID
			LEFT JOIN dbo.T_PRODUCT_COSTINGS Costings		(NOLOCK) ON Product.C_COSTINGS = Costings.C_ID
			INNER JOIN (SELECT * FROM fn_GetProductAnalysis()) ProductAnalysis		ON ProductAnalysis.ProductID			= Product.C_ID

			WHERE CASE 
					WHEN Source2.RunningTotal > (CASE	
													WHEN (StockLevel-RunningTotal) > 0		THEN RunningTotal
													ELSE RunningTotal+(StockLevel-RunningTotal)
												END )										THEN Source2.MovementAmount-(RunningTotal-(CASE	
																																			WHEN (StockLevel-RunningTotal) > 0 THEN Source2.RunningTotal
																																			ELSE RunningTotal+(StockLevel-RunningTotal)
																																		END ))
					ELSE Source2.MovementAmount
					END > 0
				AND STKLRowNum = 1
				AND ProductAnalysis.ProductDivision <> 'TEST'
			ORDER BY BranchCode, ProductCode, MovementDate
		
			DELETE FROM @branches 
			WHERE BRANCHCODE = @Branch
		END

DROP table IF EXISTS Intact_IQ_Behrens_Live_Archive.dbo.AgedStock

SELECT * INTO Intact_IQ_Behrens_Live_Archive.dbo.AgedStock FROM (
	SELECT * FROM @AgedStock
) AS nest
ORDER BY D_ProductCode



