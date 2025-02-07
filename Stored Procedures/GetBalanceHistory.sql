USE [Intact_IQ_Behrens_Live]
GO
/****** Object:  StoredProcedure [dbo].[BEH_GetBalanceHistory]    Script Date: 04/03/2021 10:40:59 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Thomas Loughrey
-- =============================================
	-- The following is used in the credit check dashboard and will plot the balance history and the credit limit audit history
-- =============================================
ALTER PROCEDURE [dbo].[BEH_GetBalanceHistory] 
	-- Add the parameters for the stored procedure here
	@CustomerID bigint
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    declare @temptable table(
		C_DateTime Datetime INDEX IX1 CLUSTERED
		,C_Adj numeric (18,2)
		,C_Balance numeric (18,2)
	)

	insert into @temptable
	SELECT 
	C_DATE
	,IIF(C_JOURNALTYPE = 0, C_AMOUNT,-C_AMOUNT)
	,0
	FROM T_SALESLEDGERENTRY as SLE
	where C_CUSTOMER = @CustomerID
	order by C_DATE

	--Insert Current Datetime with no Adjustment
	insert into @temptable
	SELECT GetDate(), 0, 0

	declare @total numeric (18,2)
	set @total = 0.00

	update @temptable set C_Balance = @total, @total = @total + C_Adj 

	 declare @temptable2 table(
		C_DateTime Datetime INDEX IX1 CLUSTERED
		,C_FROM numeric (18,2)
		,C_TO numeric (18,2)
	)

	insert into @temptable2
	SELECT 
		C_DATETIME
		,cast(C_MODIFICATIONS as xml).value('(/ModifiedProperties/CreditControlSetup.CreditLimit/@From)[1]','numeric (18,5)') C_FROM
		,cast(C_MODIFICATIONS as xml).value('(/ModifiedProperties/CreditControlSetup.CreditLimit/@To)[1]','numeric (18,5)') C_TO
	FROM T_AUDITITEM where C_ITEM = @CustomerID and C_MODIFICATIONS LIKE '%CreditControlSetup.CreditLimit%' 

	declare @currentcreditlimit numeric (18,2)
	set @currentcreditlimit =  (SELECT CCCS.C_CREDITLIMIT  FROM T_CUSTOMER as C
								LEFT JOIN T_CUSTOMER_CREDITCONTROLSETUP as CCCS on C.C_CREDITCONTROLSETUP = CCCS.C_ID
								where C.C_ID = @CustomerID
								)

	--Import First Value From Audit Trail
	insert into @temptable2
	SELECT
	(SELECT C_DATETIME FROM T_AUDITITEM where C_ITEM = @CustomerID and C_ACTIONTYPE = 0) --Date When Customer Was Created
	,0 
	,isnull((SELECT TOP 1 C_FROM FROM @temptable2 order by C_DATETIME), @currentcreditlimit) --C_FROM Or Current Credit Limit if no Audit History


	--Import Current Value
	insert into @temptable2
	SELECT GetDate(), @currentcreditlimit, @currentcreditlimit
	
	--Get Credit Limit Info
	SELECT CONVERT(CHAR(19),C_DateTime,120) as 'C_DateTime', 'Credit Limit' as C_Series, C_TO as 'C_Value' from @temptable2

	--Get Balance Info
	union all SELECT CONVERT(CHAR(19),C_DateTime,120) as 'C_DateTime','Balance' as C_Series,C_Balance as 'C_Value' FROM @temptable

END
