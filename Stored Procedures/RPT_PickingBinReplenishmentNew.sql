USE [Intact_IQ_Behrens_Live]
GO
/****** Object:  StoredProcedure [dbo].[RPT_PickingBinReplenishmentNew]    Script Date: 04/03/2021 10:51:10 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:				Ryan Curran
-- Date:				Date (MM/YY)
-- Description:   		Stored Procedure to create a picking bin replenishment report based on location.
-- Parameters:     		Location
-- =============================================
ALTER PROCEDURE [dbo].[RPT_PickingBinReplenishmentNew]	
	@LocationCode nvarchar(max)
AS
BEGIN
	SET NOCOUNT ON;

	SELECT 
		 A.ProductCode																				Product
		,A.PickFaceMaxStockLevel - A.PickFaceStockLevel												RequiredStock
		,PSBS.C_PRODUCTBATCH																		ProductBatchID
		,PB.C_NUMBER																				ProductBatchNumber
		,PB.C_CREATIONDATE																			ProductBatchCreationDate
		,PSBS.C_STOCKBIN																			FromStockBinID
		,SB.C_CODE																					FromStockBinCode
		,CASE	
			WHEN PSBS.C_PRODUCTBATCH != NULL THEN dbo.fn_GetProductBatchStockBinLevel(PSBS.C_STOCKBIN, PSBS.C_PRODUCTBATCH, A.ProductID)	
			ELSE dbo.fn_GetProductStockBinLevel(PSBS.C_STOCKBIN, A.ProductID)	
		END																							FromStockBinLevel
		,A.PickFaceStockBinID																		ToStockBinID
		,A.PickFaceStockBinCode																		ToStockBinCode
		,''																							Quantity
		,UOMC.C_CONVERSIONFACTOR																	BoxQuantity
		,A.OverflowStockBinID																		OverflowStockBinID
		,A.OverflowStockBinCode																		OverflowStockBinCode
	FROM (
		SELECT 
			 P.C_ID																					ProductID
			,P.C_CODE																				ProductCode
			,PFSB.C_ID																				PickFaceStockBinID
			,PFSB.C_CODE																			PickFaceStockBinCode
			,PBI.C_PICKFACEMINIMUMSTOCKLEVEL														PickFaceMinStockLevel
			,PBI.C_PICKFACEMAXIMUMSTOCKLEVEL														PickFaceMaxStockLevel
			,CASE WHEN dbo.fn_GetProductStockBinLevel(PBI.C_PICKFACESTOCKBIN, P.C_ID) IS NULL THEN 0
				ELSE dbo.fn_GetProductStockBinLevel(PBI.C_PICKFACESTOCKBIN, P.C_ID)			
			 END																					PickFaceStockLevel
			,OFSB.C_ID																				OverflowStockBinID
			,OFSB.C_CODE																			OverflowStockBinCode
		FROM T_PRODUCT P
		INNER JOIN T_PRODUCT_BRANCHINFO PBI ON PBI.C__OWNER_ = P.C_ID
		INNER JOIN T_BRANCH B				ON PBI.C_BRANCH = B.C_ID
		LEFT JOIN T_STOCKBIN PFSB			ON PFSB.C_ID = PBI.C_PICKFACESTOCKBIN
		LEFT JOIN T_STOCKLOCATION SBSL		ON PFSB.C_LOCATION = SBSL.C_ID
		LEFT JOIN T_STOCKBIN OFSB			ON PBI.C_OVERFLOWSTOCKBIN = OFSB.C_ID
		WHERE B.C_CODE = 'HQ' AND PBI.C_PICKFACESTOCKBIN IS NOT NULL AND SBSL.C_CODE = @LocationCode
		) A
	INNER JOIN T_PRODUCTSTOCKBINSTATISTICS PSBS ON PSBS.C_PRODUCT = A.ProductID
	LEFT JOIN T_PRODUCTBATCH PB ON PSBS.C_PRODUCTBATCH = PB.C_ID
	LEFT JOIN T_STOCKBIN SB ON PSBS.C_STOCKBIN	= SB.C_ID
	LEFT JOIN T_STOCKLOCATION SBL ON SB.C_LOCATION = SBL.C_ID
	LEFT JOIN T_PRODUCT_ALTERNATESTOCKINGUNITOFMEASURECONVERSION PASC ON A.ProductID = PASC.C__OWNER_
	LEFT JOIN T_UNITOFMEASURECONVERSION UOMC ON PASC.C_ID = UOMC.C_ID
	LEFT JOIN T_UNITOFMEASURE UOM ON UOMC.C_UNITOFMEASURE = UOM.C_ID	

	WHERE (A.PickFaceStockLevel <= A.PickFaceMinStockLevel OR A.PickFaceStockLevel IS NULL) 
		AND PSBS.C_STOCKLEVEL > 0 
		AND SB.C_STOCKBINTYPE = 0
		AND SB.C_ID != A.PickFaceStockBinID
		AND UOM.C_ID = 21539261002189
		/*The query returns all the products where the Pick Face Stock*/
	ORDER BY A.PickFaceStockBinCode, PB.C_CREATIONDATE, SB.C_SORTINDEX ASC
END
