USE [Intact_IQ_Behrens_Live]
GO
/****** Object:  StoredProcedure [dbo].[BEH_GetOverdueBalanceHistory]    Script Date: 04/03/2021 10:42:38 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Thomas Loughrey
-- =============================================
-- The following is used in the credit check dashboard to get the total value of overdue invoices at any given time. The overdue adjustment is used to specify how overdue in days the invoices
-- must be in order to be included. 

-- It should be noted that this DOES NOT INCLUDE OUTSTANDING CREDITS! This is the total value of the overdue invoices and therefore if there is an overdue invoice for £500 and an unallocated credit
-- for £500, this stored procedure will show this invoice as outstanding until the credit was allocated against the invoice.
-- =============================================
ALTER PROCEDURE [dbo].[BEH_GetOverdueBalanceHistory] 
	-- Add the parameters for the stored procedure here
	 @CustomerID bigint
	,@OverdueAdj Integer
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

declare @temptable table(
	 C_DATETIME Datetime INDEX IX1 CLUSTERED
	,C_ADJ numeric (18,2)
	,C_AMOUNT numeric (18,2)
	,C_SOURCE bigint
)

--Oustanding Amount After DueDate
insert into @temptable
SELECT 
	DateAdd(day,@OverdueAdj,C_DUEDATE) as 'C_DUEDATE'
	,cast((C_AMOUNT / C_TRANSACTIONEXCHANGERATE)*C_ACCOUNTEXCHANGERATE as DECIMAL(19,2)) - isnull(AmountPaidBeforeDueDate.C_AMOUNTALLOCATEDACCOUNTCURRENCY,0.00) - isnull(AmountPaidBeforeDueDate.C_AMOUNTWRITEOFFACCOUNTCURRENCY,0.00) - isnull(AmountPaidBeforeDueDate.C_SETTLEMENTDISCOUNTACCOUNTCURRENCY,0.00) 
	,0
	,SLE.C_ID
FROM T_SALESLEDGERENTRY as SLE
LEFT JOIN (
	SELECT
		 C_ENTRY
		,SUM(SLAL.C_AMOUNTALLOCATEDACCOUNTCURRENCY) as C_AMOUNTALLOCATEDACCOUNTCURRENCY
		,sum(SLAL.C_SETTLEMENTDISCOUNTACCOUNTCURRENCY) as C_SETTLEMENTDISCOUNTACCOUNTCURRENCY
		,sum(SLAL.C_AMOUNTWRITEOFFACCOUNTCURRENCY) as C_AMOUNTWRITEOFFACCOUNTCURRENCY
	FROM T_SALESLEDGERALLOCATION_LINE as SLAL 
	LEFT JOIN T_SALESLEDGERALLOCATION as SLA on SLAL.C__OWNER_ = SLA.C_ID
	LEFT JOIN T_SALESLEDGERENTRY as SLE on SLAL.C_ENTRY = SLE.C_ID
	where (DateAdd(day,@OverdueAdj,DATEADD(dd, DATEDIFF(dd, 0, SLE.C_DUEDATE), 0))) >= DATEADD(dd, DATEDIFF(dd, 0, SLA.C_DATE), 0) and SLA.C_CUSTOMER = @CustomerID -- Where allocation date is on or before the duedate
	group by C_ENTRY
) as AmountPaidBeforeDueDate on AmountPaidBeforeDueDate.C_ENTRY = SLE.C_ID
where SLE.C_CUSTOMER = @CustomerID 
and C_JOURNALTYPE = 0 --Debit Only 
and (DateAdd(day,@OverdueAdj,DATEADD(dd, DATEDIFF(dd, 0, C_DUEDATE), 0))) < DATEADD(dd, DATEDIFF(dd, 0, GETDATE()), 0) --Only show items which are over the due date
and C_AMOUNT - isnull(AmountPaidBeforeDueDate.C_AMOUNTALLOCATEDACCOUNTCURRENCY,0.00) - isnull(AmountPaidBeforeDueDate.C_AMOUNTWRITEOFFACCOUNTCURRENCY,0.00) - isnull(AmountPaidBeforeDueDate.C_SETTLEMENTDISCOUNTACCOUNTCURRENCY,0.00) > 0.00 --Only show items which have an amount outstanding
and isnull(SLE.C_PARTICULARS,'') != 'Ledger Allocation Write Off' -- This is an automaticly generated ledger item however there is no allocation lineor credit created therefore just ignore these (the write off will be counted twce otherwise)
and C_SHORTTYPENAME = 'SL/Inv' -- Only Intrested in Overdue Invoices

--Amount Paid / Written Off After Due Date For Outstanding Items
insert into @temptable
SELECT 
	SLA.C_DATE
	,-sum(SLAL.C_AMOUNTALLOCATEDACCOUNTCURRENCY) - sum(isnull(SLAL.C_AMOUNTWRITEOFFACCOUNTCURRENCY,0.00)) - sum(isnull(SLAL.C_SETTLEMENTDISCOUNTACCOUNTCURRENCY,0.00))
	,0
	,SLAL.C_ENTRY
FROM T_SALESLEDGERALLOCATION_LINE as SLAL 
LEFT JOIN T_SALESLEDGERALLOCATION as SLA on SLAL.C__OWNER_ = SLA.C_ID
LEFT JOIN T_SALESLEDGERENTRY as SLE on  SLE.C_ID = SLAL.C_ENTRY
where 
SLAL.C_ENTRY IN (SELECT DISTINCT C_SOURCE FROM @temptable) 
and DATEADD(dd, DATEDIFF(dd, 0, SLA.C_DATE), 0) > DATEADD(dd, DATEDIFF(dd, 0, DateAdd(day,@OverdueAdj,SLE.C_DUEDATE)), 0) --where allocation date is past the due date
group by SLA.C_DATE, SLAL.C_ENTRY

--Insert Now
 insert into @temptable
 SELECT GetDate(), 0, 0, NULL

 --Running Sum
declare @total numeric (18,2)
set @total = 0.00
update @temptable set C_AMOUNT = @total, @total = @total + C_ADJ
 
 --Get All Data
 SELECT 
	CONVERT(CHAR(19),C_DATETIME,120) as 'C_DATETIME'
	,C_ADJ
	,C_AMOUNT
	,C_SOURCE
   FROM @temptable 
 order by C_DATETIME

END
