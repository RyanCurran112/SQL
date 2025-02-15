USE [Intact_IQ_Behrens_Live]
GO
/****** Object:  StoredProcedure [dbo].[BEH_GetIndexProductAnalysis]    Script Date: 04/03/2021 10:42:11 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Thomas Loughrey
-- =============================================
-- The following is used in the forecasting system index view tab to populate the pivot table. The information is passed to a pivot table function which will pivot the data how the user
-- would like therefore here we just provide a list of the data.
-- =============================================
ALTER PROCEDURE [dbo].[BEH_GetIndexProductAnalysis]
(
	 @productid bigint
	,@startdate datetime = ''
	,@enddate datetime = ''
	,@IncludeIndexes char(1) = 'T'
)
AS
BEGIN

--All Products to group / pivot (this includes supersessions)
declare @productslist table(
 C_PRODUCTID bigint INDEX IX1 CLUSTERED
,C_PRODUCTCODE nvarchar(max)
)

--Populate product list
IF @IncludeIndexes = 'T' 
BEGIN
	
	declare @indexowner bigint;
	set @indexowner = (SELECT C_INDEXPRODUCTOWNER FROM T_PRODUCT WHERE C_ID = @productid)

	--If Type = 'Index'
	IF (SELECT C_TYPE FROM T_PRODUCT WHERE C_ID = @productid) = 21 set @indexowner = @productid

	insert into @productslist
	SELECT P.C_ID, ISNULL(NULLIF(P.C_D_OLDSTOCKCODE, ''),P.C_CODE) FROM T_PRODUCT as P
	LEFT JOIN T_PRODUCT as SUPERSESSION on P.C_SUPERSEDEDBY = SUPERSESSION.C_ID
	where P.C_INDEXPRODUCTOWNER = @indexowner or P.C_ID = @productid or SUPERSESSION.C_INDEXPRODUCTOWNER = @indexowner or SUPERSESSION.C_ID = @productid
END

IF @IncludeIndexes = 'F' 
BEGIN
	insert into @productslist
	SELECT P.C_ID, ISNULL(NULLIF(P.C_D_OLDSTOCKCODE, ''),P.C_CODE) FROM T_PRODUCT as P
	where  P.C_ID = @productid
END

SELECT
 nest1.Product 'ProductCode'
 ,FORMAT(nest1.Date, 'yyyy-MM-dd') as 'Date'

 ,left(datename(weekday,nest1.Date),3) as 'Weekday'
 ,DATEPART(week, nest1.Date) as 'Week'
 ,left(datename(mm, nest1.Date),3) as 'Month'
 ,DATEPART(qq, nest1.Date) as 'Quarter'
 ,DATEPART(YYYY, nest1.Date) as 'Year'
 ,nest1.Number
 ,nest1.Type
 ,IIF(nest1.Type = 'FCST','true','false') as 'Forecast'
 ,ISNULL(nest1.Customer,'') as 'Customer'
 ,ISNULL(nest1.FirstName,'') as 'FirstName'
 ,ISNULL(nest1.LastName,'') as 'LastName'
 ,ISNULL(nest1.CompanyName,'') as 'CompanyName'

 ,ISNULL(nest1.AddressLine1,'') as 'AddressLine1'
 ,ISNULL(nest1.AddressLine2,'') as 'AddressLine2'
 ,ISNULL(nest1.AddressLine3,'') as 'AddressLine3'
 ,ISNULL(nest1.AddressLine4,'') as 'AddressLine4'
 ,ISNULL(nest1.Country,'') as 'Country'
 ,ISNULL(RTRIM(LTRIM(nest1.PostCode)),'') as 'PostCode'

 ,nest1.Period
 ,nest1.Quantity

,ISNULL(PC.C_DESCRIPTION,'N/A') as 'Colour'
,ISNULL(PS.C_DESCRIPTION, 'N/A') as 'Size'
,ISNULL(PV.C_DESCRIPTION, 'N/A') as 'Variety'
,ISNULL(PR.C_DESCRIPTION, 'N/A') as 'Range'
,ISNULL(PComp.C_DESCRIPTION, 'N/A') as 'ProductComposition'

--------------------Add new Pivot columns here (don't forget to add them to the below selects also for union to work------------------------
,nest1.CustomerDivision as 'CustomerDivision'

FROM(

	--Get Sage Data
	SELECT 
		product COLLATE SQL_Latin1_General_CP1_CI_AS as 'Product'
		,dated as 'Date'
		,movement_reference COLLATE SQL_Latin1_General_CP1_CI_AS as 'Number'
		,transaction_type COLLATE SQL_Latin1_General_CP1_CI_AS as 'Type'
		,customer COLLATE SQL_Latin1_General_CP1_CI_AS as 'Customer'
		,'N/A' as 'FirstName'
		,'N/A' as 'LastName'
		,'N/A' as 'CompanyName'
		,address1 COLLATE SQL_Latin1_General_CP1_CI_AS as 'AddressLine1'
		,address2 COLLATE SQL_Latin1_General_CP1_CI_AS as 'AddressLine2' 
		,address3 COLLATE Latin1_General_BIN  as 'AddressLine3'
		,address4 COLLATE Latin1_General_BIN  as 'AddressLine4'
		,address5 COLLATE SQL_Latin1_General_CP1_CI_AS as 'Country'
		,address6 COLLATE SQL_Latin1_General_CP1_CI_AS as 'PostCode'
		,CONVERT(CHAR(7),movement_date,120) as 'Period'
		,[movement_quantity]*-1 as 'Quantity'

		--================================Add new Pivot columns here (don't forget to add them to the below selects also for union to work=================================================
		,'N/A' as 'CustomerDivision'

	FROM SageData.dbo.stkhstm as S

	--Join Sales Order
	LEFT JOIN [SageData].[dbo].[opheadm] as SO on  S.movement_reference = SO.order_no

	WHERE S.product COLLATE SQL_Latin1_General_CP1_CI_AS IN (SELECT C_PRODUCTCODE FROM @productslist)
	AND S.warehouse = '00' And movement_quantity < 0 And movement_date >= '2014-01-01' And S.transaction_type <> 'ADJ' AND S.transaction_type <> 'TRAN'
	AND (dated < @enddate or @enddate = '1900-01-01') 
	AND (dated >= @startdate or @startdate = '1900-01-01')

	UNION ALL --Append the following:

	 --Get Intact Data
	 SELECT
		--Group By Last Day of The Month
		 P.C_CODE as 'Product'
		,SM.C_DATE as 'Date'
		,ISNULL(SDN.C_NUMBER,ISNULL(SCN.C_NUMBER,'')) as 'Number'
		,C_SHORTTYPENAME as 'Type'
		,C.C_CODE as 'Customer'
		,CDCC.C_FIRSTNAME as 'FirstName'
		,CDCC.C_LASTNAME as 'LastName'
		,isnull(CDC.C_COMPANYNAME,concat(C.C_NAME,IIF(C.C_NAME != C.C_TRADINGNAME and len(C.C_TRADINGNAME) > 0,concat(' ',C.C_D_TRADINGNAMEPREFIX,' ',C.C_TRADINGNAME),''))) as 'CompanyName'
		,isnull(CDCA.C_ADDRESSLINE1, CA.C_ADDRESSLINE1) as 'AddressLine1' 
		,isnull(CDCA.C_ADDRESSLINE2, CA.C_ADDRESSLINE2) as 'AddressLine2' 
		,isnull(CDCA.C_ADDRESSLINE3, CA.C_ADDRESSLINE3) as 'AddressLine3'
		,isnull(CDCA.C_ADDRESSLINE4, CA.C_ADDRESSLINE4) as 'AddressLine4' 
		,isnull(CDCACTRY.C_NAME, CACTRY.C_NAME) as 'Country'
		,isnull(CDCA.C_POSTCODE, CA.C_POSTCODE) as 'PostCode'
		,CONVERT(CHAR(7),SM.C_DATE,120) as 'Period'
		,SML.[C_QUANTITY]*-1  as 'Quantity'

		--================================Add new Pivot columns here (don't forget to add them to the below SELECT statements for union to work)================================================
		,isnull(CDiv.C_CODE,'N/A') as 'CustomerDivision'

	 FROM [Intact_IQ_Behrens_Live].[dbo].[T_STOCKMOVEMENT_LINE] as SML
	 LEFT JOIN dbo.T_STOCKMOVEMENT as SM on SM.C_ID = SML.C__OWNER_
	 LEFT JOIN dbo.T_PRODUCT as P on P.C_ID = SML.C_PRODUCT
	 LEFT JOIN dbo.T_CT_DIVISION as DIV on P.C_D_PRODUCTDIVISION = DIV.C_ID
	 LEFT JOIN dbo.T_STOCKBIN as SB on SB.C_ID = SML.C_STOCKBIN
	 LEFT JOIN dbo.T_STOCKADJUSTMENT as SA on C_SOURCEITEM = SA.C_ID
	 LEFT JOIN dbo.T_STOCKADJUSTMENTREASON as SAR on SA.C_REASON = SAR.C_ID
	 LEFT JOIN DBO.T_CUSTOMER as C on SM.C_CUSTOMER = C.C_ID
	 LEFT JOIN T_CT_DIVISION as CDiv on C.C_D_DIVISION = CDiv.C_ID

	 LEFT JOIN T_SALESDELIVERYNOTE as SDN on SM.C_SOURCETRANSACTION = SDN.C_ID
	 LEFT JOIN T_SALESCREDITNOTE as SCN on SM.C_SOURCETRANSACTION = SCN.C_ID

	 LEFT JOIN T_CUSTOMER_DELIVERYCONTACT as CDC on SDN.C_DELIVERYCONTACT = CDC.C_ID
	 LEFT JOIN T_CONTACT as CDCC on SDN.C_DELIVERYCONTACT = CDCC.C_ID
	 LEFT JOIN T_ADDRESS as CDCA on  CDCC.C_ADDRESS = CDCA.C_ID
	 LEFT JOIN T_COUNTRY as CDCACTRY on CDCA.C_COUNTRY = CDCACTRY.C_ID

	 LEFT JOIN T_ADDRESS as CA on C.C_ADDRESS = CA.C_ID
	 LEFT JOIN T_COUNTRY as CACTRY on CDCA.C_COUNTRY = CACTRY.C_ID

	 --Get Source Order Type
	 LEFT JOIN T_SALESDELIVERYNOTE_LINE SDNL on SML.C_SOURCEITEM = SDNL.C_ID
	 LEFT JOIN T_SALESORDER_LINE SOL on SDNL.C_D_ORDERLINEBEH = SOL.C_ID
	 LEFT JOIN T_SALESORDER SO on SOL.C__OWNER_ = SO.C_ID
	 LEFT JOIN T_SALESORDERTYPE SOT on SO.C_ORDERTYPE = SOT.C_ID


	 --Only Include Delivery Notes, Credit Note Requests, Works Order Issues, Stock Issues, Credit Notes, Invocies, Stock Returns, Returns Confirmation (Ignore Works Order Bins)
	 WHERE 
	 
	SB.C_CODE NOT LIKE '%WIP%' 
	AND (	
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
	 AND P.C_ID IN (SELECT C_PRODUCTID FROM @productslist)
	 AND (SOT.C_D_INCLUDEINFORECASTING IS NULL OR SOT.C_D_INCLUDEINFORECASTING = 0) --Source Order Type Included in Forcasting
	 AND (SM.C_CUSTOMER IS NULL OR SM.C_CUSTOMER IN (SELECT C_ID FROM T_CUSTOMER WHERE C_D_INCLUDEINFORECASTING = 0))
	 AND (SM.C_DATE < @enddate or @enddate = '1900-01-01') 
	 AND (SM.C_DATE >= @startdate or @startdate = '1900-01-01')

	 union all

	 SELECT 
	 	P.C_CODE as 'Product'
		,cast(PFL.C_FORECASTPERIOD + '-01' as datetime) as 'Date'
		,'' as 'Number'
		,'FCST' as 'Type'
		,'' as 'Customer'
		,'' as 'FirstName'
		,'' as 'LastName'
		,'' as 'CompanyName'
		,'' as 'AddressLine1' 
		,'' as 'AddressLine2' 
		,'' as 'AddressLine3'
		,'' as 'AddressLine4' 
		,'' as 'Country'
		,'' as 'PostCode'
		,PFL.C_FORECASTPERIOD as 'Period'
		,PFL.C_FORECASTAMOUNT as 'Quantity'

		--================================================Add new Pivot columns here=================================================================================
		,'N/A' as 'CustomerDivision'

	 FROM T_PRODUCT as P
	 
	 LEFT JOIN SageData.dbo.T_PRODUCT_DEFAULT_FORECAST as DPF on DPF.C_PRODUCT = P.C_ID
	 LEFT JOIN SageData.dbo.T_PRODUCT_FORECAST as PF on PF.C_PRODUCT = P.C_ID and C_ACTIVE = 1 and (C_FORECASTNAME = DPF.C_DEFAULTFORECASTNAME or (DPF.C_DEFAULTFORECASTNAME is NULL and C_FORECASTNAME = 'ETS'))
	 LEFT JOIN SageData.dbo.T_PRODUCT_FORECAST_LINE as PFL on C_OWNER =  PF.C_ID
	 where P.C_ID in (SELECT C_ID FROM T_PRODUCT where C_INDEXPRODUCTOWNER = @indexowner or C_ID = @productid) --Do not include supersessions here because the forecast will alredy take these into account
	 AND @enddate = '1900-01-01' 
	 AND @startdate = '1900-01-01'

) as nest1 

LEFT JOIN dbo.T_PRODUCT as P on P.C_CODE COLLATE SQL_Latin1_General_CP1_CI_AS = nest1.Product
LEFT JOIN dbo.T_PRODUCTCOLOUR as PC on P.C_COLOUR = PC.C_ID
LEFT JOIN dbo.T_PRODUCTSIZE as PS on P.C_SIZE = PS.C_ID
LEFT JOIN dbo.T_PRODUCTVARIETY as PV on P.C_VARIETY = PV.C_ID
LEFT JOIN dbo.T_PRODUCTRANGE as PR on P.C_RANGE = PR.C_ID
LEFT JOIN dbo.T_CT_PRODUCTCOMPOSITION as PComp on P.C_D_PRODUCTCOMPOSITION = PComp.C_ID

order by nest1.Date



END
