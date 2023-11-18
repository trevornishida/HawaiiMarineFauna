# Hawaii Marine Fauna List
This repository contains a list of Marine Fauna localized to the [Hawaii Exclusive Economic Zone](https://www.marineregions.org/gazetteer.php?p=details&id=8453) along with the code used to update taxonomy and consolidate species across all data sources.

## Data Sources
A number of sources were used to compile this list:
- The Bishop Museum's Marine Invertebrates of the Hawaiian Islands Checklist was the primary source we used which can be accessed [here](http://www2.bishopmuseum.org/HBS/invert/taxa_summary.htm).
- Invert-E-Base's Marine Invertebrates of Kaneohe Bay Checklist found [here](https://invertebase.org/portal/checklists/checklist.php?clid=14&dynclid=0&pid=6).
- Ocean Biodiversity Information System's (OBIS) records for the Hawaii Exclusive Economic Zone hosted [here](https://mapper.obis.org/?areaid=268#).
- Lifewatch's records for the Hawaii Exclusive Economic Zone hosted [here](https://rshiny.vsc.lifewatch.be/standardized_distributions/#tab-7315-2).
- ARMS Data
- Various Professionals in their respective fields

## Processing Bishop Museum's Species Checklist
The Bishop Museum list used as the primary source came as raw text data stored in `.htm` files. These files were last updated in 2001 according to their website. The first step in creating the list was parsing the raw text into a more user-friendly format. 
1. Extract the text data from the htm files.
2. Use Regular Expressions to extract Species names using the standard taxonomic naming scheme (*Genus species*)
3. Convert the now vectorized text data into a dataframe which can be manipulated by `tidyverse` tools.
4. Collapse Sp. and cf. entries to Genus level identification.

## Approach to Processing the Data
Once the Bishop Museum data was parsed into the dataframe format, we were then able to merge data from the supplementary sources with the primary source to produce the end result.

1. Look up taxa using the [World Registry of Marine Species](https://www.marinespecies.org/) API
2. If the taxa was found, save off a number of columns of interest from the returned data entry.
3. If the taxa wasn't found, use fuzzy searching to complete another lookup.
4. Combine fuzzy searched lookup with non-fuzzy lookup.
5. Repeat for all data sources.
6. Combine all data sources to produce a comprehensive species list of marine invertebrates for the Hawaii EEZ.

## Reproduction of Results
Almost all data and code needed to reproduce the marine invertebrate list can be found in this repository. The exception for this is the OBIS dataset which was too large to be stored in a Github repository. This dataset must be downloaded directly from their data explorer located [here](https://mapper.obis.org/?areaid=268#).

## Issues & Contact
If you find any problems with the list and/or would like to contribute in any way, please feel free to create a pull request, open an issue, or send me a message.
