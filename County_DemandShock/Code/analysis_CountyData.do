/*==========================================

Merges the files and calculates simple statistics

Last modified: AK (2/15/2023)	
===========================================*/
clear all

capture log close

******************************
* 1) Combine weekly data files
******************************

global main_path "C:/Users/`c(username)'/OneDrive - Drexel University/Safegraph"		//WW's path
// global main_path "/Users/`c(username)'/Library/CloudStorage/OneDrive-DrexelUniversity/Data/Safegraph"		//AK's path
global data_path "$main_path/County_Data"
global raw_path "$data_path/Raw"
global clean_path "$data_path/Clean"
global bls_path "$main_path/BLS/BLS_Analysis/Data/Clean"
	
import delimited "$raw_path/qcew-county-msa-csa-crosswalk-csv.csv", clear
* Padding left to match fips code standards
format countycode %05.0f
save "$clean_path/county_msa_codes.dta", replace

use "$raw_path/county_demandshock_proxies.dta", clear
* Padding left to match fips code standards
format county %05.0f
rename county countycode
save "$clean_path/county_demandshock_proxies.dta", replace

* Merging to give the county_demandshock_proxies the MSA level information
merge 1:m countycode using "$clean_path/county_msa_codes.dta", keepusing(msacode msatitle) generate(merge_cc)

* Collapse hhold_income and pop_county using sum and taking the average of the rest -> Done weighted against population
collapse (sum) hhold_income pop_county (mean) week_earn_all week_earn_hs R_3 R_600_3 R_4sec R_600_4sec [aweight = pop_county], by(msatitle msacode), 
save "$clean_path/msa_county_demandshock_proxies.dta", replace

use "$clean_path/msa_county_demandshock_proxies.dta", clear
rename msatitle area_name
keep if area_name != ""

merge m:m area_name using "$bls_path/bls_cpi_laus_data.dta", generate(merge_an)
drop _merge

* Change this to covid and post-covid
keep if merge_an == 3 & item_name == "All items" & year >= 2020
sort id year month

// collapse (mean) hhold_income pop_county week_earn_all week_earn_hs R_3 R_600_3 R_4sec R_600_4sec inflation_value inflation_rate, by(id area_name)
binscatter inflation_rate hhold_income, nq(50) line(lfit)