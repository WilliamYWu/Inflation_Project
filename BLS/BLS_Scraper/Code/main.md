---
jupyter:
  jupytext:
    text_representation:
      extension: .md
      format_name: markdown
      format_version: '1.3'
      jupytext_version: 1.14.4
  kernelspec:
    display_name: Python 3
    language: python
    name: python3
---

# **BLS CPI Data Scraper**

Description: This will pull Urban Consumer CPI  and LAUS Data from BLS using its json based API.

Below are some references for the CPI Data:

* [FUll ID CREATION](https://www.bls.gov/help/hlpforma.htm#CU)
* [AREA CODES](https://download.bls.gov/pub/time.series/cu/cu.area)
* [ITEM CODES](https://download.bls.gov/pub/time.series/cu/cu.item)
* [MANUAL DOWNLOAD](https://www.bls.gov/cpi/data.htm)
* [API INFORMATION](https://www.bls.gov/developers/api_faqs.htm#register1)

Below are some references for the LAUS Data:
* [FUll ID CREATION](https://www.bls.gov/help/hlpforma.htm#LA)
* [AREA TYPE](https://download.bls.gov/pub/time.series/la/la.area_type)
* [AREA CODES](https://download.bls.gov/pub/time.series/la/la.area)
* [MEASURE CODE](https://download.bls.gov/pub/time.series/la/la.measure)


# Section 1: Setup

1. Packages
2. Directories
3. Helper Functions
4. Setup Functions


## Section 1.1: Packages

```python
from datetime import datetime
import logging
import os
import logging.handlers

import time
import requests
import json
import re
import csv
import pandas as pd
```

## Section 1.2: Directories

```python
# NOTE: All directories the program used should be included as a global variable here
MAIN_DIR =  "D:\\Code\\PYTHON\\BLS_SCRAPER\\"
DATA_DIR = MAIN_DIR + f"Data\\"

CPI_DATA_DIR = DATA_DIR + f"CPI\\"
LAUS_DATA_DIR = DATA_DIR + f"LAUS\\"
FINAL_CPI_DATA_DIR = CPI_DATA_DIR + "Final\\"
FINAL_LAUS_DATA_DIR = LAUS_DATA_DIR + "Final\\"

# NOTE: Automatic Log Folder directory creation based on date.
# NOTE: The file iteself is created based on the time. 
LOG_DIR = MAIN_DIR + f"Log\\{datetime.now().strftime('%Y%m%d')}\\" 
LOG_FILE = LOG_DIR + f"Log_{datetime.now().strftime('%H%M%S')}.log"
```

## Section 1.3: Helper Functions

```python
def directory_setup(dir_list):
    '''
    DESCRIPTION -> If the directory does not exist it will create it
    '''
    for directory in dir_list:
        if not os.path.exists(directory):
            os.makedirs(directory)

def logging_setup():
    '''
    DESCRIPTION -> Setups the logging file for code
    '''
    try:
      handler = logging.handlers.WatchedFileHandler(os.environ.get("LOGFILE", LOG_FILE))
      formatter = logging.Formatter(fmt="%(asctime)s %(levelname)-8s %(message)s", datefmt="%Y-%m-%d %H:%M:%S")
      handler.setFormatter(formatter)
      logging.getLogger().handlers.clear()
      root = logging.getLogger()
      root.setLevel(os.environ.get("LOGLEVEL", "INFO"))
      root.addHandler(handler)
      logging.propogate = False
      logging.info("Log File was created successfully.")
    except Exception as e:
        exit
```

```python
# NOTE: All steps regrading setup should be completed here
DIR_LIST = [MAIN_DIR, LOG_DIR, DATA_DIR, CPI_DATA_DIR, LAUS_DATA_DIR, FINAL_CPI_DATA_DIR, FINAL_LAUS_DATA_DIR]
directory_setup(DIR_LIST)
logging_setup()
```

# Section 2: BLS Scraping Class

Description: This is the main method used to scrape the information off of BLS.

Contains the methods
* get_data
* process_data

```python
class bls_data_scraper:
    '''
    ------------------------------------------------------------------------------------------------------------
    -----------------------------------------------DESCRIPTION--------------------------------------------------
    ------------------------------------------------------------------------------------------------------------

    Passes the BLS json request and gets the data. 
    Afterwards it processes the data and enriches the data with some additional information about area and item names.

    ------------------------------------------------------------------------------------------------------------
    -----------------------------------------------PARAMETERS---------------------------------------------------
    ------------------------------------------------------------------------------------------------------------
    api_key -> API_KEY for BLS data queries
    out_file -> Location for Data to be outputted
    series_id -> All the series of CPI data that you want
    start_year -> Query start range
    end_year -> Query end range
    area_df -> Dataframe containing information on metro area codes and names
    item_df -> Dataframe containing information on item codes and names
    cpi_check -> If 1 then this is for CPI. If 0 then this is for LAUS.
    '''
    def __init__(self, api_key, out_file, series_id, start_year, end_year, area_df, item_df, cpi_check):
        headers = {"Content-type": "application/json"}
        parameters = json.dumps({
                                "seriesid":series_id, 
                                "startyear":start_year, 
                                "endyear":end_year, 
                                "registrationkey":api_key,
                                "calculations": True
                                })
        self.area_df = area_df
        self.item_df = item_df
        self.cpi_check = cpi_check
        # Requests the data from BLS
        json_data = self.get_data(headers, parameters)
        # Processes the data from BLS
        df_data = self.process_data(json_data, area_df, item_df, cpi_check)

        # Converts the data to an array to write -> Need to do this so that we have a single header
        list_df_data = df_data.values.tolist()

        # Writes the cleaned up data into the specified out_file
        with open(out_file , "a") as file:
            headers = df_data.columns.tolist()
            writer = csv.writer(file, delimiter=',', lineterminator='\n')
            if os.stat(out_file).st_size==0:
                writer.writerow(headers)
            for row in list_df_data:
                writer.writerow(row)


    def get_data(self, headers, parameters):
        '''
        DESCRIPTION -> Posts the url and we get the data back in a json format

        PARAM 1 -> headers -> self.header a BLS API requirement
        PARAM 2 -> parameters -> The data specification that you plan on querying
        '''
        post = requests.post('https://api.bls.gov/publicAPI/v2/timeseries/data/', data=parameters, headers=headers)
        json_data = json.loads(post.text)
        return json_data
    

    def process_data(self, json_data, area_df, item_df, cpi_check):
        '''
        DESCRIPTION -> Cleans and enriches the JSON data that we just processed

        PARAM 1 -> json_data -> The raw JSON data we pulled from BLS
        PARAM 2 -> area_df -> The area code and name information
        PARAM 3 -> item_df -> The item code and name information
        '''

        # NOTE: A lot of the data is stored inside multi-layed dictionaries/lists
        # All the information is stored under a three layer depth
        df = pd.json_normalize(json_data, record_path=["Results", "series", "data"], meta=[["Results", "series", "seriesID"]])
        df.rename(columns = {"Results.series.seriesID":"ID"}, inplace = True)

        if cpi_check == 1:
            # Parsing out the area_code and item_code from the entirety of the ID that we generated
            df["area_code"] = df["ID"].apply(lambda x: x[4:8])
            df["item_code"] = df["ID"].apply(lambda x: x[8:])

            # Enriching the data here
            df = pd.merge(df, area_df, how="left", on="area_code")
            df = pd.merge(df, item_df, how="left", on="item_code")
            df.drop(columns=["area_code", 
                             "item_code", 
                             "footnotes",
                             "calculations.pct_changes.1",
                             "calculations.pct_changes.3",
                             "calculations.pct_changes.6"], inplace=True, errors="ignore")

            # # rearrange column ordering
            # name_list = df.columns.tolist()
            # name_list = name_list[-3:-2] + name_list[-2:-1] + name_list[-1:] + name_list[:-3]
            # df = df[name_list]
        else:
            # We don't need the calculation net changes for LAUS Data
            df["area_code"] = df["ID"].apply(lambda x: x[3:18])
            df = pd.merge(df, area_df, how="left", on="area_code")
            df.drop(columns=["latest", 
                             "footnotes", 
                             "period", 
                             "type_code", 
                             "area_name", 
                             "calculations.net_changes.1",
                             "calculations.net_changes.3",
                             "calculations.net_changes.6",
                             "calculations.net_changes.12",
                             "calculations.pct_changes.1",
                             "calculations.pct_changes.3",
                             "calculations.pct_changes.6",
                             "calculations.pct_changes.12"], inplace=True, errors="ignore")
        return df
```

# Section 3: BLS CPI Area and Item & LAUS Area Information Scraper

1. bls_code_scraper function 
2. Get and Filter the Information
3. Match the Filtered Codes to LAUS Data
4. Generate List of BLS Codes from Filtered Data


## Section 3.1: Scrape BLS ID Information

```python
def bls_id_scraper(url, file_dir):
    '''
    DESCRIPTION -> Scrapes textual information off of BLS links for CPI and LAUS

    PARAM 1 -> file_dir -> Where you want to write the raw_information
    '''

    response = requests.get(url)
    content = response.content.decode("utf-8")
    area_content = csv.reader(content.splitlines(), delimiter="\t")
    area_list = list(area_content)

    # n is the number of elements that we want to remove from the back of the list
    n = 3
    # Writing the uncleaned relavant information into file 
    with open(file_dir, "w") as file:
        writer = csv.writer(file)
        for row in area_list:
            row = row[: len(row) - n]
            writer.writerow(row)
    file.close()
```

## Section 3.2: Get and Filter the Information

```python
# Scraping the CPI area code information
bls_id_scraper("https://download.bls.gov/pub/time.series/cu/cu.area", f"{CPI_DATA_DIR}\\raw_area.csv")
# Scraping the CPI item code information
bls_id_scraper("https://download.bls.gov/pub/time.series/cu/cu.item", f"{CPI_DATA_DIR}\\raw_item.csv")
# Scraping the LAUS area code information
bls_id_scraper("https://download.bls.gov/pub/time.series/la/la.area", f"{LAUS_DATA_DIR}\\raw_area.csv")
```

```python
cpi_area_df = pd.read_csv(f"{CPI_DATA_DIR}\\raw_area.csv")
cpi_item_df = pd.read_csv(f"{CPI_DATA_DIR}\\raw_item.csv")

"""
------------------------------AREA FILTERS-----------------------------------------
"""

'''
Filter: Filter for S area_code, since we only want metro area codes
'''
cpi_area_df["code_check"] = cpi_area_df["area_code"].apply(lambda x: "Pass" if re.match("S[A-Z0-9]{3}", x) else "Fail")
cpi_area_df = cpi_area_df[cpi_area_df["code_check"] == "Pass"]

'''
Filter: Remove the area_names that have Size Class A in their name. Those are irrelavent.
'''
cpi_area_df["name_check"] = cpi_area_df["area_name"].apply(lambda x: "Pass" if "Size Class A" not in x else "Fail")
cpi_area_df = cpi_area_df[cpi_area_df["name_check"] == "Pass"]

"""
------------------------------ITEM FILTERS-----------------------------------------
"""

'''
Filter: Filter that selects only those at the aggregate: all items, all items less food, and all items less food and energy
'''
cpi_item_df["code_check"] = cpi_item_df["item_code"].apply(lambda x: "Pass" if re.match("SA0[^R;]*", x) else "Fail")
cpi_item_df = cpi_item_df[cpi_item_df["code_check"] == "Pass"]

'''
Filter: Only include item_codes that have a shorter length than 4 since those are the more aggregated values.
'''
# cpi_item_df["code_check"] = cpi_item_df["item_code"].apply(lambda x: "Pass" if len(x)<4 else "Fail")
# cpi_item_df = cpi_item_df[cpi_item_df["code_check"] == "Pass"]

'''
Filter: If the item_name contains All Items we remove since those are too aggregated
'''
# cpi_item_df["name_check"] = cpi_item_df["item_name"].apply(lambda x: "Pass" if not re.match("All items [a-zA-Z\s,]*",x) else "Fail")
# cpi_item_df = cpi_item_df[cpi_item_df["name_check"] == "Pass"]

cpi_area_df.drop(columns=["code_check", "name_check"], inplace=True)
cpi_item_df.drop(columns=["code_check"], inplace=True)

cpi_area_df.to_csv(f"{CPI_DATA_DIR}\\clean_area.csv", index=False)
cpi_item_df.to_csv(f"{CPI_DATA_DIR}\\clean_item.csv", index=False)
```

## Section 3.3: Match the Filtered Codes to LAUS Data

Depending on the remaining codes in area code we will create their respective LAUS codes based on the pre-comma area_text/area_name.

```python
# WARNING: Further processing is needed for the cpi_area_df. There are discrepancies between the identifier in that and whats available in the cpi_area_df
# WARNING: Check on Boston later it might have a parsing issue as well
cpi_area_df["laus_check"] = cpi_area_df["area_name"].apply(lambda x: x.split(",")[0].replace(" ",""))

'''
Filter: Remove the urban tag for both Hawaii and Alaska ex.) Urban Hawaii -> Hawaii
'''
cpi_area_df["laus_check"] = cpi_area_df["laus_check"].apply(lambda x: x.replace("Urban","") if re.match("Urban[A-Za-z]+", x) else x)

'''
Filter: Remove WA from the filter, since it didn't split properly without the comma that was supposed to be there. Thank you BLS.
'''
cpi_area_df["laus_check"] = cpi_area_df["laus_check"].apply(lambda x: x.replace("WA","") if re.match("Seattle-Tacoma-BellevueWA", x) else x)

laus_area_df = pd.read_csv(f"{LAUS_DATA_DIR}\\raw_area.csv")
# Create the same format laus_check as what you did for the cpi_area_df so that you can merge it.
laus_area_df["laus_check"] = laus_area_df["area_text"].apply(lambda x: x.split(",")[0].replace(" ", ""))
laus_merge_df = pd.merge(cpi_area_df, laus_area_df, how="left", on="laus_check")

laus_merge_df.drop(columns=["area_code_x", "area_name",], inplace=True)
laus_merge_df.rename(columns={"area_type_code":"type_code", "area_code_y":"area_code", "area_text":"area_name"}, inplace=True)

'''
Filter: Removing those that have an area_type other than B Metropolitan Areas
'''
laus_merge_df.drop(laus_merge_df[laus_merge_df["type_code"] != "B"].index, inplace=True)

laus_merge_df.to_csv(f"{LAUS_DATA_DIR}\\clean_area.csv", index=False)

```

## Section 3.4: Generate List of BLS CPI Codes from Filtered Data

```python
"""
Here is a sample of how the BLS creates the unique identifier. You can find more information on it here (https://www.bls.gov/help/hlpforma.htm#id=CU).

	Series ID    CUUR0000SA0L1E
	Positions       Value           Field Name
	1-2             CU              Prefix
	3               U               Not Seasonal Adjustment Code
	4               R               Periodicity Code
	5-8             0000            Area Code
	9               S               Base Code
	10-16           A0L1E           Item Code
"""
cpi_code_list = []
# Consumer Price Index - All Urban Consumers
prefix = "CU"
# This dataset does not have any seasonally adjusted data
seasonality = "U"
# R stands for monthly
periodicity = "R"
for area in cpi_area_df["area_code"]:
    for item in cpi_item_df["item_code"]:
        cpi_code_list.append(f"{prefix}{seasonality}{periodicity}{str(area)}{str(item)}")
logging.info(f"Total Unique CPI Codes: {len(cpi_code_list)}")
```

## Section 3.5: Generate List of BLS LAUS Codes from Filtered Data

```python
'''
	Series ID    LAUCN281070000000003
	Positions    Value            Field Name
	1-2          LA               Prefix
	3            U                Seasonal Adjustment Code
	4-18         CN2810700000000  Area Code
	19-20        03               Measure Code
'''

laus_code_list = []
# Local Area Unemployment
prefix = "LA"
# Seasonality Adjustment
seasonality = "U"
# area code and measure code
measure_code = "03"

laus_code_list = []
for laus_area_code in laus_merge_df["area_code"]:
    laus_code_list.append(f"{prefix}{seasonality}{laus_area_code}{measure_code}")
logging.info(f"Total Unique LAUS Codes: {len(laus_code_list)}")
```

# Section 4: Main

1. Setup For API Calls
2. Function for Checking File Existence
3. BLS CPI API Call 
4. BLS LAUS API Call
5. Merging Our Datasets Together


## Section 4.1: Setup For API Calls

```python
'''
--------- KEY FEATURES/LIMITATIONS OF API ----------
Limit of 500 calls per key.
Can make 50 calls every query.
20 years per query
'''
# Drexel API Key: "024f5a0ca6e7494cbec2ea4088cd4a9d"
# GMAIL API Key: "73df4bb81189431089fe2f247af35ce1"
api_key = "024f5a0ca6e7494cbec2ea4088cd4a9d"
start_year_1 = 1990
end_year_1 = 2005
start_year_2 = 2006
end_year_2 = 2022
```

## Section 4.2: Function for Checking File Existence

```python
def file_existance(file_paths):
    for file_path in file_paths:
        if os.path.exists(file_path):
            try:
                os.remove(file_path)
                logging.info("Removed old file for data.")
            except:
                logging.info("Did not remove old file for data.")
```

## Section 4.3: BLS CPI API Call

```python
'''
-----------------BLS CPI API CALLS HERE--------------------
'''

file_existance([f"{FINAL_CPI_DATA_DIR}\\bls_cpi_data_p1.csv", f"{FINAL_CPI_DATA_DIR}\\bls_cpi_data_p2.csv"])
for x in range(0, len(cpi_code_list), 50):
    code_chunk = cpi_code_list[x:x+50]
    bls_data_scraper(api_key, f"{FINAL_CPI_DATA_DIR}\\bls_cpi_data_p1.csv", code_chunk, start_year_1, end_year_1, cpi_area_df, cpi_item_df,1)
    bls_data_scraper(api_key, f"{FINAL_CPI_DATA_DIR}\\bls_cpi_data_p2.csv", code_chunk, start_year_2, end_year_2, cpi_area_df, cpi_item_df,1)
    time.sleep(2)
logging.info("Done with BLS CPI API Calls")
```

## Section 4.4: BLS LAUS API Call

```python
file_existance([f"{FINAL_LAUS_DATA_DIR}\\bls_laus_data_p1.csv", f"{FINAL_LAUS_DATA_DIR}\\bls_laus_data_p2.csv"])
# NOTE: Technically we don't need to make an exception for the LAUS dataset. However, since we only have one item this just makes life easier. 
# NOTE: If we wanted to though, this could just be one general method that works for both cases.
for x in range(0, len(laus_code_list), 50):
    code_chunk = laus_code_list[x:x+50]
    bls_data_scraper(api_key, f"{FINAL_LAUS_DATA_DIR}\\bls_laus_data_p1.csv", code_chunk, start_year_1, end_year_1, laus_merge_df,0,0)
    bls_data_scraper(api_key, f"{FINAL_LAUS_DATA_DIR}\\bls_laus_data_p2.csv", code_chunk, start_year_2, end_year_2, laus_merge_df,0,0)
    time.sleep(2)
logging.info("Done with BLS LAUS API Calls")
```

## Section 4.5: Merging Our Datasets Together

```python
cpi_merge = pd.concat([pd.read_csv(f"{FINAL_CPI_DATA_DIR}\\bls_cpi_data_p1.csv"), pd.read_csv(f"{FINAL_CPI_DATA_DIR}\\bls_cpi_data_p2.csv")])
laus_merge = pd.concat([pd.read_csv(f"{FINAL_LAUS_DATA_DIR}\\bls_laus_data_p1.csv"), pd.read_csv(f"{FINAL_LAUS_DATA_DIR}\\bls_laus_data_p2.csv")])

cpi_merge.to_csv(f"{FINAL_CPI_DATA_DIR}\\bls_cpi_data_cmb.csv", index=False)
laus_merge.to_csv(f"{FINAL_LAUS_DATA_DIR}\\bls_laus_data_cmb.csv", index=False)
```
