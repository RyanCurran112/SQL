USE [Intact_IQ_Behrens_Live]
GO
/****** Object:  StoredProcedure [dbo].[CD_StockStatisticsDivisionYearOverview]    Script Date: 04/03/2021 10:45:49 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Ryan Curran
-- Create date: 03/04/2020
-- Description: A stored procedure to show overview of sales by rep & year on a control desk/dashboard
-- =============================================
ALTER PROCEDURE [dbo].[CD_StockStatisticsDivisionYearOverview]

AS
BEGIN
	
	SET NOCOUNT ON;

	/* COLUMNS HEADERS */
	DECLARE @ColumnName NVARCHAR(MAX)
	SELECT 
		@ColumnName  = COALESCE (@ColumnName + ',[' + D_Division + ']', '[' + D_Division + ']')
	FROM Intact_IQ_Behrens_Live_Archive.dbo.AgedStock
	GROUP BY 
		D_Division
	ORDER BY 
		D_Division

	/* GRAND TOTAL COLUMN */
	DECLARE @GrandTotalCol	NVARCHAR(MAX)
	SELECT @GrandTotalCol = COALESCE (@GrandTotalCol + 'ISNULL ([' + D_Division +'],0) + ', 'ISNULL([' + D_Division + '],0) + ')
	FROM Intact_IQ_Behrens_Live_Archive.dbo.AgedStock
	GROUP BY 
		D_Division
	ORDER BY 
		D_Division
	SET @GrandTotalCol = LEFT (@GrandTotalCol, LEN (@GrandTotalCol)-1)

	/* GRAND TOTAL ROW */
	DECLARE @GrandTotalRow	NVARCHAR(MAX)
	SELECT @GrandTotalRow = COALESCE(@GrandTotalRow + ',ISNULL(SUM([' + D_Division +']),0)', 'ISNULL(SUM([' + D_Division +']),0)')
	FROM Intact_IQ_Behrens_Live_Archive.dbo.AgedStock
	GROUP BY 
		D_Division
	ORDER BY 
		D_Division

	/* MAIN QUERY */
	DECLARE @sql NVARCHAR(MAX)
	SET @sql = 	'	SELECT
						 *
						,(' + @GrandTotalCol + ') AS [Grand_Total] 
					INTO #temp_MatchesTotal
					FROM (
							SELECT 
								 D_Division										[Division]
								,CAST(YEAR(D_MovementDate) as nvarchar)			[Movement_Year]
								,CAST(SUM(M_Value) as int)						[NetAmount]
							FROM Intact_IQ_Behrens_Live_Archive.dbo.AgedStock
							WHERE D_MovementDate > ''01/01/2010''
							GROUP BY
								 D_Division
								,D_MovementDate
						) t
					PIVOT
						(
							SUM(t.NetAmount)
							FOR t.Division IN (' + @ColumnName + ')
						) AS pivot_table
					ORDER BY Movement_Year ASC;

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
					ORDER BY A.Movement_Year

					
					DROP TABLE #temp_MatchesTotal'


	EXECUTE sp_executesql @sql

END
