USE [Intact_IQ_Behrens_Live]
GO
/****** Object:  StoredProcedure [dbo].[BEH_ForecastProductConsumption]    Script Date: 04/03/2021 10:37:57 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Thomas Loughrey
-- =============================================
-- This is the main forecasting stored procedure and is very important!
-- The following stored procedure is added to SQL Server Agent > Jobs > BEH_Monthly which runs at the start of every month.
-- This will run and save a forecast for every product in a division
-- Products must have sold more than one unit to be included in the forecast
-- The results of the forecast are saved in sagedata.dbo.T_PRODUCT_FORECAST and sagedata.dbo.T_PRODUCT_FORECAST_LINE
--=============================================
ALTER PROCEDURE [dbo].[BEH_ForecastProductConsumption]
	-- Add the parameters for the stored procedure here
	 @divisioncode nvarchar(max) = ''
	,@productid bigint = -1
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	--=====================================================DO NOT ALTER THIS CODE UNLESS YOU ARE 100% CONFIDENT!=======================================================================

--the following table MUST allign with the returned R Code!
declare @temptable table(
 C_PRODUCT bigint
,C_PERIOD nvarchar(7)
,C_FORECASTNAME nvarchar(50)
,C_FORECASTMETHOD nvarchar(250)
,C_FORECASTPERIOD nvarchar(7)
,C_FORECASTTRANSFORMATION nvarchar(50)
,C_FORECASTCONSTANT float
,C_FORECASTVALUES nvarchar(max)
,C_FORECASTAMOUNT float
,C_ACTIVE int
)


--NDV 02:53.13
--BHT 03:35.45
--TDV 01:19:04
--RDV 00:06:47

declare @divisionid bigint 
set @divisionid = (SELECT C_ID FROM T_CT_DIVISION where C_CODE = @divisioncode)

insert into @temptable
EXEC sp_execute_external_script
    @language = N'R'

	-- R Script Here
    , @script = N'
		
	library("forecast")
	library(robets)
	library(DescTools)


	initdata <- Input

	Output = NULL

	uniqueid = levels(as.factor(initdata$C_ID))
	C_Period = format(as.Date(Sys.Date()),"%Y-%m");

	AddForecast <- function(Forecast.Amount,Forecast.Transformation,Forecast.Constant,Forecast.Name, Forecast.Method,Forecast.Amounts.String){
			
			Forecast.Period = format(AddMonths(as.Date(Sys.Date()), iforecast-1),"%Y-%m")
			
			#If any transformations are used they should be converted back here

			Forecast.ForecastedAmount = floor(Forecast.Amount) - Forecast.Constant

			if (Forecast.ForecastedAmount < 0) Forecast.ForecastedAmount = 0

			result <- c(C_ID, C_Period, Forecast.Name ,Forecast.Method, Forecast.Period ,Forecast.Transformation, Forecast.Constant, Forecast.Amounts.String, Forecast.ForecastedAmount,1)
			return (result)
	}

	if (length(uniqueid) > 0){
	for (iid in 1:length(uniqueid)){

		idx = which(initdata$C_ID[]==uniqueid[iid])
		C_ID = initdata$C_ID[idx[1]]

		model.raw <- initdata$C_Quantity[idx]
		model.adjraw <- model.raw[ min( which ( model.raw != 0 )) : length(model.raw) ]
		model.adjraw.string <- as.character(paste(model.adjraw,collapse=","))

		model.constant <- abs(max(model.adjraw)) + 1
		model.adjraw.GTZero <- model.adjraw + model.constant
		model.adjraw.GTZero.string <- as.character(paste(model.adjraw.GTZero,collapse=","))

		#ROBETS Forecast
		try({
			model.forecast = model.adjraw %>% ts(frequency = 12) %>% robets() %>% forecast(h=12)
			for (iforecast in 1:length(model.forecast$mean)){
				Output = rbind(Output,AddForecast(model.forecast$mean[iforecast],''None'',0,''ROBETS'',model.forecast$method,model.adjraw.string))
			}
		})

		#ETS Forecast
		try({
			model.forecast = model.adjraw %>% ts(frequency = 12) %>% ets() %>% forecast(h=12)
			for (iforecast in 1:length(model.forecast$mean)){
				Output = rbind(Output,AddForecast(model.forecast$mean[iforecast],''None'',0,''ETS'',model.forecast$method,model.adjraw.string))
			}
		})

		#Holt Forecast
		try({
			model.forecast = model.adjraw %>% ts(frequency = 12) %>% holt(damped=FALSE,h=12) %>% forecast(h=12)
			for (iforecast in 1:length(model.forecast$mean)){
				Output = rbind(Output,AddForecast(model.forecast$mean[iforecast],''None'',0,''Holts'',model.forecast$method,model.adjraw.string))
			}
		})

		#Holt Damped Forecast
		try({
			model.forecast = model.adjraw %>% ts(frequency = 12) %>% holt(damped=TRUE,h=12) %>% forecast(h=12)
			for (iforecast in 1:length(model.forecast$mean)){
				Output = rbind(Output,AddForecast(model.forecast$mean[iforecast],''None'',0,''Holts (D)'',model.forecast$method,model.adjraw.string))
			}
		})

		#Holt Winters Additive Forecast
		try({
			model.forecast = model.adjraw %>% ts(frequency = 12) %>% hw(seasonal=''additive'', damped=FALSE) %>% forecast(h=12)
			for (iforecast in 1:length(model.forecast$mean)){
				Output = rbind(Output,AddForecast(model.forecast$mean[iforecast],''None'',0,''Holt Winters Additive'',model.forecast$method,model.adjraw.string))
			}
		})

		#Holt Winters Additive Damped Forecast
		try({
			model.forecast = model.adjraw %>% ts(frequency = 12) %>% hw(seasonal=''additive'', damped=TRUE) %>% forecast(h=12)
			for (iforecast in 1:length(model.forecast$mean)){
				Output = rbind(Output,AddForecast(model.forecast$mean[iforecast],''None'',0,''Holt Winters Additive (D)'',model.forecast$method,model.adjraw.string))
			}
		})

		#Holt Winters Multiplicative Forecast
		try({
			model.forecast = model.adjraw.GTZero %>% ts(frequency = 12) %>% hw(seasonal=''multiplicative'', damped=FALSE) %>% forecast(h=12)
		
			for (iforecast in 1:length(model.forecast$mean)){
				Output = rbind(Output,AddForecast(model.forecast$mean[iforecast],''None'',model.constant,''Holt Winters Multiplicative'',model.forecast$method,model.adjraw.string))
			}

		})

		#Holt Winters Multiplicative Damped Forecast
		try({
			model.forecast = model.adjraw.GTZero %>% ts(frequency = 12) %>% hw(seasonal=''multiplicative'', damped=TRUE) %>% forecast(h=12)
			for (iforecast in 1:length(model.forecast$mean)){
				Output = rbind(Output,AddForecast(model.forecast$mean[iforecast],''None'',model.constant,''Holt Winters Multiplicative (D)'',model.forecast$method,model.adjraw.string))
			}
		})

		#Last 12 Month Usage
		try({
			model.forecast = model.adjraw[(length(model.adjraw)-11):length(model.adjraw)]
			for (iforecast in 1:length(model.forecast)){
				Output = rbind(Output,AddForecast(model.forecast[iforecast],''None'',0,''Last 12 Month Usage'',''Last 12 Month Usage'',model.adjraw.string))
			}
		})

		#Last Month Usage
		try({
			model.forecast = rep(model.adjraw[length(model.adjraw)],12)
			for (iforecast in 1:length(model.forecast)){
				Output = rbind(Output,AddForecast(model.forecast[iforecast],''None'',0,''Last Month Usage'',''Last Month Usage'',model.adjraw.string))
			}
		})

		#3 Month Average
		try({
			model.forecast = rep(mean(model.adjraw[(length(model.adjraw)-2):length(model.adjraw)]),12)
			for (iforecast in 1:length(model.forecast)){
				Output = rbind(Output,AddForecast(model.forecast[iforecast],''None'',0,''3 Month Average'',''3 Month Average'',model.adjraw.string))
			}
		})

		#6 Month Average
		try({
			model.forecast = rep(mean(model.adjraw[(length(model.adjraw)-5):length(model.adjraw)]),12)
			for (iforecast in 1:length(model.forecast)){
				Output = rbind(Output,AddForecast(model.forecast[iforecast],''None'',0,''6 Month Average'',''6 Month Average'',model.adjraw.string))
			}
		})

		#9 Month Average
		try({
			model.forecast = rep(mean(model.adjraw[(length(model.adjraw)-8):length(model.adjraw)]),12)
			for (iforecast in 1:length(model.forecast)){
				Output = rbind(Output,AddForecast(model.forecast[iforecast],''None'',0,''9 Month Average'',''9 Month Average'',model.adjraw.string))
			}
		})

		#12 Month Average
		try({
			model.forecast = rep(mean(model.adjraw[(length(model.adjraw)-11):length(model.adjraw)]),12)
			for (iforecast in 1:length(model.forecast)){
				Output = rbind(Output,AddForecast(model.forecast[iforecast],''None'',0,''12 Month Average'',''12 Month Average'',model.adjraw.string))
			}
		})

		#No Forecast
		try({
			model.forecast = rep(0,12)
			for (iforecast in 1:length(model.forecast)){
				Output = rbind(Output,AddForecast(model.forecast[iforecast],''None'',0,''No Forecast'',''No Forecast'',model.adjraw.string))
			}
		})
	}
  } 

Output <- data.frame(Output)

'

	--SQL Input Script Here
    , @input_data_1 = N'
	--Only get products which have sold in the last 12 months
	SELECT
	P.C_ID
	,MSU.C_Month
	,MSU.C_Quantity
	FROM [SageData].[dbo].[T_MonthlyStockUsage] as MSU
	JOIN Intact_IQ_Behrens_Live.dbo.T_PRODUCT as P on P.C_CODE COLLATE Latin1_General_CI_AS = MSU.C_Product
	where C_Product IN(
			SELECT 
			C_Product
			FROM [SageData].[dbo].[T_MonthlyStockUsage] as MSU2
			JOIN Intact_IQ_Behrens_Live.dbo.T_PRODUCT as P on P.C_CODE COLLATE Latin1_General_CI_AS = MSU2.C_Product
			JOIN Intact_IQ_Behrens_Live.dbo.T_CT_DIVISION as D on D.C_ID = P.C_D_PRODUCTDIVISION
			WHERE C_Month IN (SELECT DISTINCT TOP(12) C_Month FROM [SageData].[dbo].[T_MonthlyStockUsage] ORDER BY C_Month DESC) and  P.C_SUPERSEDEDBY IS NULL and (P.C_D_PRODUCTDIVISION = @divisionid_r or P.C_ID = @productid_r)
			GROUP BY C_Product
			HAVING sum(C_Quantity) > 1
	)
	ORDER BY P.C_ID, MSU.C_MONTH
	'
	, @input_data_1_name = N'Input'
	, @output_data_1_name = N'Output'
	, @params = N' @divisionid_r bigint, @productid_r bigint' 
	, @divisionid_r = @divisionid
	, @productid_r = @productid
   -- WITH RESULT SETS undefined;

   --Set All Previous Forecasts to Inactive
	UPDATE sagedata.dbo.T_PRODUCT_FORECAST SET [C_ACTIVE] = 0 where [C_ACTIVE] = 1 and C_PRODUCT IN (SELECT C_ID FROM T_PRODUCT where C_D_PRODUCTDIVISION = @divisionid)
	UPDATE sagedata.dbo.T_PRODUCT_FORECAST SET [C_ACTIVE] = 0 where [C_ACTIVE] = 1 and C_PRODUCT = @productid

   --Insert Forecast Headers
   insert into sagedata.dbo.T_PRODUCT_FORECAST
   SELECT DISTINCT
       [C_PRODUCT]
      ,[C_PERIOD]
	  ,[C_FORECASTNAME]
      ,[C_FORECASTMETHOD]
      ,[C_FORECASTTRANSFORMATION]
      ,[C_FORECASTCONSTANT]
      ,[C_FORECASTVALUES]
      ,[C_ACTIVE]
  FROM @temptable

  --Insert Forecast Lines
  insert into sagedata.dbo.T_PRODUCT_FORECAST_LINE
  SELECT
		 PF.[C_ID]
		,temp.[C_FORECASTPERIOD]
		,temp.[C_FORECASTAMOUNT]
  FROM @temptable as temp
  left JOIN sagedata.dbo.T_PRODUCT_FORECAST as PF on PF.[C_ACTIVE] = 1 and PF.[C_PRODUCT] = temp.[C_PRODUCT] and PF.[C_FORECASTNAME] COLLATE Latin1_General_CI_AS = temp.[C_FORECASTNAME]

END
