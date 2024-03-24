# Cleaning Data for NashvilleHousing Data

## Project Overview: 

The project aims to clean and standardize data within the NashvilleHousing database by executing various SQL queries. The process involves several steps to enhance data quality and consistency for subsequent analysis or application usage. Below is an overview of the key tasks performed:

## Data Sources: 
The data source is from [Alex The Analyst](https://mavenanalytics.io/data-playground)

1. ### Standardize Date Format:
Converts the SaleDate column to a standardized date format for consistency and ease of analysis.

```ruby
SELECT SaleDate, STR_TO_DATE(SaleDate, '%M %d,%Y') AS SaleDate_Converted
FROM NashvilleHousing.`nashville _housing`;

ALTER TABLE NashvilleHousing.`nashville _housing`
ADD COLUMN SaleDate_Converted DATE AFTER SaleDate;

UPDATE NashvilleHousing.`nashville _housing`
SET SaleDate_Converted = STR_TO_DATE(SaleDate, '%M %d,%Y');
```

2. ### Populate Property Address Data:
Utilizes a self-join operation to populate missing property addresses based on ParcelID, ensuring each entry receives a complete address.

- Populate Property Address data
- Use self-join to populate the PropertyAddress with ParcelID; however, UniqueID needs to be different to indicate its different row

```ruby
Select 
    a.ParcelID,
    a.PropertyAddress,
    b.ParcelID,
    b.PropertyAddress,
	IF(a.PropertyAddress = '', b.PropertyAddress, NULL) AS PropertyAddressComplete
FROM NashvilleHousing.`nashville _housing` a
JOIN NashvilleHousing.`nashville _housing` b
	ON a.ParcelID = b.ParcelID
	AND a.UniqueID != b.UniqueID
WHERE a.PropertyAddress = '';
```


3. ### Break Out Addresses into Individual Columns:
Splits the PropertyAddress and OwnerAddress columns into separate components such as address, city, and state, stored in newly added columns.

- Replace the missing values in the PropertyAddress column with the addresses associated with the corresponding ParcelID.
```ruby
UPDATE NashvilleHousing.`nashville _housing` AS a
JOIN NashvilleHousing.`nashville _housing` AS b
	ON a.ParcelID = b.ParcelID
	AND a.UniqueID != b.UniqueID
SET a.PropertyAddress = IF(a.PropertyAddress = '', b.PropertyAddress, NULL)
WHERE a.PropertyAddress = '';

-- Breaking out Address into Individual Columns (Address, City, State)
SELECT
	PropertyAddress,
    SUBSTRING_INDEX(PropertyAddress, ',', 1) AS Address,
	SUBSTRING_INDEX(PropertyAddress, ',', -1) AS City
FROM NashvilleHousing.`nashville _housing`;


SELECT
	OwnerAddress,
    SUBSTRING_INDEX(OwnerAddress, ',', 1) AS Address,
    SUBSTRING_INDEX(SUBSTRING_INDEX(OwnerAddress, ',', 2), ',', -1) AS City,
    SUBSTRING_INDEX(OwnerAddress, ',', -1) AS State
FROM NashvilleHousing.`nashville _housing`;


-- Populate the newly added columns with Address data
UPDATE NashvilleHousing.`nashville _housing`
SET
PropertySplitCity = SUBSTRING_INDEX(PropertyAddress, ',', 1),
PropertySplitAddress = SUBSTRING_INDEX(PropertyAddress, ',', -1),
OwnerSplitState = SUBSTRING_INDEX(OwnerAddress, ',', -1),
OwnerSplitCity = SUBSTRING_INDEX(SUBSTRING_INDEX(OwnerAddress, ',', 2), ',', -1),
OwnerSplitAddress = SUBSTRING_INDEX(OwnerAddress, ',', 1);

-- Check the newly added columns
SELECT 
	PropertySplitCity,
	PropertySplitAddress,
	OwnerSplitState,
	OwnerSplitCity,
	OwnerSplitAddress
FROM NashvilleHousing.`nashville _housing`;
```

4. ### Change Y and N to Yes and No in "SoldAsVacant" Field:
Modifies values in the SoldAsVacant column, replacing 'Y' with 'Yes' and 'N' with 'No' for consistency and clarity.

```ruby
SELECT DISTINCT SoldAsVacant, COUNT(SoldAsVacant) AS numbers
FROM NashvilleHousing.`nashville _housing`
GROUP BY 1
ORDER BY 2 DESC;
-- Check how many unique values in SoldAsVacant column
-- We have No, Yes, N, Y in SoldAsVacant
-- will change Y and N to Yes and No since these two are the vastly more populated ones

-- Use CASE statement to rewrite it
SELECT
	SoldAsVacant,
    CASE
		WHEN SoldAsVacant = 'Y' THEN 'Yes'
        WHEN SoldAsVacant = 'N' THEN 'No'
	ELSE SoldAsVacant
    END AS SoldAsVacant_revised
    FROM NashvilleHousing.`nashville _housing`;

-- Update to the table
UPDATE NashvilleHousing.`nashville _housing`
SET SoldAsVacant = 
CASE
		WHEN SoldAsVacant = 'Y' THEN 'Yes'
        WHEN SoldAsVacant = 'N' THEN 'No'
	ELSE SoldAsVacant
    END;
```

5. ### Remove Duplicates:
Identifies and removes duplicate rows based on specific criteria, ensuring data integrity and eliminating redundant entries.

```ruby
-- Remove Duplicates
-- Disclaimer: We only drop the duplicates directly HERE in this practice. 
-- However, iin the real world, we don't delete the actual raw data. Conduct in the temp table and put the remove duplicates there

-- identify the duplicate rows
-- use ROW_NUMBER() OVER (PARTITION BY )
-- duplicate ones are those which row_num > 1
-- Method no1: Check Duplicates with nested queries
CREATE TEMPORARY TABLE Nash_Table_no_duplicates
SELECT *
From(
SELECT *,
	ROW_NUMBER() OVER (PARTITION BY ParcelID, 
									PropertyAddress, 
                                    SalePrice, 
                                    SaleDate, 
                                    LegalReference ORDER BY UniqueID) AS row_num
FROM NashvilleHousing.`nashville _housing`
) AS Nash_Table
Where row_num > 1
ORDER BY UniqueID;


-- Method no2: Check Duplicates with CTE
WITH RownumCTE AS
(
SELECT *,
	ROW_NUMBER() OVER (PARTITION BY ParcelID, 
									PropertyAddress, 
                                    SalePrice, 
                                    SaleDate, 
                                    LegalReference ORDER BY UniqueID) AS row_num
FROM NashvilleHousing.`nashville _housing`
ORDER BY ParcelID
)
SELECT * FROM RownumCTE
WHERE row_num > 1
ORDER BY UniqueID;

```


6. ### Delete Unused Columns:
Removes unused columns from the dataset, streamlining the structure and reducing redundancy.

```ruby
-- Drop Duplicates
DELETE FROM NashvilleHousing.`nashville _housing`
WHERE UniqueID IN(
SELECT UniqueID FROM Nash_Table_no_duplicates);


-- Delete Unused Columns
-- Disclaimer: We only delete unused columns directly HERE in this practice. 
-- However, iin the real world, we don't delete the actual raw data. Conduct in the temp table and create View statement
ALTER TABLE NashvilleHousing.`nashville _housing`
DROP COLUMN SaleDate,
DROP COLUMN TaxDistrict,
DROP COLUMN PropertyAddress,
DROP COLUMN OwnerAddress;
```

7. ### Save the Processed Table:
Commits the processed data back to the NashvilleHousing database, making it ready for further analysis or application integration.

```ruby
-- Save the Processed table
SELECT *
FROM NashvilleHousing.`nashville _housing`
COMMIT;
```

## Conclusion
By systematically cleaning and organizing the data through SQL queries, this project enhances the quality, consistency, and usability of the NashvilleHousing dataset, facilitating more accurate and insightful data-driven decisions.
