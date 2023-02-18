/*==========================================

Merges the files and calculates simple statistics

Last modified: AK (2/15/2023)	
===========================================*/
clear all

capture log close

global main_path "C:/Users/`c(username)'/OneDrive - Drexel University/Safegraph"		//WW's path
// global main_path "/Users/`c(username)'/Library/CloudStorage/OneDrive-DrexelUniversity/Data/Safegraph"		//AK's path
global data_path "$main_path/SG_Data"
global results_path "$main_path/SG_Data"
global raw_data "$data_path/Raw-release-2022-04-15/spend_patterns/Weekly"
global processed_data "$data_path/Processed"

use "$processed_data/weekly_balanced.dta", replace

*naics2 has 0s and 3s...not sure what industries they are...drop them for now & also drop naics92 (public admin & govt)
tab naics2
drop if naics2 == 0 | naics2 == 3 | naics == 92

*create aggregates
collapse (sum) raw_* visits, by (week naics2)
rename raw_total_spend spend
rename raw_num_transactions transactions
rename raw_num_customers customers

save "$processed_data/weekly_balanced_naics2.dta", replace


* create aggregates over different naics2 while preserving naics2 detail
use "$processed_data/weekly_balanced_naics2.dta", replace

reshape wide visits spend transactions customers, i(week) j(naics2)

foreach var in visits spend transactions customers {
	egen `var'0 = rowtotal(`var'*)		//private non-farm
	egen `var'4445 = rowtotal(`var'44 `var'45) 	//retail trade
	egen `var'60 = rowtotal(`var'61 `var'62) 	//education & health
	egen `var'70 = rowtotal(`var'71 `var'72) 	//leisure & hospitality
	egen `var'4678 = rowtotal(`var'4445 `var'60 `var'70 `var'81) //in-person service sectors
}

reshape long visits spend transactions customers, i(week) j(naics2)

gen spend_per_transaction = spend / transactions
gen spend_per_customer = spend / customers


* inspecting the aggregate data
foreach var in visits spend transactions customers spend_per_transaction spend_per_customer {
	twoway (line `var' week if naics2==0), title(`var') name(`var') nodraw
}
graph combine visits spend transactions customers spend_per_transaction spend_per_customer
graph export "$main_path/Results/SG_series_naics00.png", as(png) replace

* drop first week as it has much lower spending and transactions yet more visits than other weeks in Jan, Feb 2020
drop if week == 0

* set visits after week 100 to missing since they drop to 0
replace visits = . if week > 100 


* plot relative aggregates as % of average of 2020 January and Febuary 
foreach var in visits spend transactions customers spend_per_transaction spend_per_customer {
	bysort naics2 (week): egen `var'ref = mean(`var') if week < 9	//reference is average over weeks 1-8
	bysort naics2 (week): replace `var'ref = `var'ref[1]	//spread reference value over all weeks within group
	gen r_`var' = 100 * `var'/`var'ref
	drop `var'ref
}

foreach var in r_visits r_spend r_transactions r_customers r_spend_per_transaction r_spend_per_customer {
	twoway (line `var' week if naics2==0), title(`var') name(`var') nodraw
}
graph combine r_visits r_spend r_transactions r_customers r_spend_per_transaction r_spend_per_customer
graph export "$main_path/Results/SG_r_series_naics00.png", as(png) replace


foreach n in 4445 60 70 81 {
	twoway (line r_visits week if naics2==`n'), title(`n') name(r_visits_`n') nodraw
}
graph combine r_visits_4445 r_visits_60 r_visits_70 r_visits_81 
graph export "$main_path/Results/SG_r_visits_in-person-naics.png", as(png) replace

foreach n in 4445 60 70 81 {
	twoway (line r_spend week if naics2==`n'), title(`n') name(r_spend_`n') nodraw
}
graph combine r_spend_4445 r_spend_60 r_spend_70 r_spend_81 
graph export "$main_path/Results/SG_r_spend_in-person-naics.png", as(png) replace

