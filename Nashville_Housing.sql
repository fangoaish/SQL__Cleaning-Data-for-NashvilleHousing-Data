/*

Cleaning Data in SQL Queries

*/

USE NashvilleHousing;
SELECT * FROM NashvilleHousing.`nashville _housing`;


-- Standardize Date Format

SELECT SaleDate, STR_TO_DATE(SaleDate, '%M %d,%Y') AS SaleDate_Converted
FROM NashvilleHousing.`nashville _housing`;

ALTER TABLE NashvilleHousing.`nashville _housing`
ADD COLUMN SaleDate_Converted DATE AFTER SaleDate;

UPDATE NashvilleHousing.`nashville _housing`
SET SaleDate_Converted = STR_TO_DATE(SaleDate, '%M %d,%Y');


-- Populate Property Address data
-- Use self-join to populate the PropertyAddress with ParcelID; however, UniqueID needs to be different to indicate its different row
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


-- Replace the missing values in the PropertyAddress column with the addresses associated with the corresponding ParcelID.
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


-- Add new columns to stored the seperated address data
ALTER TABLE NashvilleHousing.`nashville _housing`
ADD COLUMN PropertySplitCity VARCHAR (255) AFTER PropertyAddress, 
ADD COLUMN PropertySplitAddress VARCHAR (255) AFTER PropertyAddress, 
ADD COLUMN OwnerSplitState VARCHAR (255) AFTER OwnerAddress, 
ADD COLUMN OwnerSplitCity VARCHAR (255) AFTER PropertyAddress, 
ADD COLUMN OwnerSplitAddress VARCHAR (255) AFTER PropertyAddress;

-- Populate the newly added columns with Address data
UPDATE NashvilleHousing.`nashville _housing`
SET
PropertySplitCity = SUBSTRING_INDEX(PropertyAddress, ',', 1),
PropertySplitAddress = SUBSTRING_INDEX(PropertyAddress, ',', -1),
OwnerSplitState = SUBSTRING_INDEX(OwnerAddress, ',', -1),
OwnerSplitCity = SUBSTRING_INDEX(SUBSTRING_INDEX(OwnerAddress, ',', 2), ',', -1),
OwnerSplitAddress = SUBSTRING_INDEX(OwnerAddress, ',', 1);

-- check the newly added columns
SELECT 
	PropertySplitCity,
	PropertySplitAddress,
	OwnerSplitState,
	OwnerSplitCity,
	OwnerSplitAddress
FROM NashvilleHousing.`nashville _housing`;

-- Change Y and N to Yes and No in "Sold as Vacant" field
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

SELECT DISTINCT SoldAsVacant, COUNT(SoldAsVacant) AS numbers
FROM NashvilleHousing.`nashville _housing`
GROUP BY 1
ORDER BY 2 DESC;


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

-- Save the Processed table
SELECT *
FROM NashvilleHousing.`nashville _housing`
COMMIT;