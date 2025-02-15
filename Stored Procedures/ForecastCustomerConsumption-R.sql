USE [Intact_IQ_Behrens_Live]
GO
/****** Object:  StoredProcedure [dbo].[BEH_ForecastMonthlyCustomerSales]    Script Date: 04/03/2021 10:40:06 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Thomas Loughrey
-- =============================================
-- This is an old R script which would forecast customer sales based on previous sales the results are saved in the SageData database table T_ForecastResults
-- I'm going to keep this script here for reference however the product forecast script is much better, if this is to be revisted I suggest you use BEH_ForecastProductConsumption
-- and alter the input data to be relevant to customers.
-- =============================================
ALTER PROCEDURE [dbo].[BEH_ForecastMonthlyCustomerSales]
AS
BEGIN

	insert into [SageData].[dbo].[T_ForecastResults]
	EXEC sp_execute_external_script
    @language = N'R'

	-- R Script Here
    , @script = N'
	
	library("forecast")
	library(DescTools)

	#First Column MUST be GroupID e.g. Customer, Product etc
	#Remaining Columns must be numerical and will be forecasted! (these should be in timeseries order e.g. 2018-01, 2018-02 etc

	initdata <- Input

	Output = NULL

	#Convert Column 1 into a factor (basically remove all duplicates and see this as a group rather than a value)
	initdata[,1] <- as.factor(initdata[,1])
	iGroups = levels(initdata[,1])

	C_Period = format(as.Date(Sys.Date()),"%Y-%m");

	#How far to forecast into the future
	C_PredictionRange = 12
	for (iGroup in 1:length(iGroups)){
  
		#Get index values of this group
		idx = NULL
		idx = which(initdata[,1]==iGroups[iGroup])
  
		#5 months data will be used testing accuracy
		leadtime = 12

		#At least two obeservations to forecast
  if (length(idx) >= 2) {

	#IMPORTANT! Because we use a constant to ensure values > 0, this will effect forecasts e.g. a constant of 10 will result in a slightly different forecast 
	#than a constant of 100 (this can also include a method change and the MAPE will decrease as the constant gets larger)

	#Loop for every column 
	for (iColumn in 2:NCOL(initdata)){

	C_Property = NULL
	C_Property = names(initdata)[iColumn]

	constant = min(initdata[idx,iColumn])
	if (constant <= 0) {
	constant = abs(constant) + 1
	}
	else{
	constant = 0
	}
	initdata[idx,iColumn] = initdata[idx,iColumn] + constant

	xAll = NULL
    xAll <- ts(initdata[idx,iColumn], frequency = 12)
	
	C_GroupID = NULL
    C_GroupID = as.character(initdata[idx[1],1])
    C_Train = FALSE
   
    #Determine if training can be done
    if (length(idx) >= (leadtime + 2))  {
      idxtraining = idx[1:(length(idx)-(leadtime-1))]
        if(sum(initdata[idxtraining,iColumn]) > 0){
          C_Train = TRUE
        }
    }
    
    if (C_Train == TRUE){
  
      #Training Data (remove last three months data)

	  idxtest = NULL
      idxtest = idx[(length(idx)-(leadtime-1)):length(idx)]

	  idxtraining = NULL
      idxtraining = idx[1:(length(idx)-(leadtime-1))]
    
      #Create time series using index values of product (12 observations in a season)

	  xtraining = NULL
      xtraining <- ts(initdata[idxtraining,iColumn], frequency = 12)

	  xtest = NULL
      xtest <- initdata[idxtest,iColumn]
      
      forecasts = NULL
      
	  forecast1 = NULL
      forecast1 = holt(xtraining,damping=FALSE, h = C_PredictionRange)
      forecasts = rbind(forecasts,c(accuracy(f = forecast1$mean[1:leadtime], x = xtest)[3],accuracy(f = forecast1$mean[1:leadtime], x = xtest)[5],forecast1$model$call))
      
	  #Need 10 data points for damping
      if (length(idxtraining) >= 10){
		forecast4 = NULL
        forecast4 = holt(xtraining,damped=TRUE, h = C_PredictionRange)
        forecasts = rbind(forecasts,c(accuracy(f = forecast4$mean[1:leadtime], x = xtest)[3],accuracy(f = forecast4$mean[1:leadtime], x = xtest)[5],forecast4$model$call))
      }

      if (length(idxtraining) > 21) {

		forecast2 = NULL
        forecast2 = hw(xtraining,seasonal=''additive'',damped=FALSE, h = C_PredictionRange)
        forecasts = rbind(forecasts,c(accuracy(f = forecast2$mean[1:leadtime], x = xtest)[3],accuracy(f = forecast2$mean[1:leadtime], x = xtest)[5],forecast2$model$call))
      
		forecast3 = NULL
        forecast3 = hw(xtraining,seasonal=''additive'',damped=TRUE, h = C_PredictionRange)
        forecasts = rbind(forecasts,c(accuracy(f = forecast3$mean[1:leadtime], x = xtest)[3],accuracy(f = forecast3$mean[1:leadtime], x = xtest)[5],forecast3$model$call))
        
		forecast5 = NULL
        forecast5 = hw(xtraining,seasonal=''multiplicative'',damped=FALSE, h = C_PredictionRange)
        forecasts = rbind(forecasts,c(accuracy(f = forecast5$mean[1:leadtime], x = xtest)[3],accuracy(f = forecast5$mean[1:leadtime], x = xtest)[5],forecast5$model$call))
        
		forecast6 = NULL
        forecast6 = hw(xtraining,seasonal=''multiplicative'',damped=TRUE, h = C_PredictionRange)
        forecasts = rbind(forecasts,c(accuracy(f = forecast6$mean[1:leadtime], x = xtest)[3],accuracy(f = forecast6$mean[1:leadtime], x = xtest)[5],forecast6$model$call))
        
	  }
      
      #Find row with smallest error, execute the same forecast and replace data used.
      Bestidx = NULL
	  Bestidx = which.min(forecasts[,1])
      
	  BestMAE = NULL
	  BestMAPE = NULL
	  BestMethod = NULL
	  BestForecast = NULL

      if (Bestidx > 0) {

		BestMAE = as.numeric(forecasts[Bestidx,1]) #Mean Absolute Error
        BestMAPE = as.numeric(forecasts[Bestidx,2]) #Mean Absolute Percentage Error
        
        if (BestMAE == Inf) BestMAE = -1
        if (BestMAPE == Inf) BestMAPE = -1

        BestMethod = gsub("xtraining", "xAll", forecasts[Bestidx,3]) 
		
		#print(paste(C_GroupID,",",BestMethod))
		#print(xAll)
        BestForecast = eval(parse(text=BestMethod))

      }
      
    }
    # Not enough data points to train therefore do basic forecast
    else
    {
      BestForecast = holt(xAll,damped=FALSE, h = C_PredictionRange)
      BestMethod =  "holt(xAll,damped=FALSE, h = C_PredictionRange) [NotTrained]"
      BestMAE = -1
      BestMAPE = -1
    }
    
    #For each forecast
    for (iforecast in 1:length(BestForecast$mean)){
      
      C_ForecastedPeriod = NULL
      C_ForecastedAmount = NULL
      
      C_ForecastedPeriod = format(AddMonths(as.Date(Sys.Date()), iforecast-1),"%Y-%m")
      C_ForecastedAmount = floor(BestForecast$mean[iforecast]) - constant
      
	  #Ignore negative forecasts
      if (C_ForecastedAmount < 0){
        C_ForecastedAmount = 0
      }

      #Write forecast value
      row = c(C_GroupID,C_Property,C_Period,C_ForecastedPeriod,C_ForecastedAmount,BestMethod,BestMAE,BestMAPE)
      Output = rbind(Output,row)
    }
	}
  } 
 }

Output <- data.frame(Output)
'
	--SQL Input Script Here (The First Column must be a Grouping ID e.g. Customer, Product, the Second Column must be the time series
    , @input_data_1 = N'
	--Only get customers who have a 12 month margin != 0 
	SELECT MCS.C_Customer, MCS.C_NETAMOUNTLESSDISCOUNTBASE FROM [SageData].[dbo].[T_MonthlyCustomerSales] as MCS
	JOIN (
			SELECT 
			C_Customer
			,sum(C_NETAMOUNTLESSDISCOUNTBASE) as C_NETAMOUNTLESSDISCOUNTBASE
			FROM [SageData].[dbo].[T_MonthlyCustomerSales]
			where CONVERT(datetime, C_Period + ''-01'', 102) > DateAdd(month, -12, GetDATE())
			Group by C_Customer
			) as ActiveCustomers on ActiveCustomers.C_Customer = MCS.C_Customer
	where round(ActiveCustomers.C_NETAMOUNTLESSDISCOUNTBASE,2) != 0.00
	ORDER BY MCS.C_Customer, MCS.C_Period
	'
	, @input_data_1_name = N'Input'
	, @output_data_1_name = N'Output'
	, @parallel = 1
END
