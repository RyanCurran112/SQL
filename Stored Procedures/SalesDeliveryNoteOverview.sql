USE [Intact_IQ_Behrens_Live]
GO
/****** Object:  StoredProcedure [dbo].[CD_SalesDeliveryNoteOverview]    Script Date: 04/03/2021 10:44:07 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Ryan Curran
-- Create date: 02/04/2020
-- Description:	A stored procedure to show overview of sales deliveries on a control desk/dashboard
-- =============================================
ALTER PROCEDURE [dbo].[CD_SalesDeliveryNoteOverview]
	@StartDate datetime
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    SELECT 
		 CASE GROUPING(D.C_CODE) WHEN 1 THEN 'Total' ELSE D.C_CODE END													[Division]
		,ISNULL(SUM(Source.SDNCount),0)																					[SDNCount]
		,ISNULL(SUM(Source.SDNItemCount),0)																				[SDNItemCount]
		,ISNULL(SUM(Source.SDNItemSum),0)																				[SDNItemSum]
	FROM dbo.fn_GetActiveDivisions() D
	LEFT JOIN(
			SELECT
				 SDN.Division																							[Division]
				,CAST(COUNT(DISTINCT SDN.DeliveryNoteID) as int)														[SDNCount]
				,CAST(COUNT(SDN.DeliveryNoteID) * 100.0		/ SUM(COUNT(SDN.DeliveryNoteID)) OVER () as int)			[SDNCountPercentage]	
				,CAST(COUNT(SDN.DeliveryNoteLineID) as int)																[SDNItemCount]
				,CAST(COUNT(SDN.DeliveryNoteLineID) * 100.0 / SUM(COUNT(SDN.DeliveryNoteLineID)) OVER () as int)		[SDNItemCountPercentage]	
				,CAST(SUM(QuantityInStockingUnits) as int)																[SDNItemSum]
				,CAST(SUM(QuantityInStockingUnits) * 100.0	/ SUM(SUM(QuantityInStockingUnits)) OVER () as int)			[SDNItemSumPercentage]
			FROM (SELECT * FROM fn_GetSalesDeliveryNoteAnalysis())	SDN 
			INNER JOIN (SELECT * FROM fn_GetProductAnalysis())		PA ON SDN.ProductID = PA.ProductID
			INNER JOIN (SELECT * FROM fn_GetCustomerAnalysis())		CA ON SDN.CustomerID = CA.CustomerID
			WHERE SDN.Date >= @StartDate
				AND PA.ProductType <> 'Bundle'
			GROUP BY SDN.Division
		) Source ON Source.Division = D.C_CODE
	GROUP BY ROLLUP(D.C_CODE)
	ORDER BY Division
END
