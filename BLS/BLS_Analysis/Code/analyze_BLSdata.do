/*==========================================

Initial Data Analysis

Last modified: WW (2/14/2023)
===========================================*/
clear all

capture log close
global main_path "D:/Code/STATA/BLS_Analysis"
// global main_path "C:/Users/`c(username)'/OneDrive - Drexel University/Safegraph"		//WW's path
// global main_path "/Users/`c(username)'/Library/CloudStorage/OneDrive-DrexelUniversity/Data/Safegraph"	//AK's path
global data_path "$main_path/Data"
global raw_data "$data_path/Raw"
global clean_data "$data_path/Clean"
global results_path "$main_path/Results"

cd "$raw_data"
import delimited "$raw_data/bls_cpi_data_cmb.csv"

* Creates the month value by taking a substring of periodand
rename period month
replace month = substr(month, 2, 2)
destring month, replace

* Generates a date using year and month afterwards
gen int date = ym(year, month)
format date %tm

* Renaming our CPI data
* inflation rate is the 12 month percentage change in inflation_rate
rename value inflation_value
rename calculationspct_changes12 inflation_rate 

* Formatting missing values in for Stata to detect
replace inflation_rate = inflation_rate/100

* Drops the metro areas that are missing information on inflation_rate
* One kind of missing values are those that are reported with nan
// bys id (date): egen missing_values = total(missing(inflation_rate))
// drop if missing_values > 0

* The other type of missing value are those that don't include the existece of the missing month of data in the first place
// bys id (date): drop if _N < 396

egen group = group(id)
xtset group date
xtdescribe

save "$clean_data/bls_cpi_data_cmb.dta", replace

clear all
import delimited "$raw_data/bls_laus_data_cmb.csv"
rename value unemployment_rate
replace unemployment_rate = unemployment_rate/100
save "$clean_data/bls_laus_data_cmb.dta", replace

* Merging the dataset together for both unemployment_rate and inflation_rate to be together
clear all
use "$clean_data/bls_cpi_data_cmb.dta", replace
merge m:1 laus_check year periodname using "$clean_data/bls_laus_data_cmb.dta", keepusing(unemployment_rate)

save "$clean_data/bls_cpi_laus_data.dta", replace

drop if _merge != 3

sort id (year month)

/*
0: pre-covid -> Jan 2010 - Feb 2020
1: covid -> Mar 2020 - Feb 2021
2: post-covid -> Mar 2021 - Dec 2022
*/
gen covid = 0
replace covid = 1 if dofm(date) >= date("202003","YM")
replace  covid = 2 if dofm(date) >= date("202103","YM")

twoway (scatter inflation_rate unemployment_rate if covid == 0 & item_name == "All items", ms(Oh) msize(small) mcol(blue)) ///
|| (scatter inflation_rate unemployment_rate if covid == 1 & item_name == "All items", ms(Oh) msize(small) mcol(green)) ///
|| (scatter inflation_rate unemployment_rate if covid == 2 & item_name == "All items", ms(Oh) msize(small) mcol(red)), ///
title("Figure 1: The Phillips Correlation Across US Cities") ytitle("12-month Inflation Rate") legend( rows(1) label (1 "pre-COVID") label (2 "COVID") label (3 "post-COVID"))

graph export "$results_path/BLS_CPI_LAUS_covid_allitems.png", as(png) replace



