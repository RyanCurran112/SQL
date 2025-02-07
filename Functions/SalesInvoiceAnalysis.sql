USE [Intact_IQ_Behrens_Live]
GO
/****** Object:  UserDefinedFunction [dbo].[fn_GetSalesInvoiceAnalysis]    Script Date: 04/03/2021 10:53:08 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Ryan Curran
-- Create date: 21/11/19
-- Description:	Function to return all Sales Invoice Data
-- =============================================
ALTER FUNCTION [dbo].[fn_GetSalesInvoiceAnalysis]
(
)
RETURNS TABLE 
AS
RETURN 
(
	SELECT
		 SalesInvoice.C_ID																					TransactionID
		,Customer.C_ID																						CustomerID
		,SalesInvoice.C_CASHCUSTOMER																		CashCustomerID
		,DeliveryContact.DeliveryContactID																	DeliveryContactID
		,DeliveryContact.CompanyName																		DeliveryContactCompanyName
		,DeliveryContact.Postcode																			DeliveryPostcode

		,SalesInvoice.C_NUMBER																				TransactionNumber
		,SalesInvoice.C_ALTERNATEREFERENCE																	CustomerOrderNo
		,SO.C_DATE																							OrderDate
		,SalesInvoice.C_DATE																				TransactionDate
		,SalesInvoice.C_PERIOD																				TransactionPeriod
		,Currency.C_CODE																					TransactionCurrency
		,Branch.C_CODE																						Branch
		,DespatchBranch.C_CODE																				DespatchBranch
		,Division.C_CODE																					TransactionDivision
		,SalesRep.C_ID																						TransactionSalesRepID
		,SalesRep.C_NAME																					TransactionSalesRep
		,'Invoice'																							TransactionType

		,SalesInvoiceLine.C_ID																				TransactionLineID
		,Product.C_ID																						ProductID
		,(SELECT dbo.fn_GetSalesInvoiceLineType(SalesInvoiceLine.C_ID))										LineType
		,UOM.C_DESCRIPTION																					SellingUnits
		,''																									CreditNoteLineReason

		,SalesInvoiceLine.C_QUANTITYINSTOCKINGUNITS															Quantity
		,SalesInvoiceLine.C_QUANTITY																		SellingQuantity
		,SalesInvoice.C_TRANSACTIONEXCHANGERATE																TransactionExchangeRate
		,SalesInvoiceLine.C_NETCOST						/ SalesInvoice.C_TRANSACTIONEXCHANGERATE			NetCostBase
		,ROUND(SalesInvoiceLine.C_NETSELLINGCOST		/ SalesInvoice.C_TRANSACTIONEXCHANGERATE	,2)		NetSellingCostBase
		,SalesInvoiceLine.C_NETPRICE																		NetPrice
		,SalesInvoiceLine.C_NETAMOUNT																		NetAmount
		,ROUND(SalesInvoiceLine.C_NETAMOUNTLESSDISCOUNT	/ SalesInvoice.C_TRANSACTIONEXCHANGERATE	,2)		NetLessDiscountBase
		,SalesInvoiceLine.C_TAXAMOUNT																		TaxAmount
		,SalesInvoiceLine.C_GROSSAMOUNT																		GrossAmount
		,SalesInvoiceLine.C_MARGINAMOUNT				/ SalesInvoice.C_TRANSACTIONEXCHANGERATE			MarginAmountBase
		,SalesInvoiceLine.C_SELLINGMARGINAMOUNT			/ SalesInvoice.C_TRANSACTIONEXCHANGERATE			SellingMarginAmountBase 

	FROM T_SALESINVOICE_LINE SalesInvoiceLine
	INNER JOIN T_SALESINVOICE									(nolock)	SalesInvoice	ON SalesInvoiceLine.C__OWNER_			= SalesInvoice.C_ID
	INNER JOIN T_CUSTOMER										(nolock)	Customer		ON SalesInvoice.C_CUSTOMER				= Customer.C_ID
	INNER JOIN T_PRODUCT										(nolock)	Product			ON SalesInvoiceLine.C_PRODUCT			= Product.C_ID
	INNER JOIN T_CURRENCY										(nolock)	Currency		ON SalesInvoice.C_CURRENCY				= Currency.C_ID
	INNER JOIN T_BRANCH											(nolock)	Branch			ON SalesInvoice.C_BRANCH				= Branch.C_ID
	LEFT JOIN (SELECT * FROM fn_GetDeliveryContactDetails())				DeliveryContact	ON SalesInvoice.C_DELIVERYCONTACT		= DeliveryContact.DeliveryContactID
	LEFT JOIN T_BRANCH											(nolock)	DespatchBranch	ON SalesInvoice.C_DESPATCHBRANCH		= DespatchBranch.C_ID
	LEFT JOIN T_CT_DIVISION										(nolock)	Division		ON SalesInvoice.C_D_DIVISION			= Division.C_ID
	LEFT JOIN T_SALESREP										(nolock)	SalesRep		ON SalesInvoice.C_SALESREP				= SalesRep.C_ID
	LEFT JOIN T_UNITOFMEASURE									(nolock)	UOM				ON SalesInvoiceLine.C_SELLINGUNITS		= UOM.C_ID
	LEFT JOIN T_SALESDELIVERYNOTE_LINE							(nolock)	SDNL			ON SalesInvoiceLine.C_DELIVERYNOTELINE	= SDNL.C_ID
	LEFT JOIN T_SALESORDER_LINE									(nolock)	SOL				ON SDNL.C_SOURCELINE					= SOL.C_ID
	LEFT JOIN T_SALESORDER										(nolock)	SO				ON SOL.C__OWNER_						= SO.C_ID
	WHERE Product.C_CODE <> 'DEP'

	UNION ALL

	SELECT 
		 SalesCreditNote.C_ID																				TransactionID
		,Customer.C_ID																						CustomerID
		,SalesCreditNote.C_CASHCUSTOMER																		CashCustomerID
		,DeliveryContact.DeliveryContactID																	DeliveryContactID
		,DeliveryContact.CompanyName																		DeliveryContactCompanyName
		,DeliveryContact.Postcode																			DeliveryPostcode

		,SalesCreditNote.C_NUMBER																			TransactionNumber
		,SalesCreditNote.C_ALTERNATEREFERENCE																CustomerOrderNo
		,''																									OrderDate
		,SalesCreditNote.C_DATE																				TransactionDate
		,SalesCreditNote.C_PERIOD																			TransactionPeriod
		,Currency.C_CODE																					TransactionCurrency
		,Branch.C_CODE																						Branch
		,ReturnBranch.C_CODE																				DespatchBranch
		,Division.C_CODE																					TransactionDivision
		,SalesRep.C_ID																						TransactionSalesRepID
		,SalesRep.C_NAME																					TransactionSalesRep
		,'Credit Note'																						TransactionType
		
		,SalesCreditNoteLine.C_ID																			TransactionLineID
		,Product.C_ID																						ProductID
		,(SELECT dbo.fn_GetSalesInvoiceLineType(SalesCreditNoteLine.C_ID))									LineType	
		,UOM.C_DESCRIPTION																					SellingUnits
		,CreditReason.C_DESCRIPTION																			CreditNoteLineReason

		,(SalesCreditNoteLine.C_QUANTITYINSTOCKINGUNITS) *-1												Quantity
		,(SalesCreditNoteLine.C_QUANTITY) *-1																SellingQuantity
		,SalesCreditNote.C_TRANSACTIONEXCHANGERATE															TransactionExchangeRate
		,(SalesCreditNoteLine.C_NETCOST						/ SalesCreditNote.C_TRANSACTIONEXCHANGERATE)*-1	NetCostBase
		,(SalesCreditNoteLine.C_NETSELLINGCOST				/ SalesCreditNote.C_TRANSACTIONEXCHANGERATE)*-1	NetSellingCostBase
		,SalesCreditNoteLine.C_NETPRICE																		NetPrice
		,SalesCreditNoteLine.C_NETAMOUNT *-1																NetAmount
		,(SalesCreditNoteLine.C_NETAMOUNTLESSDISCOUNT		/ SalesCreditNote.C_TRANSACTIONEXCHANGERATE)*-1	NetLessDiscountBase
		,SalesCreditNoteLine.C_TAXAMOUNT *-1																TaxAmount
		,SalesCreditNoteLine.C_GROSSAMOUNT	*-1																GrossAmount
		,(SalesCreditNoteLine.C_MARGINAMOUNT				/ SalesCreditNote.C_TRANSACTIONEXCHANGERATE)*-1	MarginAmountBase
		,(SalesCreditNoteLine.C_SELLINGMARGINAMOUNT			/ SalesCreditNote.C_TRANSACTIONEXCHANGERATE)*-1	SellingMarginAmountBase

	FROM T_SALESCREDITNOTE_LINE SalesCreditNoteLine
	INNER JOIN T_SALESCREDITNOTE								(nolock) SalesCreditNote	ON SalesCreditNoteLine.C__OWNER_		= SalesCreditNote.C_ID
	INNER JOIN T_CUSTOMER										(nolock) Customer			ON SalesCreditNote.C_CUSTOMER			= Customer.C_ID
	INNER JOIN T_PRODUCT										(nolock) Product			ON SalesCreditNoteLine.C_PRODUCT		= Product.C_ID
	INNER JOIN T_CURRENCY										(nolock) Currency			ON SalesCreditNote.C_CURRENCY			= Currency.C_ID
	INNER JOIN T_BRANCH											(nolock) Branch				ON SalesCreditNote.C_BRANCH				= Branch.C_ID
	LEFT JOIN (SELECT * FROM fn_GetDeliveryContactDetails())			 DeliveryContact	ON SalesCreditNote.C_DELIVERYCONTACT	= DeliveryContact.DeliveryContactID
	LEFT JOIN T_BRANCH											(nolock) ReturnBranch		ON SalesCreditNote.C_RETURNBRANCH		= ReturnBranch.C_ID
	LEFT JOIN T_CT_DIVISION										(nolock) Division			ON SalesCreditNote.C_D_DIVISION			= Division.C_ID
	LEFT JOIN T_SALESREP										(nolock) SalesRep			ON SalesCreditNote.C_SALESREP			= SalesRep.C_ID
	LEFT JOIN T_UNITOFMEASURE									(nolock) UOM				ON SalesCreditNoteLine.C_SELLINGUNITS	= UOM.C_ID
	LEFT JOIN T_SALESCREDITNOTELINEREASON						(nolock) CreditReason		ON SalesCreditNoteLine.C_REASON			= CreditReason.C_ID
	WHERE Product.C_CODE <> 'DEP'
)
