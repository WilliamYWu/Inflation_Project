/*==========================================

Merges the files and calculates simple statistics

Last modified: AK (2/15/2023)	
===========================================*/
clear all

capture log close

******************************
* 1) Combine weekly data files
******************************

*global main_path "C:/Users/`c(username)'/OneDrive - Drexel University/Safegraph"		//WW's path
global main_path "/Users/`c(username)'/Library/CloudStorage/OneDrive-DrexelUniversity/Data/Safegraph"		//AK's path
global data_path "$main_path/SG_Data"
global raw_data "$data_path/Raw-release-2022-04-15/spend_patterns/Weekly"
global processed_data "$data_path/Processed"			
cd "$raw_data"

local file_list : dir "`c(pwd)'" files "spend_w*.dta"
di `"`file_list'"'

tempfile tmp
save `tmp', replace empty

forv w = 0/116 {
	qui: use spend_w`w', clear			
	gen week = `w'
	append using `tmp'
	save `tmp', replace	
}

compress
save "$processed_data/weekly_dta_combined.dta", replace


******************************************************
* 2) Merge time-invariant characteristics for each POI
******************************************************

use "$processed_data/weekly_dta_combined.dta", clear
describe
* 1.735 distinct POIs over the 117 week period  
distinct placekey

egen id = group(placekey)
xtset id week
xtdescribe

* Merge with time-invariant POI info (county code etc, naics code)
merge m:1 placekey using "$raw_data/POIs_time_invariant_vars.dta", keepusing(naics_code county_fips opened_on closed_on)		// some POIs in this dataset are not in the master file...weird since POIs_time_invariant_vars is created from POIs in master file
gen naics2 = floor(naics_code/1e4)
drop naics_code

save "$processed_data/weekly_dta_combined.dta", replace


* Construct balanced panel of POIs that have spending data in every week 
bysort placekey (week): drop if _N < 117
* 363k distince POIs track across the whole dataset -- the majority of POIs with missing data starts in week 14 (=mid-march 2020)
distinct placekey
xtset id week
xtdescribe

save "$processed_data/weekly_balanced.dta", replace
