USE [Intact_IQ_Behrens_Live]
GO
/****** Object:  StoredProcedure [dbo].[CD_SalesDeliveryNotesDivisionDayOverview]    Script Date: 04/03/2021 10:44:34 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Ryan Curran
-- Create date: 18/04/2020
-- Description:	<Description,,>
-- =============================================
ALTER PROCEDURE [dbo].[CD_SalesDeliveryNotesDivisionDayOverview] 
(
	@StartDate datetime
)
AS
BEGIN
	SET NOCOUNT ON;


	/* COLUMNS HEADERS */
	DECLARE @ColumnName NVARCHAR(MAX)
	SELECT 
		@ColumnName  = COALESCE (@ColumnName + ',[' + DATENAME(d,Date) + '-' + DATENAME(dw,Date) + ']', '[' + DATENAME(d,Date) + '-' + DATENAME(dw,Date) + ']')
	FROM fn_GetSalesDeliveryNoteAnalysis()
	WHERE Date >= @StartDate
	GROUP BY 
		DATENAME(d,Date),DATENAME(dw,Date)

	ORDER BY 
		DATENAME(d,Date)

	/* GRAND TOTAL COLUMN */
	DECLARE @GrandTotalCol	NVARCHAR(MAX)
	SELECT @GrandTotalCol = COALESCE (@GrandTotalCol + 'ISNULL ([' + DATENAME(d,Date) + '-' + DATENAME(dw,Date) +'],0) + ', 'ISNULL([' + DATENAME(d,Date) + '-' + DATENAME(dw,Date) + '],0) + ')
	FROM fn_GetSalesDeliveryNoteAnalysis()
	WHERE Date >= @StartDate
	GROUP BY 
		DATENAME(d,Date),DATENAME(dw,Date)
	ORDER BY 
		DATENAME(d,Date)
	SET @GrandTotalCol = LEFT (@GrandTotalCol, LEN (@GrandTotalCol)-1)

	/* GRAND TOTAL ROW */
	DECLARE @GrandTotalRow	NVARCHAR(MAX)
	SELECT @GrandTotalRow = COALESCE(@GrandTotalRow + ',ISNULL(SUM([' + DATENAME(d,Date) + '-' + DATENAME(dw,Date) +']),0)', 'ISNULL(SUM([' + DATENAME(d,Date) + '-' + DATENAME(dw,Date) +']),0)')
	FROM fn_GetSalesDeliveryNoteAnalysis()
	WHERE Date >= @StartDate
	GROUP BY 
		DATENAME(d,Date),DATENAME(dw,Date)
	ORDER BY 
		DATENAME(d,Date)

	/* MAIN QUERY */
	DECLARE @sql NVARCHAR(MAX)
	SET @sql = 	'	SELECT
						 *
						,(' + @GrandTotalCol + ') AS [Grand_Total] 
					INTO #temp_MatchesTotal
					FROM (
							SELECT 
								 Division													[Division]
								,DATENAME(d, Date) + ''-'' +	DATENAME(dw, Date)			[Day]
								,CAST(COUNT(DeliveryNoteLineID) as int)						[NoLines]
							FROM fn_GetSalesDeliveryNoteAnalysis()
							WHERE Date >= ' + @StartDate + '
							GROUP BY
								 Division
								,DATENAME(d, Date)
								,DATENAME(dw, Date)
						) t
					PIVOT
						(
							SUM(t.NoLines)
							FOR t.Day IN (' + @ColumnName + ')
						) AS pivot_table

					SELECT * FROM (
						SELECT 
							 *
						FROM #temp_MatchesTotal 

						UNION ALL

						SELECT 
							 ''Total''
							,'+ @GrandTotalRow +'
							, ISNULL(SUM([Grand_Total]), 0) 
						FROM #temp_MatchesTotal
					) A
					ORDER BY A.Division

					DROP TABLE #temp_MatchesTotal'

	EXECUTE sp_executesql @sql

END
