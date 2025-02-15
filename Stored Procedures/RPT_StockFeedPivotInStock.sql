USE [Intact_IQ_Behrens_Live]
GO
/****** Object:  StoredProcedure [dbo].[RPT_StockFeedPivotInStock]    Script Date: 04/03/2021 10:52:27 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:				Ryan Curran & TL
-- Date:				July 2019
-- Description:   		Stored Procedure to show a Stock Due Report for either a customer, division, product range etc. This takes into account Sales Orders,
--						purchase orders, shipping lists & works orders and expected lead times.
-- Parameters:     		Division Code, Customer Account Code, Product Category Group, Product Category, Product Brand, Product Range, Product Style, Product, Include Customer Year Sales (Yes/No)
-- =============================================

ALTER PROCEDURE [dbo].[RPT_StockFeedPivotInStock]
	-- Add the parameters for the stored procedure here
	 @CustomerCode nvarchar(80) = ''
	,@CategoryGroup varchar(80) = ''
	,@Category varchar(80) = ''
	,@Range nvarchar(80) = ''
	,@StockFeed nvarchar(80) = ''
	,@Style nvarchar(80) = ''
	,@Brand nvarchar(80) = ''
	,@DivisionCode nvarchar(80) = ''
	,@ProductCode nvarchar(80) = ''
	,@IncludeCustomerYearSales nvarchar(1) = 'F'
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
			--Number of Days Between Breaks
			 @break1 int = 14
			,@break2 int = 30
			,@break3 int = 90
			,@break4 int = 120
			--Number of Years to include when @IncludeCustomerYearSales = 'T'
			,@IncludedNumberOfYears int = 2

	DECLARE @ProductList table(
			C_PRODUCTID bigint INDEX IX1 CLUSTERED
	)

	DECLARE @CustomerSalesPerYear table(
			 C_PRODUCT bigint INDEX IX1 CLUSTERED
			,C_YEAR smallint
			,C_QUANTITY numeric (18,5)
	)

	-- START Populate Product List =======================================================================================================

	IF @CustomerCode != ''
	BEGIN
		DECLARE @CustomerID bigint = (SELECT C_ID FROM T_CUSTOMER WHERE C_CODE = @CustomerCode) 

		--Rule here is if its on the list include it, unless its a index owner in which case only include if the child is stocked and active
		INSERT INTO @ProductList
			SELECT 
				DISTINCT isnull(IDXPC.C_ID,P.C_ID)
			FROM T_CUSTOMER_FAVOURITEPRODUCTITEM	CFPI
				LEFT JOIN T_PRODUCT					P		ON CFPI.C_PRODUCT = P.C_ID
				LEFT JOIN T_PRODUCT					IDXPC	ON P.C_ID = IDXPC.C_INDEXPRODUCTOWNER 
															AND IDXPC.C_STOCKINGSTATUS = 0					--Stocking Status = Stocked Only
															AND IDXPC.C_WORKFLOWSTATUS != 21560735854731	--Workflow Status Not Inactive
			WHERE CFPI.C__OWNER_ = @CustomerID 

		IF @IncludeCustomerYearSales = 'T'
		BEGIN
				INSERT INTO @CustomerSalesPerYear
				SELECT 
						SIL.C_PRODUCT
					,year(SI.C_DATE)
					,sum(SIL.C_QUANTITY * C_STOCKINGUNITCONVERSIONFACTOR)
				FROM T_SALESINVOICE_LINE		SIL
					LEFT JOIN T_SALESINVOICE	SI ON SIL.C__OWNER_ = SI.C_ID
				WHERE SI.C_CUSTOMER = @CustomerID
				GROUP BY SIL.C_PRODUCT, year(SI.C_DATE)
				HAVING year(SI.C_DATE) BETWEEN year(GETDATE())-(@IncludedNumberOfYears - 1) and year(GETDATE()) --Only show three years

				INSERT INTO @CustomerSalesPerYear
				SELECT 
						C_PRODUCTID
					,NULL
					,0
				FROM @ProductList
		END
	END

	IF @CategoryGroup != ''
	BEGIN
		--Rule here is must be a stocked product, active and must not be an index product owner or an open or service.
		INSERT INTO @ProductList
			SELECT 
				P.C_ID 
			FROM T_PRODUCT						P
				LEFT JOIN T_PRODUCT_STATISTICS	PS ON P.C_STATISTICS = PS.C_ID
				LEFT JOIN T_PRODUCTCATEGORY		PC ON P.C_CATEGORY = PC.C_ID
			WHERE C_GROUP = (SELECT C_ID FROM T_PRODUCTCATEGORYGROUP WHERE C_CODE = @CategoryGroup) 
				AND (
							C_STOCKINGSTATUS = 0							-- Stocked
						OR (C_STOCKINGSTATUS = 2 AND PS.C_STOCKLEVEL > 0)	-- Superseded
				)															-- Stocked
				AND P.C_TYPE != 21											-- Index
				AND P.C_TYPE != 1											-- Open
				AND P.C_TYPE != 2											-- Service
				AND P.C_WORKFLOWSTATUS != 21560735854731					-- Inactive
				AND P.C_D_CUSTOMEROWNER IS NULL								-- Must be a non bespoke product
	END

	IF @Category != ''
	BEGIN
		--Rule here is must be a stocked product, active and must not be an index product owner or an open or service.
		INSERT INTO @ProductList
			SELECT 
				P.C_ID 
			FROM T_PRODUCT						P
				LEFT JOIN T_PRODUCT_STATISTICS	PS ON P.C_STATISTICS = PS.C_ID
			WHERE C_CATEGORY = (SELECT C_ID FROM T_PRODUCTCATEGORY WHERE C_CODE = @Category) 
				AND (
							C_STOCKINGSTATUS = 0							-- Stocked
						OR (C_STOCKINGSTATUS = 2 AND PS.C_STOCKLEVEL > 0)	-- Superseded
				)															-- Stocked
				AND P.C_TYPE != 21											-- Index
				AND P.C_TYPE != 1											-- Open
				AND P.C_TYPE != 2											-- Service
				AND P.C_WORKFLOWSTATUS != 21560735854731					-- Inactive
				AND P.C_D_CUSTOMEROWNER IS NULL								-- Must be a non bespoke product
	END

	IF @Brand != ''
	BEGIN
		--Rule here is must be a stocked product, active and must not be an index product owner or an open or service.
		INSERT INTO @ProductList
			SELECT 
				P.C_ID 
			FROM T_PRODUCT						P
				LEFT JOIN T_PRODUCT_STATISTICS	PS ON P.C_STATISTICS = PS.C_ID
			WHERE C_BRAND = (SELECT C_ID FROM T_BRAND WHERE C_CODE = @Brand) 
				AND (
							C_STOCKINGSTATUS = 0							-- Stocked
						OR (C_STOCKINGSTATUS = 2 AND PS.C_STOCKLEVEL > 0)	-- Superseded
				)															-- Stocked
				AND C_TYPE != 21											-- Index
				AND C_TYPE != 1												-- Open
				AND C_TYPE != 2												-- Service
				AND P.C_WORKFLOWSTATUS != 21560735854731					-- Inactive
				AND P.C_D_CUSTOMEROWNER IS NULL								-- Must be a non bespoke product
	END

	IF @Range != ''
	BEGIN
		--Rule here is must be a stocked product, active and must not be an index product owner or an open or service.
		INSERT INTO @ProductList
			SELECT 
				P.C_ID 
			FROM T_PRODUCT						P
				LEFT JOIN T_PRODUCT_STATISTICS	PS ON P.C_STATISTICS = PS.C_ID
			WHERE C_RANGE = (SELECT C_ID FROM T_PRODUCTRANGE WHERE C_CODE = @Range) 
				AND (
							C_STOCKINGSTATUS = 0 -- Stocked
						OR (C_STOCKINGSTATUS = 2 AND PS.C_STOCKLEVEL > 0)	-- Superseded
						OR (C_STOCKINGSTATUS = 4 AND PS.C_STOCKLEVEL > 0)	-- Discontinued After Stock is Sold
				)															-- Stocked
				AND C_TYPE != 21											-- Index
				AND C_TYPE != 1												-- Open
				AND C_TYPE != 2												-- Service
				AND P.C_WORKFLOWSTATUS != 21560735854731					-- Inactive
				AND P.C_D_CUSTOMEROWNER IS NULL								-- Must be a non bespoke product
	END

	IF @StockFeed != ''
	BEGIN
		--Rule here is must be a stocked product, active and must not be an index product owner or an open or service.
		INSERT INTO @ProductList
			SELECT 
				P.C_ID 
			FROM T_PRODUCT						P
				INNER JOIN T_CT_PRODUCTSTYLE PSt ON P.C_D_STYLE = PSt.C_ID
				INNER JOIN T_CT_STOCKREPORTLISTS SFL ON PSt.C_ID = SFL.C_PRODUCTSTYLE
				LEFT JOIN T_PRODUCT_STATISTICS	PS ON P.C_STATISTICS = PS.C_ID
				
			WHERE SFL.C_STOCKREPORT = (SELECT C_ID FROM T_CT_STOCKREPORTS WHERE C_CODE = @StockFeed) 
				AND (
							C_STOCKINGSTATUS = 0							-- Stocked
						OR (C_STOCKINGSTATUS = 2 AND PS.C_STOCKLEVEL > 0)	-- Superseded
				)															-- Stocked
				AND C_TYPE != 21											-- Index
				AND C_TYPE != 1												-- Open
				AND C_TYPE != 2												-- Service
				AND P.C_WORKFLOWSTATUS != 21560735854731					-- Inactive
				AND P.C_D_CUSTOMEROWNER IS NULL								-- Must be a non bespoke product
	END

	IF @Style != ''
	BEGIN
		--Rule here is must be a stocked product, active and must not be an index product owner or an open or service.
		INSERT INTO @ProductList
			SELECT 
				P.C_ID 
			FROM T_PRODUCT						P
				LEFT JOIN T_PRODUCT_STATISTICS	PS ON P.C_STATISTICS = PS.C_ID
			WHERE C_D_STYLE = (SELECT C_ID FROM T_CT_PRODUCTSTYLE WHERE C_CODE = @Style) 
				AND (
							C_STOCKINGSTATUS = 0							-- Stocked
						OR (C_STOCKINGSTATUS = 2 AND PS.C_STOCKLEVEL > 0)	-- Superseded
						OR (C_STOCKINGSTATUS = 4 AND PS.C_STOCKLEVEL > 0)	-- Discontinued After Stock is Sold
				)															-- Stocked
				AND C_TYPE != 21											-- Index
				AND C_TYPE != 1												-- Open
				AND C_TYPE != 2												-- Service
				AND P.C_WORKFLOWSTATUS != 21560735854731					-- Inactive
				AND P.C_D_CUSTOMEROWNER IS NULL								-- Must be a non bespoke product
	END

	IF @DivisionCode != '' and @DivisionCode !='TDV'
	BEGIN
		--Rule here is must be a stocked product, active and must not be an index product owner or an open or service.
		INSERT INTO @ProductList
			SELECT 
				P.C_ID 
			FROM T_PRODUCT					P
			LEFT JOIN T_PRODUCT_STATISTICS	PS ON P.C_STATISTICS = PS.C_ID
			WHERE C_D_PRODUCTDIVISION = (SELECT C_ID FROM T_CT_DIVISION WHERE C_CODE = @DivisionCode) 
				AND (
							C_STOCKINGSTATUS = 0							-- Stocked
						OR (C_STOCKINGSTATUS = 2 AND PS.C_STOCKLEVEL > 0)	-- Superseded
						OR (C_STOCKINGSTATUS = 4 AND PS.C_STOCKLEVEL > 0)	-- Discontinued After Stock is Sold
				)															-- Stocked
				AND C_TYPE != 21											-- Index
				AND C_TYPE != 1												-- Open
				AND C_TYPE != 2												-- Service
				AND P.C_WORKFLOWSTATUS != 21560735854731					-- Inactive
				AND P.C_D_CUSTOMEROWNER IS NULL								-- Must be a non bespoke product
	END

	IF @DivisionCode = 'TDV'
	BEGIN
		--Rule here is must be a stocked product, active and must not be an index product owner or an open or service.
		INSERT INTO @ProductList
			SELECT 
				P.C_ID 
			FROM T_PRODUCT										P
			LEFT JOIN T_PRODUCT_STATISTICS						PS ON P.C_STATISTICS = PS.C_ID
			LEFT JOIN (SELECT * FROM fn_GetProductAnalysis())	ProductAnalysis ON ProductAnalysis.ProductID = P.C_ID
			WHERE (C_D_PRODUCTDIVISION = (SELECT C_ID FROM T_CT_DIVISION WHERE C_CODE = @DivisionCode) or C_D_PRODUCTDIVISION = 39232911374255618)
				AND (
							C_STOCKINGSTATUS = 0							-- Stocked
						OR (C_STOCKINGSTATUS = 2 AND PS.C_STOCKLEVEL > 0)	-- Superseded
						OR (C_STOCKINGSTATUS = 4 AND PS.C_STOCKLEVEL > 0)	-- Discontinued After Stock is Sold
				)															-- Stocked
				AND C_TYPE != 21											-- Index
				AND C_TYPE != 1												-- Open
				AND C_TYPE != 2												-- Service
				AND P.C_WORKFLOWSTATUS != 21560735854731					-- Inactive
				AND P.C_D_CUSTOMEROWNER IS NULL								-- Must be a non bespoke product
				AND ProductAnalysis.ProductCategoryGroup != 'Workwear Clothing & Accessories' 
				AND ProductAnalysis.ProductCategoryGroup != 'Workwear Scrub Clothing' -- Must not be within the Workwear Categories
	END

	IF @ProductCode != ''
	BEGIN
		INSERT INTO @productlist
			SELECT 
				C_ID 
			FROM T_PRODUCT 
			WHERE C_CODE = @ProductCode
	END

	-- END Populate Product List =======================================================================================================


	DECLARE @OutstandingSalesOrders table(
			 C_PRODUCT bigint INDEX IX1 CLUSTERED
			,C_QUANTITY numeric(18,5)
	)

	INSERT INTO @OutstandingSalesOrders
		SELECT
			 C_PRODUCT
			,sum(C_STOCKINGUNITCONVERSIONFACTOR * C_QUANTITYOUTSTANDING) C_QUANTITY
		FROM T_SALESORDER_LINE		SOL
		LEFT JOIN T_SALESORDER		SO	ON SOL.C__OWNER_ = SO.C_ID
		LEFT JOIN T_SALESORDERTYPE	SOT	ON SO.C_ORDERTYPE = SOT.C_ID
		WHERE C_PRODUCT IN (SELECT C_PRODUCTID FROM @ProductList) 
			AND (C_CALLOFFLINETYPE = 0 OR C_CALLOFFLINETYPE = 2) 
			AND SO.C_ORDERTYPE != 9247068578543								-- Works Order Issue
			AND SOT.C_DEFAULTORDERFULFILLMENTMETHOD != 1					-- Ignore Direct Sales Orders
		GROUP BY C_PRODUCT

	DECLARE @OutstandingWorksOrderRequirements table(
		 C_PRODUCT bigint INDEX IX1 CLUSTERED
		,C_QUANTITY numeric(18,5)
	)

	INSERT INTO @OutstandingWorksOrderRequirements
		SELECT
			 WOL.C_PRODUCT
			,sum(WOL.C_QUANTITYOUTSTANDING) 
		FROM T_IS_WORKSORDER_LINE	WOL 
		JOIN T_IS_WORKSORDER		WO ON WOL.C__OWNER_ = WO.C_ID 
		WHERE WOL.C_PRODUCT IN (SELECT C_PRODUCTID FROM @ProductList) 
			AND (WO.C_STATUS = 0 OR WO.C_STATUS = 5)
		GROUP BY WOL.C_PRODUCT

	DECLARE @EffectiveStock table(
		 C_PRODUCT bigint INDEX IX1 CLUSTERED
		,C_QUANTITY numeric(18,5)
	)

	INSERT INTO @EffectiveStock
		SELECT
			 P.C_ID
			,PSTAT.C_STOCKLEVEL
		FROM T_PRODUCT					P
		LEFT JOIN T_PRODUCT_STATISTICS	PSTAT ON P.C_STATISTICS = PSTAT.C_ID
		WHERE P.C_ID IN (SELECT C_PRODUCTID FROM @ProductList)

	UPDATE EffectiveStock
	SET C_QUANTITY = EffectiveStock.C_QUANTITY - isnull(OutstandingSalesOrders.C_QUANTITY,0) - isnull(OutstandingWorksOrderRequirements.C_QUANTITY,0)
	FROM @EffectiveStock EffectiveStock
	LEFT JOIN @OutstandingSalesOrders				OutstandingSalesOrders			  ON OutstandingSalesOrders.C_PRODUCT = EffectiveStock.C_PRODUCT
	LEFT JOIN @OutstandingWorksOrderRequirements	OutstandingWorksOrderRequirements ON OutstandingWorksOrderRequirements.C_PRODUCT = EffectiveStock.C_PRODUCT

	declare @StockIn table(
		    C_PRODUCT bigint
		   ,C_DATETIME Datetime INDEX IX1 CLUSTERED
		   ,C_QUANTITY numeric(18,5)
		   ,C_TOTALQUANTITY numeric(18,5)
	)

	INSERT INTO @StockIn
		-- Purchase Orders
		SELECT 
			 C_PRODUCT
			,POL.C_DUEDATE
			,(C_QUANTITYOUTSTANDING - C_QUANTITYSHIPPED) * C_STOCKINGUNITCONVERSIONFACTOR
			,0
		FROM T_PURCHASEORDER_LINE			POL
			LEFT JOIN T_PURCHASEORDER		PO	ON POL.C__OWNER_ = PO.C_ID
			LEFT JOIN T_PURCHASEORDERTYPE	POT	ON PO.C_ORDERTYPE = POT.C_ID
		WHERE C_PRODUCT IN (SELECT C_PRODUCTID FROM @ProductList) 
			AND C_QUANTITYOUTSTANDING - C_QUANTITYSHIPPED > 0 
			AND POL.C_DUEDATE IS NOT NULL 
			AND POL.C_DUEDATE > DATEADD(day, DATEDIFF(day, 0, GETDATE()), 0)
			AND POT.C_DEFAULTORDERFULFILLMENTMETHOD != 1						-- Ignore Direct Purchase Orders

		union all

		-- Shipping Lists
		SELECT
			 SLI.C_PRODUCT
			,SL.C_D_ETABEHRENS
			,SLI.C_QUANTITYSHIPPED * SLI.C_STOCKINGUNITCONVERSIONFACTOR
			,0
		FROM T_IS_SHIPPINGLIST_ITEM			SLI
			LEFT JOIN T_IS_SHIPPINGLIST		SL ON SLI.C__OWNER_ = SL.C_ID
			LEFT JOIN T_PURCHASEORDER_LINE	POL ON SLI.C_ORDERLINE = POL.C_ID
			LEFT JOIN T_PURCHASEORDER		PO ON POL.C__OWNER_ = PO.C_ID
			LEFT JOIN T_PURCHASEORDERTYPE	POT ON PO.C_ORDERTYPE = POT.C_ID
		WHERE SLI.C_PRODUCT IN (SELECT C_PRODUCTID FROM @ProductList) 
			AND SL.C_STATUS = 0 
			AND SL.C_D_ETABEHRENS IS NOT NULL 
			AND SL.C_D_ETABEHRENS > DATEADD(day, DATEDIFF(day, 0, GETDATE()), 0)
			AND POT.C_DEFAULTORDERFULFILLMENTMETHOD != 1						-- Ignore Direct Purchase Orders

		union all

		-- Works Orders
		SELECT 
			 C_PRODUCT
			,WO.C_DUEDATE
			,WO.C_QUANTITYOUTSTANDING
			,0
		FROM T_IS_WORKSORDER	WO 
		WHERE (WO.C_STATUS = 0 or WO.C_STATUS = 5)
			AND WO.C_PRODUCT IN (SELECT C_PRODUCTID FROM @ProductList) 
			AND WO.C_DUEDATE IS NOT NULL 
			AND WO.C_DUEDATE > DATEADD(day, DATEDIFF(day, 0, GETDATE()), 0)

-- Stock Feed=================================================================================================================================================================================

	SELECT 
		 unpvt.ProductCode [Product Code]
		,unpvt.ProductDescription [Product Description]
		,isnull(unpvt.CategoryCode,'') [CategoryCode]
		,isnull(unpvt.CategoryDescription, 'Other') [Category]
		,isnull(unpvt.ProductBrand, 'N/A') [Brand]
		,isnull(unpvt.ProductRange, 'N/A') [Range]
		,isnull(unpvt.Style, 'N/A') [Style]
		,isnull(unpvt.IndexProductOwnerCode, 'N/A') [Product Group Code]
		,isnull(unpvt.IndexProductOwnerDescripion, 'N/A') [Product Group]
		,isnull(unpvt.Colour, 'N/A') [Colour]
		,isnull(unpvt.SecondaryColour, 'N/A') [Secondary Colour]
		,isnull(unpvt.TrimColour, 'N/A') [Trim Colour]
		,concat(unpvt.Colour,	CASE 
									WHEN unpvt.SecondaryColour IS NULL THEN '' 
									ELSE CONCAT('/', unpvt.SecondaryColour) 
								END, 
								CASE 
									WHEN unpvt.TrimColour IS NULL THEN '' 
									ELSE CONCAT('/', unpvt.TrimColour, ' Trim') 
								END) [ColourDescription]
		,concat(format(isnull(unpvt.SizeDisplayOrder, 0),'0000'),'#',isnull(unpvt.SizeCode, 'N/A')) [Size]
		,isnull(unpvt.VarietyDescription, ' ') [Variety]
		,isnull(unpvt.SizeDisplayOrder, 0) [Display Order]
		,isnull(unpvt.LegLength, ' ') [Leg]
		,isnull(unpvt.StyleStockFeedCode, ' ') [StyleStockFeedCode]
		,CASE
			WHEN BreakNumber = 'Break0' AND SalesYear IS NULL THEN 'Current Stock'
			WHEN BreakNumber = 'Break0' AND SalesYear IS NOT NULL THEN concat(SalesYear, ' Sales')
			WHEN BreakNumber = 'Break1' THEN concat('Due Within ', @break1, ' Days')
			WHEN BreakNumber = 'Break2' THEN concat('Due Within ', @break2, ' Days')
			WHEN BreakNumber = 'Break3' THEN concat('Due Within ', @break3, ' Days')
			WHEN BreakNumber = 'Break4' THEN concat('Due Within ', @break4, ' Days')
		 END [Stock Status]
	    ,Quantity [Quantity]
	FROM(
		SELECT 
			 P.C_CODE [ProductCode]
			,P.C_DESCRIPTION [ProductDescription]
			,PCAT.C_CODE [CategoryCode]
			,PCAT.C_DESCRIPTION [CategoryDescription]
			,PB.C_DESCRIPTION [ProductBrand]
			,PR.C_DESCRIPTION [ProductRange]
			,PST.C_DESCRIPTION [Style]
			,IDXP.C_CODE [IndexProductOwnerCode]
			,IDXP.C_DESCRIPTION [IndexProductOwnerDescripion]
			,PC.C_DESCRIPTION [Colour]
			,PC2.C_DESCRIPTION [SecondaryColour]
			,PC3.C_DESCRIPTION [TrimColour]
			,PS.C_DISPLAYORDER [SizeDisplayOrder]
			,PS.C_CODE [SizeCode]
			,PLL.C_CODE [LegLength]
			,PV.C_DESCRIPTION [VarietyDescription]
			,CustomerSalesPerYear.C_YEAR [SalesYear]
			,PST.C_STOCKFEEDCODE [StyleStockFeedCode]
			
			-- Stock Calculations Below this line =================================================================================================================================================================================
			,cast(IIF(CustomerSalesPerYear.C_YEAR IS NULL,
					--THEN
					IIF(EffectiveStock.C_QUANTITY <= 0,
							--THEN
							0, 
							--ELSE
							EffectiveStock.C_QUANTITY
					)
					--ELSE
					,CustomerSalesPerYear.C_QUANTITY
			) as numeric(18,5)) [Break0] --If Effective Stock is negative show zero else show Effective Stock

			--Stock Calculations Above this line =================================================================================================================================================================================

		FROM T_PRODUCT							P
		LEFT JOIN T_PRODUCT					IDXP on P.C_INDEXPRODUCTOWNER = IDXP.C_ID
		LEFT JOIN T_PRODUCTCOLOUR			PC on P.C_D_PRIMARYCOLOUR = PC.C_ID
		LEFT JOIN T_PRODUCTCOLOUR			PC2 on P.C_D_SECONDARYCOLOUR = PC2.C_ID
		LEFT JOIN T_PRODUCTCOLOUR			PC3 on P.C_D_TRIMCOLOUR = PC3.C_ID
		LEFT JOIN T_PRODUCTSIZE				PS on P.C_SIZE = PS.C_ID
		LEFT JOIN T_PRODUCTVARIETY			PV on P.C_VARIETY = PV.C_ID
		LEFT JOIN T_PRODUCTCATEGORY			PCAT on P.C_CATEGORY = PCAT.C_ID
		LEFT JOIN T_CT_PRODUCTLEGLENGTH		PLL on P.C_D_LEGLENGTH = PLL.C_ID
		LEFT JOIN T_CT_PRODUCTSTYLE			PST on P.C_D_STYLE = PST.C_ID
		LEFT JOIN T_PRODUCTRANGE			PR on P.C_RANGE = PR.C_ID
		LEFT JOIN T_BRAND					PB on P.C_BRAND = PB.C_ID
		LEFT JOIN @EffectiveStock			EffectiveStock on P.C_ID = EffectiveStock.C_PRODUCT

		FULL JOIN @CustomerSalesPerYear		CustomerSalesPerYear on P.C_ID = CustomerSalesPerYear.C_PRODUCT

		LEFT JOIN(
				SELECT C_PRODUCT, sum(C_QUANTITY) C_QUANTITY
				FROM @StockIn sk 
				WHERE sk.C_DATETIME <= DATEADD(day,@break1,GETDATE())
				GROUP BY C_PRODUCT
		)									DueWithinBreak1 on P.C_ID = DueWithinBreak1.C_PRODUCT

		LEFT JOIN(
				SELECT C_PRODUCT, sum(C_QUANTITY) C_QUANTITY
				FROM @StockIn sk 
				WHERE sk.C_DATETIME <= DATEADD(day,@break2,GETDATE()) and sk.C_DATETIME > DATEADD(day,@break1,GETDATE())
				GROUP BY C_PRODUCT
		)									DueWithinBreak2 on P.C_ID = DueWithinBreak2.C_PRODUCT

		LEFT JOIN(
				SELECT C_PRODUCT, sum(C_QUANTITY) C_QUANTITY
				FROM @StockIn sk 
				WHERE sk.C_DATETIME <= DATEADD(day,@break3,GETDATE()) and sk.C_DATETIME > DATEADD(day,@break2,GETDATE())
				GROUP BY C_PRODUCT
		)									DueWithinBreak3 on P.C_ID = DueWithinBreak3.C_PRODUCT 

		LEFT JOIN(
				SELECT C_PRODUCT, sum(C_QUANTITY) C_QUANTITY
				FROM @StockIn sk 
				WHERE sk.C_DATETIME <= DATEADD(day,@break4,GETDATE()) and sk.C_DATETIME > DATEADD(day,@break3,GETDATE())
				GROUP BY C_PRODUCT
		)									DueWithinBreak4 on P.C_ID = DueWithinBreak4.C_PRODUCT 
		WHERE P.C_ID IN (SELECT C_PRODUCTID FROM @ProductList)
	) sourcedata
	UNPIVOT (Quantity for BreakNumber IN ( [Break0])) unpvt
	WHERE Quantity > 0 
		OR BreakNumber = 'Break0'
	ORDER BY 
		[Product Code]
	   ,[Stock Status]

END
