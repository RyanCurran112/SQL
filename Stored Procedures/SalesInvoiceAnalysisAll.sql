USE [Intact_IQ_Behrens_Live]
GO
/****** Object:  StoredProcedure [dbo].[DD_SalesInvoiceAnalysisAll]    Script Date: 04/03/2021 10:47:32 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:				Ryan Curran
-- Date:				July 2019
-- Description:   		Stored Procedure to recalculate Sales Analysis taking into account Sales Invoices & Sales Credit Notes.
--						This was built for an Intact Datadrill. It doesn't return data, just updates table Intact_IQ_Behrens_Live_Archive.dbo.SalesInvoiceAnalysisAll
-- Parameters:     		N/A
-- =============================================
/*
Author:			Ryan Curran
Description :	Procedure to show Sales Analysis using Invoices & Credits (This doesn't take into account superseeded products)

Date:			June 2019
*/

ALTER PROCEDURE [dbo].[DD_SalesInvoiceAnalysisAll]	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @SalesAnalysis TABLE
	(
		 D_Number varchar(max)
		,D_Date datetime
		,D_Week varchar(max)
		,D_MonthName varchar(max)
		,D_MonthNameYear varchar(max)
		,D_Month varchar(max)
		,D_MonthYear varchar(max)
		,D_Quarter varchar(max)
		,D_QuarterYear varchar(max)
		,D_Year varchar(max)
		,D_Period varchar(max)
		,D_Branch varchar(max)
		,D_DespatchBranch varchar(max)
		,D_TransactionDivision varchar(max)
		,D_TransactionSalesRep varchar(max)
		,D_TransactionType varchar(max)
		,D_LineType varchar(max)
		,D_CreditNoteLineReason varchar(max)

		--Customer Analysis--
		,D_CustomerDivision varchar(max)
		,D_Customer varchar(max)
		,D_CustomerName varchar(max)
		,D_CustomerTradingName varchar(max)
		,D_CustomerAccountClassification varchar(max)
		,D_CustomerCategory varchar(max)
		,D_CustomerSubCategory varchar(max)
		,D_CustomerIndustry varchar(max)
		,D_CustomerRegion varchar(max)
		,D_CustomerType varchar(max)
		,D_CustomerSalesRep varchar(max)
		,D_CustomerLinkCode varchar(max)
		,D_CustomerDeliveryPostcode varchar(max)

		--Product Analysis--
		,D_ProductDivision varchar(max)
		,D_Pre2019ProductDivision varchar(max)
		,D_ProductDepartment varchar(max)
		,D_ProductBuyingDepartment varchar(max)
		,D_Product varchar(max)
		,D_ProductDescription varchar(max)
		,D_ProductCategoryClass varchar(max)
		,D_ProductCategoryGroup varchar(max)
		,D_ProductCategory varchar(max)
		,D_ProductBrand varchar(max)
		,D_ProductRange varchar(max)
		,D_ProductStyle varchar(max)
		,D_ProductStyleDescription varchar(max)
		,D_ProductSeason varchar(max)
		,D_ProductVariety varchar(max)
		,D_ProductGender varchar(max)
		,D_ProductComposition varchar(max)
		,D_ProductDesign varchar(max)
		,D_ProductColour varchar(max)
		,D_ProductSize varchar(max)
		,D_ProductHook varchar(max)
		,D_ProductWidth varchar(max)
		,D_ProductHeight varchar(max)

		,D_ProductWriteDown2015 varchar(max)
		,D_ProductWriteDown2016 varchar(max)
		,D_ProductWriteDown2017 varchar(max)
		,D_ProductWriteDown2018 varchar(max)
		,D_ProductWriteDown2019 varchar(max)

		--Measures--
		,M_Quantity [decimal](15, 6)
		,M_SalesVolume [decimal](15,6)

		,M_NetCostBase [decimal](15, 6)
		,M_NetSellingCostBase [decimal](15,6)
		,M_NetLessDiscountBase [decimal](15, 6)
		,M_MarginAmountBase [decimal](15, 6)
		,M_SellingMarginAmountBase [decimal](15,6)
	)


	INSERT INTO @SalesAnalysis
		SELECT				
			SalesTransactions.TransactionNumber																													D_Number
			,SalesTransactions.TransactionDate																													D_Date
			,CONCAT(DATEPART(yyyy,SalesTransactions.TransactionDate),'-',RIGHT('0' + CAST(DATENAME(WEEK,SalesTransactions.TransactionDate) AS VARCHAR(2)),2))	D_Week
			,DATENAME(MONTH,SalesTransactions.TransactionDate)																									D_MonthName
			,CONCAT(DATEPART(yyyy,SalesTransactions.TransactionDate),'-',DATENAME(MONTH,SalesTransactions.TransactionDate))										D_MonthNameYear
			,DATENAME(MONTH,SalesTransactions.TransactionDate)																									D_Month
			,CONCAT(DATEPART(yyyy,SalesTransactions.TransactionDate),'-',RIGHT('0'+CAST(MONTH(SalesTransactions.TransactionDate) AS VARCHAR(2)),2))				D_MonthYear
			,DATEPART(q,SalesTransactions.TransactionDate)																										D_Quarter
			,CONCAT(DATEPART(yyyy,SalesTransactions.TransactionDate),'Q',DATEPART(q,SalesTransactions.TransactionDate))											D_QuarterYear
			,DATEPART(yyyy,SalesTransactions.TransactionDate)																									D_Year
			,SalesTransactions.TransactionPeriod																												D_Period
			,SalesTransactions.Branch																															D_Branch
			,SalesTransactions.DespatchBranch																													D_DespatchBranch
			,SalesTransactions.TransactionDivision																												D_TransactionDivision
			,SalesTransactions.TransactionSalesRep																												D_TransactionSalesRep
			,SalesTransactions.TransactionType																													D_TransactionType
			,SalesTransactions.LineType																															D_LineType
			,SalesTransactions.CreditNoteLineReason																												D_CreditNoteLineReason

			,CustomerAnalysis.CustomerDivision																													D_CustomerDivision
			,CustomerAnalysis.CustomerCode																														D_Customer
			,CustomerAnalysis.CustomerName																														D_CustomerName
			,CustomerAnalysis.CustomerTradingName																												D_CustomerTradingName		
			,CustomerAnalysis.CustomerAccountClassification																										D_CustomerAccountClassification
			,CustomerAnalysis.CustomerCategory																													D_CustomerCategory
			,CustomerAnalysis.CustomerSubCategory																												D_CustomerSubCategory
			,CustomerAnalysis.CustomerIndustry																													D_CustomerIndustry
			,CustomerAnalysis.CustomerRegion																													D_CustomerRegion
			,CustomerAnalysis.CustomerSalesRep																													D_CustomerSalesRep
			,CustomerAnalysis.CustomerType																														D_CustomerType
			,CustomerAnalysis.CustomerLinkCode																													D_CustomerLinkCode
			,SalesTransactions.DeliveryPostcode																													D_CustomerDeliveryPostcode

			,ProductAnalysis.ProductDivision																													D_ProductDivision
			,ProductAnalysis.Pre2019Division																													D_Pre2019ProductDivision
			,ProductAnalysis.ProductDepartment																													D_ProductDepartment
			,ProductAnalysis.ProductBuyingDepartment																											D_ProductBuyingDepartment

			,ProductAnalysis.ProductCode																														D_Product
			,ProductAnalysis.ProductDescription																													D_ProductDescription
			,ProductAnalysis.ProductCategoryClass																												D_ProductCategoryClass
			,ProductAnalysis.ProductCategoryGroup																												D_ProductCategoryGroup
			,ProductAnalysis.ProductCategory																													D_ProductCategory
			,ProductAnalysis.ProductBrand																														D_ProductBrand
			,ProductAnalysis.ProductRange																														D_ProductRange
			,ProductAnalysis.ProductStyleCode																													D_ProductStyle
			,ProductAnalysis.ProductStyle																														D_ProductStyleDescription
			,ProductAnalysis.ProductSeason																														D_ProductSeason
			,ProductAnalysis.ProductVariety																														D_ProductVariety
			,ProductAnalysis.ProductGender																														D_ProductGender
			,ProductAnalysis.ProductComposition																													D_ProductComposition
			
			,ProductAnalysis.ProductDesignDescription																											D_ProductDesign
			,ProductAnalysis.ProductColourDescription																											D_ProductColour
			,ProductAnalysis.ProductSizeDescription																												D_ProductSize
			,ProductAnalysis.ProductHook																														D_ProductHook
			,ProductAnalysis.ProductWidth																														D_ProductWidth
			,ProductAnalysis.ProductHeight																														D_ProductHeight

			,ProductAnalysis.ProductWriteDown2015																												D_ProductWriteDown2015
			,ProductAnalysis.ProductWriteDown2016																												D_ProductWriteDown2016
			,ProductAnalysis.ProductWriteDown2017																												D_ProductWriteDown2017
			,ProductAnalysis.ProductWriteDown2018																												D_ProductWriteDown2018
			,ProductAnalysis.ProductWriteDown2019																												D_ProductWriteDown2019
			
			,SalesTransactions.Quantity																															M_Quantity
			,SalesTransactions.Quantity * ProductAnalysis.ProductVolume																							M_SalesVolume

			,SalesTransactions.NetCostBase																														M_NetCostBase
			,SalesTransactions.NetSellingCostBase																												M_NetSellingCostBase
			,SalesTransactions.NetLessDiscountBase																												M_NetLessDiscountBase
			,SalesTransactions.MarginAmountBase																													M_MarginAmountBase
			,SalesTransactions.SellingMarginAmountBase																											M_SellingMarginAmountBase
																			
		FROM
		(
			SELECT * FROM fn_GetSalesInvoiceAnalysis() 
		) SalesTransactions

		INNER JOIN T_CUSTOMER							Customer				ON SalesTransactions.CustomerID			= Customer.C_ID		
		INNER JOIN (SELECT * FROM fn_GetCustomerAnalysis()) CustomerAnalysis	ON CustomerAnalysis.CustomerID			= Customer.C_ID

		INNER JOIN T_PRODUCT							Product					ON SalesTransactions.ProductID			= Product.C_ID
		INNER JOIN (SELECT * FROM fn_GetProductAnalysis()) ProductAnalysis		ON ProductAnalysis.ProductID			= Product.C_ID
END

DROP table IF EXISTS Intact_IQ_Behrens_Live_Archive.dbo.DD_SalesInvoiceAnalysisAll

SELECT * INTO Intact_IQ_Behrens_Live_Archive.dbo.DD_SalesInvoiceAnalysisAll FROM (
	SELECT * FROM @SalesAnalysis
) AS nest
ORDER BY D_Number