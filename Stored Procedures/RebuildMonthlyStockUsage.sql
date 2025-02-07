USE [Intact_IQ_Behrens_Live]
GO
/****** Object:  StoredProcedure [dbo].[BEH_RebuildMonthlyStockUsage]    Script Date: 04/03/2021 10:43:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Thomas Loughrey
-- =============================================
-- The following is used by the database trigger [trg_StockConsumptionUpdate] on T_PRODUCT and is called when either the Supercession or OldStockCode of a product is changed.
-- This procedure will be called for the product being changed, the oldsupercession if it exists and the new supercession if it exists.
-- =============================================
ALTER PROCEDURE [dbo].[BEH_RebuildMonthlyStockUsage](
	@productid bigint --If this value is -1 a full rebuild will be completed else just the product specified
)
AS
BEGIN

--This will hold our products we will run a rebuild for
declare @ProductList Table
(
	C_ProductID bigint
)

--Create list of products to loop
INSERT INTO @ProductList 
SELECT C_ID FROM T_PRODUCT where C_ID = @productid or @productid = -1

--Clear Old Values
if @productid != -1
	begin
		DELETE FROM [SageData].[dbo].[T_MonthlyStockUsage] WHERE C_Product COLLATE SQL_Latin1_General_CP1_CI_AS = (SELECT C_CODE FROM T_PRODUCT WHERE C_ID = @productid);
	end;
else
	begin
		truncate table [SageData].[dbo].[T_MonthlyStockUsage]
	end;

declare @loopproductid bigint;
declare @launchdate datetime;
declare @loopproductcode VARCHAR (max);
declare @toDate datetime2;
declare @fromDate datetime2;

declare @temptable table(
	C_PERIOD int
	,C_QUANTITY numeric (18,5)
)

set @toDate = DATEADD(month, DATEDIFF(month, 0, GETDATE()), 0); --Get Today

--Loop through all items in @ProductList
WHILE (select COUNT(*) from @ProductList) > 0
begin

	set @loopproductid = (select top 1 C_ProductID from @ProductList)
	set @launchdate =  (SELECT C_LAUNCHDATE FROM T_PRODUCT WHERE C_ID = @loopproductid)

	--If Product was launched before the start of this month
	if @launchdate < @toDate
		begin

			PRINT @loopproductid;

			set @loopproductcode = (SELECT [C_CODE] FROM [Intact_IQ_Behrens_Live].[dbo].[T_PRODUCT] WHERE [C_ID] = @loopproductid)
			set @fromDate = DATEADD(month, DATEDIFF(month, 0, @launchdate), 0); --Get First Day of the Month of Launch Date
			if (@fromDate < '2014-01-01') set @fromDate ='2014-01-01'; --Ignore any data from before 2014

			DELETE FROM @temptable;

			--Display all months regardless if any result is shown (This ensures a record of zero sales in any given month is reported rather than being left out)
			With dt As
			(
				Select @fromDate As YearMonth
				Union All
				Select DateAdd(month, 1, YearMonth) From dt Where DateAdd(month, 1, YearMonth) < @toDate
			)
				insert into @temptable
				Select (Year(YearMonth)*100)+month(YearMonth), 0
			From
			dt
			option (maxrecursion 0);

			insert into @temptable
				--Get Sage Data
				SELECT 
					yearmonth as C_PERIOD,
					Sum([movement_quantity])*-1 as C_QUANTITY
				FROM SageData.dbo.stkhstm as S

				-- Some product codes were changed upon import and double spaces replaced with single spaces
				WHERE S.product COLLATE SQL_Latin1_General_CP1_CI_AS IN (SELECT C_D_OLDSTOCKCODE FROM fn_GetSupersessionProducts(@loopproductid)) 
				AND S.warehouse = '00' And movement_quantity < 0 And movement_date BETWEEN '2014-01-01' AND '2017-09-28' And S.transaction_type <> 'ADJ' AND S.transaction_type <> 'TRAN'
				GROUP BY yearmonth

			union all

			--Get Intact Data
			SELECT
				--Group By Last Day of The Month
				SM.C_D_YEARMONTH,
				Sum(SML.[C_QUANTITY])*-1 as Total
			FROM [Intact_IQ_Behrens_Live].[dbo].[T_STOCKMOVEMENT_LINE] as SML
			left JOIN dbo.T_STOCKMOVEMENT as SM on SM.C_ID = SML.C__OWNER_
			left JOIN dbo.T_PRODUCT as P on P.C_ID = SML.C_PRODUCT
			left JOIN dbo.T_CT_DIVISION as DIV on P.C_D_PRODUCTDIVISION = DIV.C_ID
			left JOIN dbo.T_STOCKBIN as SB on SB.C_ID = SML.C_STOCKBIN
			left join dbo.T_STOCKADJUSTMENT as SA on C_SOURCEITEM = SA.C_ID
			left join dbo.T_STOCKADJUSTMENTREASON as SAR on SA.C_REASON = SAR.C_ID
			left JOIN DBO.T_CUSTOMER as C on SM.C_CUSTOMER = C.C_ID

			--Get Source Order Type
			left join T_SALESDELIVERYNOTE_LINE SDNL on SML.C_SOURCEITEM = SDNL.C_ID
			left join T_SALESORDER_LINE SOL on SDNL.C_D_ORDERLINEBEH = SOL.C_ID
			left join T_SALESORDER SO on SOL.C__OWNER_ = SO.C_ID
			left join T_SALESORDERTYPE SOT on SO.C_ORDERTYPE = SOT.C_ID

			--Only Include Delivery Notes, Credit Note Requests, Works Order Issues, Stock Issues, Credit Notes, Invocies, Stock Returns, Returns Confirmation (Ignore Works Order Bins)
			WHERE 
			SB.C_CODE NOT LIKE '%WIP%' 
			AND(	
				   SM.C_SHORTTYPENAME = 'SL/Del' 
				or SM.C_SHORTTYPENAME = 'SL/CReq' 
				or SM.C_SHORTTYPENAME = 'SC/WOIss'
				or SM.C_SHORTTYPENAME = 'SC/Isu' 
				or SM.C_SHORTTYPENAME = 'SL/Crn'
				or SM.C_SHORTTYPENAME = 'SL/Inv' 
				or SM.C_SHORTTYPENAME = 'SC/Ret' 
				or SM.C_SHORTTYPENAME = 'RET/Con' 
				or (SM.C_SHORTTYPENAME = 'SC/Adj' and SAR.C_ID IN (SELECT C_ID FROM T_STOCKADJUSTMENTREASON WHERE C_D_INCLUDEINFORECASTING = 0))
			)
			AND P.C_ID IN (SELECT C_ID FROM fn_GetSupersessionProducts(@loopproductid))
			AND (SOT.C_D_INCLUDEINFORECASTING IS NULL OR SOT.C_D_INCLUDEINFORECASTING = 0) --Source Order Type Included in Forcasting
			AND (SM.C_CUSTOMER IS NULL OR SM.C_CUSTOMER IN (SELECT C_ID FROM T_CUSTOMER WHERE C_D_INCLUDEINFORECASTING = 0)) --Customer Included in Forecasting
			AND SM.C_DATE < @toDate

			GROUP BY SM.C_D_YEARMONTH
			--option (maxrecursion 0) --for fn_GetSupersessionProducts

			insert into [SageData].[dbo].[T_MonthlyStockUsage]
			SELECT @loopproductcode,concat(left(C_PERIOD,4),'-',right(C_PERIOD,2)), sum(C_QUANTITY) 
			FROM @temptable 
			where C_PERIOD IS NOT NULL
			group by C_PERIOD

		end;

	--kick this item from @ProductList
	delete from @ProductList where C_ProductID = @loopproductid
end

END
