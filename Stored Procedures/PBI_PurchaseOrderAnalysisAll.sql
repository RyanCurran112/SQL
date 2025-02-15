USE [Intact_IQ_Behrens_Live]
GO
/****** Object:  StoredProcedure [dbo].[PBI_PurchaseOrderAnalysisAll]    Script Date: 04/03/2021 10:48:46 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:				Ryan Curran
-- Date:				July 2019
-- Description:   		Stored Procedure to show Purchase Order Analysis
-- Parameters:     		N/A
-- =============================================


ALTER PROCEDURE [dbo].[PBI_PurchaseOrderAnalysisAll]	
AS
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @PurchaseAnalysis TABLE
	(
		 D_Number varchar(max)
		,D_Date datetime
		,D_Month varchar(max)
		,D_MonthYear varchar(max)
		,D_Year varchar(max)

		,D_DueDate datetime
		,D_DueMonth varchar(max)
		,D_DueMonthYear varchar(max)
		,D_DueYear varchar(max)

		,D_Branch varchar(max)
		,D_DespatchBranch varchar(max)
		,D_OrderDivision varchar(max)
		,D_OrderType varchar(max)
		,D_LineType varchar(max)
		,D_WorkflowStatus varchar(max)

		--Supplier Analysis--
		,D_SupplierDivision varchar(max)
		,D_Supplier varchar(max)
		,D_SupplierName varchar(max)
		,D_SupplierTradingName varchar(max)
		,D_SupplierCategory varchar(max)
		,D_SupplierIndustry varchar(max)
		,D_SupplierType varchar(max)

		--Product Analysis--
		,D_ProductDivision varchar(max)
		,D_ProductDepartment varchar(max)
		,D_ProductBuyingDepartment varchar(max)

		,D_ProductCode varchar(max)
		,D_ProductDescription varchar(max)

		,D_ProductABCClass varchar(max)
		,D_ProductStockingStatus varchar(max)
		,D_ProductWorkflowStatus varchar(max)

		--Analysis--
		,D_ProductCategoryClass varchar(max)
		,D_ProductCategoryGroup varchar(max)
		,D_ProductCategory varchar(max)
		,D_ProductBrand varchar(max)
		,D_ProductRange varchar(max)
		,D_ProductStyle varchar(max)
		,D_ProductStyleDescription varchar(max)
		,D_ProductVariety varchar(max)
		,D_ProductComposition varchar(max)

		,D_ProductColour varchar(max)
		,D_ProductPrimaryColour varchar(max)
		,D_ProductSecondaryColour varchar(max)
		,D_ProductSize varchar(max)
		,D_ProductType varchar(max)

		--Measures--
		,M_Quantity [decimal](15, 6)
		,M_QuantityShipped [decimal](15, 6)
		,M_QuantityOutstanding [decimal](15, 6)

		--,M_ComponentQuantityRequired [decimal](15, 6)
		--,M_ComponentQuantityOutstandingRequired [decimal](15, 6)

		,M_Volume [decimal](15, 6)
		,M_VolumeOutstanding [decimal](15, 6)

		,M_NetPriceBase [decimal](15, 6)
		,M_NetLessDiscountBase [decimal](15, 6)
		,M_NetOutstandingValueBase [decimal](15, 6)

		--,M_NetProductValue [decimal](15,6)	
		--,M_NetOutstandingProductValue [decimal](15, 6)
	)


	INSERT INTO @PurchaseAnalysis
		SELECT				
			 PurchaseOrders.Number																																D_Number
			,PurchaseOrders.Date																																D_Date
			,DATENAME(MONTH,PurchaseOrders.DateDue)																												D_Month
			,CONCAT(DATEPART(yyyy,PurchaseOrders.DateDue),'-',RIGHT('0'+CAST(MONTH(PurchaseOrders.DateDue) AS VARCHAR(2)),2))									D_MonthYear
			,DATEPART(yyyy,PurchaseOrders.DateDue)																												D_Year

			,PurchaseOrders.DateDue																																D_DueDate
			,DATENAME(MONTH,PurchaseOrders.DateDue)																												D_DueMonth
			,CONCAT(DATEPART(yyyy,PurchaseOrders.DateDue),'-',RIGHT('0'+CAST(MONTH(PurchaseOrders.DateDue) AS VARCHAR(2)),2))									D_DueMonthYear
			,DATEPART(yyyy,PurchaseOrders.DateDue)																												D_DueYear

			,PurchaseOrders.Branch																																D_Branch
			,PurchaseOrders.DeliverToBranch																														D_DespatchBranch
			,PurchaseOrders.Division																															D_OrderDivision
			,PurchaseOrders.OrderType																															D_OrderType
			,PurchaseOrders.LineType																															D_LineType
			,PurchaseOrders.WorkflowStatus																														D_WorkflowStatus

			,SupplierAnalysis.SupplierDivision																													D_SupplierDivision
			,SupplierAnalysis.SupplierCode																														D_Supplier
			,SupplierAnalysis.SupplierName																														D_SupplierName
			,SupplierAnalysis.SupplierTradingName																												D_SupplierTradingName		
			,SupplierAnalysis.SupplierCategory																													D_SupplierCategory
			,SupplierAnalysis.SupplierIndustry																													D_SupplierIndustry
			,SupplierAnalysis.SupplierType																														D_SupplierType
			
			,ProductAnalysis.ProductDivision																													D_ProductDivision
			,ProductAnalysis.ProductDepartment																													D_ProductDepartment
			,ProductAnalysis.ProductBuyingDepartment																											D_ProductBuyingDepartment

			,ProductAnalysis.ProductCode																														D_ProductCode
			,ProductAnalysis.ProductDescription																													D_ProductDescription

			,ProductAnalysis.ProductABCClass																													D_ProductABCClass
			,ProductAnalysis.ProductStockingStatus																												D_ProductStockingStatus
			,ProductAnalysis.ProductWorkflowStatus																												D_ProductWorkflowStatus
			

			,ProductAnalysis.ProductCategoryClass																												D_ProductCategoryClass
			,ProductAnalysis.ProductCategoryGroup																												D_ProductCategoryGroup
			,ProductAnalysis.ProductCategory																													D_ProductCategory
			,ProductAnalysis.ProductBrand																														D_ProductBrand
			,ProductAnalysis.ProductRange																														D_ProductRange
			,ProductAnalysis.ProductStyleCode																													D_ProductStyle
			,ProductAnalysis.ProductStyle																														D_ProductStyleDescription
			,ProductAnalysis.ProductVariety																														D_ProductVariety
			,ProductAnalysis.ProductComposition																													D_ProductComposition
			
			,ProductAnalysis.ProductColourDescription																											D_ProductColour
			,ProductAnalysis.ProductColour																														D_ProductPrimaryColour
			,ProductAnalysis.ProductSecondaryColour																												D_ProductSecondaryColour
			,ProductAnalysis.ProductSizeDescription																												D_ProductSize
			,ProductAnalysis.ProductType																														D_ProductABCClass

			,PurchaseOrders.Quantity																															M_Quantity
			,PurchaseOrders.QuantityShipped																														M_QuantityShipped
			,PurchaseOrders.QuantityOutstanding																													M_QuantityOutstanding

			--,PurchaseOrders.Quantity * ProductAssemblyAnalysis.ComponentQuantityRequired																		M_FabricQuantity
			--,PurchaseOrders.QuantityOutstanding * ProductAssemblyAnalysis.ComponentQuantityRequired																M_FabricOutstandingQuantity

			,PurchaseOrders.Quantity * ProductAnalysis.ProductVolume																							M_Volume
			,PurchaseOrders.QuantityOutstanding * ProductAnalysis.ProductVolume																					M_OutstandingVolume

			,PurchaseOrders.NetPriceBase																														M_NetPriceBase
			,PurchaseOrders.NetAmountLessDiscountBase																											M_NetLessDiscountBase
			,PurchaseOrders.NetOutstandingValueBase																												M_NetOutstandingValueBase

			--,PurchaseOrders.Quantity * ProductPricing.NetPrice																									M_NetProductValue
			--,PurchaseOrders.QuantityOutstanding * ProductPricing.NetPrice																						M_NetOutstandingProductValue

		FROM (SELECT * FROM fn_GetPurchaseOrderAnalysis()) PurchaseOrders
		INNER JOIN (SELECT * FROM fn_GetSupplierAnalysis())	SupplierAnalysis	ON SupplierAnalysis.SupplierID	= PurchaseOrders.SupplierID
		INNER JOIN (SELECT * FROM fn_GetProductAnalysis())	ProductAnalysis		ON ProductAnalysis.ProductID	= PurchaseOrders.ProductID
		--LEFT JOIN (SELECT * FROM fn_GetProductPricings())	ProductPricing		ON ProductPricing.ProductID		= PurchaseOrders.ProductID
		--LEFT JOIN (SELECT * FROM fn_GetProductAssemblyAnalysis()) ProductAssemblyAnalysis ON ProductAnalysis.ProductID = ProductAssemblyAnalysis.ProductID
		
        WHERE ProductDivision != 'TEST'

	SELECT * FROM @PurchaseAnalysis
	ORDER BY D_Number

END
