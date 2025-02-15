USE [Intact_IQ_Behrens_Live]
GO
/****** Object:  StoredProcedure [dbo].[RPT_PickingBinReplenishment]    Script Date: 04/03/2021 10:51:25 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:				Ryan Curran
-- Date:				Date (MM/YY)
-- Description:   		Stored Procedure to create a picking bin replenishment Report.
-- Parameters:     		N/A
-- =============================================
ALTER PROCEDURE [dbo].[RPT_PickingBinReplenishment]
AS
BEGIN
	SET NOCOUNT ON;

	SELECT 
		 ''																[Number]
		,'RCURRAN'														[CreatedBy]
		,ProductCode													[Items.Product]
		,OverflowBin													[Items.FromStockBin]
		,PickBin														[Items.ToStockBin]
		,TransferQty													[Items.Quantity]
	FROM (
		SELECT 
			 PickBinLevel.ProductCode											[ProductCode]
			,PickBinLevel.PickBinCode											[PickBin]
			,PickBinLevel.PickBinStockLevel										[PickBinCurrentStockLevel]
			,PickBinLevel.OverflowCode											[OverflowBin]
			,PSBS.C_STOCKLEVEL													[OverflowStockLevel]
			,CASE 
				WHEN (PickBinLevel.PickBinMaxStockLevel - PickBinLevel.PickBinStockLevel) > PSBS.C_STOCKLEVEL	THEN PSBS.C_STOCKLEVEL
				WHEN PickBinLevel.PickBinStockLevel > PickBinMaxStockLevel										THEN 0
				ELSE PickBinLevel.PickBinMaxStockLevel - PickBinLevel.PickBinStockLevel
			END [TransferQty]
		FROM 
					(
					SELECT
						P.C_ID								[ProductID]
						,P.C_CODE							[ProductCode]
						,SB.C_CODE							[PickBinCode]
						,OFB.C_CODE							[OverflowCode]
						,PSBS.C_STOCKLEVEL					[PickBinStockLevel]
						,PBI.C_PICKFACEMINIMUMSTOCKLEVEL	[PickBinMinStockLevel]
						,PBI.C_PICKFACEMAXIMUMSTOCKLEVEL	[PickBinMaxStockLevel]
					FROM Intact_IQ_Behrens_Live.dbo.T_PRODUCT P
					INNER JOIN Intact_IQ_Behrens_Live.dbo.T_CT_DIVISION					(nolock) D		ON D.C_ID = P.C_D_PRODUCTDIVISION
					INNER JOIN Intact_IQ_Behrens_Live.dbo.T_PRODUCT_STATISTICS			(nolock) PS		ON P.C_STATISTICS = PS.C_ID
					INNER JOIN Intact_IQ_Behrens_Live.dbo.T_PRODUCT_BRANCHINFO			(nolock) PBI	ON PBI.C__OWNER_ = P.C_ID
					INNER JOIN Intact_IQ_Behrens_Live.dbo.T_BRANCH						(nolock) B		ON B.C_ID = PBI.C_BRANCH
					INNER JOIN Intact_IQ_Behrens_Live.dbo.T_STOCKBIN					(nolock) SB		ON SB.C_ID = PBI.C_PICKFACESTOCKBIN
					INNER JOIN Intact_IQ_Behrens_Live.dbo.T_STOCKBIN					(nolock) OFB	ON OFB.C_ID = PBI.C_OVERFLOWSTOCKBIN
					INNER JOIN Intact_IQ_Behrens_Live.dbo.T_PRODUCTSTOCKBINSTATISTICS	(nolock) PSBS	ON PSBS.C_STOCKBIN = PBI.C_PICKFACESTOCKBIN AND P.C_ID = PSBS.C_PRODUCT
					WHERE ( P.C_STOCKINGSTATUS = 0 -- Stocked
						OR (P.C_STOCKINGSTATUS = 2 AND PS.C_STOCKLEVEL > 0) --Superseded
						OR (P.C_STOCKINGSTATUS = 4 AND PS.C_STOCKLEVEL > 0) --Discontinued After Stock is Sold
						)  --Stocked
						AND C_TYPE != 21 --Index
						AND C_TYPE != 1 --Open
						AND C_TYPE != 2 --Service
						AND P.C_WORKFLOWSTATUS != 21560735854731 -- Inactive
						AND D.C_CODE = 'D&D'
						AND PSBS.C_STOCKLEVEL <= PBI.C_PICKFACEMINIMUMSTOCKLEVEL
					) AS PickBinLevel
		LEFT JOIN Intact_IQ_Behrens_Live.dbo.T_PRODUCTSTOCKBINSTATISTICS	(nolock) PSBS	ON PSBS.C_PRODUCT = PickBinLevel.ProductID
		INNER JOIN Intact_IQ_Behrens_Live.dbo.T_STOCKBIN					(nolock) SB		ON SB.C_ID = PSBS.C_STOCKBIN
		INNER JOIN Intact_IQ_Behrens_Live.dbo.T_STOCKLOCATION				(nolock) SL		ON SB.C_LOCATION = SL.C_ID
		WHERE SB.C_CODE = OverflowCode
		) Test
	WHERE Test.TransferQty > 0
	ORDER BY ProductCode

END
