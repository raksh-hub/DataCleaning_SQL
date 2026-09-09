-- SOURCE : Kaggle
-- https://www.kaggle.com/datasets/tmthyjames/nashville-housing-data
-- ================================
-- nashville housing data cleaning
-- =================================



-- date check and formatting it correctly
SELECT
    SaleDate,
    STR_TO_DATE(SaleDate, '%M %e, %Y') AS SaleDateConverted
FROM NashvilleHousing;


-- convert the sale date from text into a proper date value
UPDATE NashvilleHousing
SET SaleDate = STR_TO_DATE(SaleDate, '%M %e, %Y');


-- changing the column type to DATE
ALTER TABLE NashvilleHousing
MODIFY SaleDate DATE;


-- check that the column was converted correctly
DESCRIBE NashvilleHousing;



-- --------------------------------
-- 2. fixing typos/inconsistent values
-- ---------------------------

-- landuse column

select landuse
from NashvilleHousing
group by landuse
order by landuse;

UPDATE NashvilleHousing
SET LandUse = 'VACANT RESIDENTIAL LAND'
WHERE LandUse = 'VACANT RES LAND';

UPDATE NashvilleHousing
SET LandUse = 'VACANT RESIDENTIAL LAND'
WHERE LandUse = 'VACANT RESIENTIAL LAND';




-- ---------------------------
-- 3. cleaning soldasvacant values
-- ---------------------------

-- replace y/n with yes/no so the column is easier to read and consistent
UPDATE NashvilleHousing
SET SoldAsVacant =
    CASE
        WHEN SoldAsVacant = 'Y' THEN 'Yes'
        WHEN SoldAsVacant = 'N' THEN 'No'
        ELSE SoldAsVacant
    END;




-- ----------------------------------
-- 4. finding missing property addresses and populating wherever possible
-- -----------------------------------

-- another record with the same parcelid has an address
SELECT
    n1.ParcelID,
    n1.PropertyAddress,
    n2.ParcelID,
    n2.PropertyAddress,
    COALESCE(n2.PropertyAddress, n1.PropertyAddress)
FROM NashvilleHousing n1
JOIN NashvilleHousing n2
    ON n1.ParcelID = n2.ParcelID
    AND n1.UniqueID <> n2.UniqueID
WHERE n2.PropertyAddress IS NULL
  AND n1.PropertyAddress IS NOT NULL;

-- populate the missing property addresses
START TRANSACTION; -- for precaution if mistakes happpen

UPDATE NashvilleHousing n2
JOIN NashvilleHousing n1
    ON n1.ParcelID = n2.ParcelID
    AND n1.UniqueID <> n2.UniqueID
SET n2.PropertyAddress = n1.PropertyAddress
WHERE n2.PropertyAddress IS NULL
  AND n1.PropertyAddress IS NOT NULL;

-- ROLLBACK;
COMMIT;




-- -------------------
-- 5. cleaning sale price
-- ---------------------

-- check for sale prices containing characters other than numbers
SELECT SalePrice
FROM NashvilleHousing
WHERE SalePrice REGEXP '[^0-9]';


START TRANSACTION; 

-- remove , and the 'us$' prefix
UPDATE NashvilleHousing
SET SalePrice = REPLACE(
                    REPLACE(SalePrice, ',', ''),
                    'US$',''
                    );

-- trimming extra white space
UPDATE NashvilleHousing
SET SalePrice = TRIM(SalePrice);

COMMIT;

-- convert saleprice into a numeric column

ALTER TABLE NashvilleHousing
MODIFY SalePrice INT;




-- ----------------------------------------
-- 6. splitting property address into street and city
-- -----------------------------------------

-- checking the address split before adding the new columns
SELECT
    PropertyAddress,
    SUBSTRING(
        PropertyAddress,
        1,
        LOCATE(',', PropertyAddress) - 1
    ) AS StreetAdd,
    SUBSTRING(
        PropertyAddress,
        LOCATE(',', PropertyAddress) + 1
    ) AS City
FROM NashvilleHousing;


-- add separate columns for street address and city
ALTER TABLE NashvilleHousing
ADD COLUMN StreetAdd VARCHAR(255),
ADD COLUMN City VARCHAR(100);


-- populate the created columns
UPDATE NashvilleHousing
SET
    StreetAdd = SUBSTRING(
        PropertyAddress,
        1,
        LOCATE(',', PropertyAddress) - 1
    ),
    City = SUBSTRING(
        PropertyAddress,
        LOCATE(',', PropertyAddress) + 1
    );




-- ------------------------
-- 7. splitting owner address
-- ---------------------------

-- checking the owner address split
SELECT
    OwnerAddress,
    SUBSTRING_INDEX(OwnerAddress, ',', 1) AS StreetAddress,
    SUBSTRING_INDEX(
        SUBSTRING_INDEX(OwnerAddress, ',', 2), -- string
        ',',-- delimiter
        -1 -- picks from behind
    ) AS City,
    SUBSTRING_INDEX(OwnerAddress, ',', -1) AS State
FROM NashvilleHousing;


-- add separate columns for the owner address
ALTER TABLE NashvilleHousing
ADD COLUMN Owner_StreetAdd VARCHAR(255) AFTER OwnerAddress ,
ADD COLUMN Owner_City VARCHAR(255) AFTER Owner_StreetAdd ,
ADD COLUMN Owner_State VARCHAR(255) AFTER Owner_City;


-- populating new created columns
UPDATE NashvilleHousing
SET
    Owner_StreetAdd = SUBSTRING_INDEX(OwnerAddress, ',', 1),
    Owner_City = SUBSTRING_INDEX(
        SUBSTRING_INDEX(OwnerAddress, ',', 2),
        ',',
        -1
    ),
    Owner_State = SUBSTRING_INDEX(OwnerAddress, ',', -1);





-- ---------------------------
-- 8. removing duplicate records
-- -------------------------------

-- find duplicate records based on the columns below

START TRANSACTION; 

WITH RowNumCte AS
(
    SELECT
        UniqueID,
        ROW_NUMBER() OVER (
            PARTITION BY
                ParcelID,
                PropertyAddress,
                SaleDate,
                SalePrice,
                LegalReference
            ORDER BY UniqueID
        ) AS row_num
    FROM NashvilleHousing
)

-- delete everything except the first record in each duplicate group

DELETE FROM NashvilleHousing
WHERE UniqueID IN
(
    SELECT UniqueID
    FROM RowNumCte
    WHERE row_num > 1
);

COMMIT;




-- --------------------------------------
-- 9. removing columns that are might not be needed(personal project purpose onlyy)
-- ------------------------------------

-- these columns have already been split into separate fields which are no longer needed
ALTER TABLE NashvilleHousing
DROP COLUMN OwnerAddress,
DROP COLUMN PropertyAddress,
DROP COLUMN TaxDistrict;

