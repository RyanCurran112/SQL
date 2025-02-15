USE [Intact_IQ_Behrens_Live]
GO
/****** Object:  UserDefinedFunction [dbo].[fn_GetSalesDeliveryNoteAnalysis]    Script Date: 04/03/2021 10:53:35 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Ryan Curran
-- Create date: 30/03/2020
-- Description:	Function to return all Sales Delivery Note Data
-- =============================================
ALTER FUNCTION [dbo].[fn_GetSalesDeliveryNoteAnalysis]
(	

)
RETURNS TABLE 
AS
RETURN 
(
	SELECT
		 SalesDeliveryNote.C_ID																					DeliveryNoteID
		,SalesDeliveryNote.C_NUMBER																				Number
		,CONVERT(date, SalesDeliveryNote.C_DATE)																Date
		,SalesDeliveryNote.C_DUEDATE																			DueDate
		,SalesDeliveryNote.C_ALTERNATEREFERENCE																	CustomerOrderNo

		,Branch.C_CODE																							Branch
		,DespatchBranch.C_CODE																					DespatchBranch
		,Division.C_CODE																						Division
		,SalesRep.C_NAME																						SalesRep
		,SalesDeliveryNote.C_CUSTOMER																			CustomerID
		
		,SalesDeliveryNote.C_DELIVERYCONTACT																	DeliveryContactID
		,DeliveryAgent.C_DESCRIPTION																			DeliveryAgent
		,DeliveryAgentService.C_DESCRIPTION																		DeliveryAgentService

		,Currency.C_CODE																						Currency
		
		,(SELECT dbo.fn_GetSalesDeliveryNotePricingStatus(SalesDeliveryNote.C_PRICINGSTATUS))					PricingStatus
		,(SELECT dbo.fn_GetSalesDeliveryNoteBillingStatus(SalesDeliveryNote.C_BILLINGSTATUS))					BillingStatus
		
		,SalesDeliveryNoteLine.C_D_ORDERLINEBEH																	SalesOrderLineID
		,SalesDeliveryNoteLine.C_ID																				DeliveryNoteLineID
		,SalesDeliveryNoteLine.C_PRODUCT																		ProductID
		,UOM.C_DESCRIPTION																						SellingUnits

		,(SELECT dbo.fn_GetSalesOrderLineType(SalesDeliveryNoteLine.C_LINETYPE))								LineType

		,SalesDeliveryNoteLine.C_QUANTITYINSTOCKINGUNITS														QuantityInStockingUnits
		,SalesDeliveryNoteLine.C_QUANTITY																		Quantity

		,SalesDeliveryNote.C_TRANSACTIONEXCHANGERATE															ExchangeRate
		,SalesDeliveryNoteLine.C_NETCOST					/ SalesDeliveryNote.C_TRANSACTIONEXCHANGERATE		NetCostBase
		,ROUND(SalesDeliveryNoteLine.C_NETSELLINGCOST		/ SalesDeliveryNote.C_TRANSACTIONEXCHANGERATE	,2)	NetSellingCostBase
		,SalesDeliveryNoteLine.C_NETPRICE																		NetPrice
		,SalesDeliveryNoteLine.C_NETAMOUNT																		NetAmount
		,ROUND(SalesDeliveryNoteLine.C_NETAMOUNTLESSDISCOUNT/ SalesDeliveryNote.C_TRANSACTIONEXCHANGERATE	,2)	NetLessDiscountBase
		,SalesDeliveryNoteLine.C_TAXAMOUNT																		TaxAmount
		,SalesDeliveryNoteLine.C_GROSSAMOUNT																	GrossAmount
		,SalesDeliveryNoteLine.C_MARGINAMOUNT				/ SalesDeliveryNote.C_TRANSACTIONEXCHANGERATE		MarginAmountBase
		,SalesDeliveryNoteLine.C_SELLINGMARGINAMOUNT		/ SalesDeliveryNote.C_TRANSACTIONEXCHANGERATE		SellingMarginAmountBase 

	FROM T_SALESDELIVERYNOTE_LINE											SalesDeliveryNoteLine
	INNER JOIN T_SALESDELIVERYNOTE								(nolock)	SalesDeliveryNote		ON SalesDeliveryNoteLine.C__OWNER_			= SalesDeliveryNote.C_ID
	LEFT JOIN T_BRANCH											(nolock)	Branch					ON SalesDeliveryNote.C_BRANCH				= Branch.C_ID
	LEFT JOIN T_BRANCH											(nolock)	DespatchBranch			ON SalesDeliveryNote.C_DESPATCHBRANCH		= DespatchBranch.C_ID
	LEFT JOIN T_CURRENCY										(nolock)	Currency				ON SalesDeliveryNote.C_CURRENCY				= Currency.C_ID
	LEFT JOIN (SELECT * FROM fn_GetDeliveryContactDetails())				DeliveryContact			ON SalesDeliveryNote.C_DELIVERYCONTACT		= DeliveryContact.DeliveryContactID
	LEFT JOIN T_CT_DIVISION										(nolock)	Division				ON SalesDeliveryNote.C_D_DIVISION			= Division.C_ID
	LEFT JOIN T_SALESREP										(nolock)	SalesRep				ON SalesDeliveryNote.C_SALESREP				= SalesRep.C_ID
	LEFT JOIN T_DELIVERYAGENT									(nolock)	DeliveryAgent			ON SalesDeliveryNote.C_DELIVERYAGENT		= DeliveryAgent.C_ID
	LEFT JOIN T_DELIVERYAGENT_SERVICE							(nolock)	DeliveryAgentService	ON SalesDeliveryNote.C_DELIVERYAGENTSERVICE	= DeliveryAgentService.C_ID
	LEFT JOIN T_UNITOFMEASURE									(nolock)	UOM						ON SalesDeliveryNoteLine.C_SELLINGUNITS		= UOM.C_ID
)
