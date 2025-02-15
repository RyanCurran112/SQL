USE [Intact_IQ_Behrens_Live]
GO
/****** Object:  StoredProcedure [dbo].[RPT_FairtradeReport]    Script Date: 04/03/2021 10:49:43 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Ryan Curran	
-- Create date: 21/11/2019
-- Description:	Report for Fairtrade Lifestyle
-- =============================================
ALTER PROCEDURE [dbo].[RPT_FairtradeReport]
	 @Quarter numeric(1,0)
	,@Year numeric(4,0)
AS
BEGIN
	
	SET NOCOUNT ON;
	SELECT 
		ISNULL(SalesInfo.Quarter,  CONCAT(@Year,'Q',@Quarter))																								[Quarter]
		,'United Kingdom'																																	[Country of Sale]
		,PFT.C_FAIRTRADEPRODUCTCODE																															[Product Code]
		,ISNULL(SalesInfo.UnitsSold, 0)																														[Units Sold]
		,ISNULL(SalesInfo.ValueSold, 0)																														[Value of Sales]
		,PFT.C_FAIRTRADEPRODUCTDESCRIPTION																													[Name & Pack Size]
		,PFT.C_FAIRTRADEINTERNALCODE																														[Internal Code] 
		,'The Behrens Group'																																[Brand Name]
		,PFT.C_CODE																																			[Fairtrade Code]
	FROM 
	T_CT_PRODUCTFAIRTRADEID PFT 
	LEFT JOIN 
	(
		SELECT  
			 CONCAT(DATEPART(yyyy,SalesAnalysis.TransactionDate),'Q',DATEPART(q,SalesAnalysis.TransactionDate))												Quarter																																						
			,PFT.C_FAIRTRADEPRODUCTCODE																														FairtradeProductCode
			,ROUND(SUM(SalesAnalysis.Quantity), 0)																											UnitsSold
			,ROUND(AVG(ProductCostings.ListPrice/CurrencyInfo.ExchangeRate), 2)	* ROUND(SUM(SalesAnalysis.Quantity), 0)										ValueSold
			,PFT.C_FAIRTRADEPRODUCTDESCRIPTION																												FairtradeDescription
			,PFT.C_FAIRTRADEINTERNALCODE																													FairtradeInternalCode																									
			,PFT.C_CODE																																		FairtradeCode
		FROM T_CT_PRODUCTFAIRTRADEID PFT 
			INNER JOIN T_PRODUCT									P				ON PFT.C_ID = P.C_D_FAIRTRADEANALYSIS
			INNER JOIN (SELECT * FROM fn_GetSalesInvoiceAnalysis()) SalesAnalysis	ON SalesAnalysis.ProductID = P.C_ID
			INNER JOIN (SELECT * FROM fn_GetProductCostings())		ProductCostings ON ProductCostings.ProductID = P.C_ID	
			INNER JOIN 
			(
				SELECT
					Currency.C_ID																															Currency
					,AVG(CurrencyDateRangeRates.C_PURCHASELEDGERRATE)																						ExchangeRate
					,COUNT(CurrencyDateRangeRates.C_PURCHASELEDGERRATE)																						CountRates
					,CONCAT(DATEPART(yyyy,CurrencyDateRangeRates.C_STARTDATE),'Q',DATEPART(q,CurrencyDateRangeRates.C_STARTDATE))							[Quarter]
					,Currency.C_CODE																														[CurrencyCode]
				FROM T_CURRENCY Currency 
					LEFT JOIN T_CURRENCY_DATERANGERATES CurrencyDateRangeRates ON CurrencyDateRangeRates.C__OWNER_ = Currency.C_ID
				WHERE CurrencyDateRangeRates.C_STARTDATE >= DATEADD(qq, DATEDIFF(qq, 0, CurrencyDateRangeRates.C_STARTDATE), 0)
					AND CurrencyDateRangeRates.C_ENDDATE <= DATEADD(dd, -1, DATEADD(qq, DATEDIFF(qq, 0, CurrencyDateRangeRates.C_ENDDATE) + 1, 0))
					AND CurrencyDateRangeRates.C_PURCHASELEDGERRATE > 0
				GROUP BY 
					 Currency.C_ID
					,Currency.C_CODE
					,CONCAT(DATEPART(yyyy,CurrencyDateRangeRates.C_STARTDATE),'Q',DATEPART(q,CurrencyDateRangeRates.C_STARTDATE))
			) CurrencyInfo ON CurrencyInfo.Currency = ProductCostings.ListPriceCurrency AND CurrencyInfo.Quarter = CONCAT(DATEPART(yyyy,SalesAnalysis.TransactionDate),'Q',DATEPART(q,SalesAnalysis.TransactionDate))		
			WHERE SalesAnalysis.TransactionDivision = 'D&D' 
				AND DATEPART(q,SalesAnalysis.TransactionDate) = @Quarter 
				AND DATEPART(yyyy,SalesAnalysis.TransactionDate) = @Year
		GROUP BY 
			 CONCAT(DATEPART(yyyy,SalesAnalysis.TransactionDate),'Q',DATEPART(q,SalesAnalysis.TransactionDate))	
			,DATEPART(yyyy,SalesAnalysis.TransactionDate)	
			,PFT.C_FAIRTRADEPRODUCTCODE
			,PFT.C_FAIRTRADEINTERNALCODE
			,PFT.C_FAIRTRADEPRODUCTDESCRIPTION
			,PFT.C_CODE
	) SalesInfo ON SalesInfo.FairtradeCode = PFT.C_CODE
	ORDER BY 
		PFT.C_CODE
END
