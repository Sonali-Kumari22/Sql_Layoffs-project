-- SQL Project - Data Cleaning

SELECT * 
FROM layoffs.layoffs;

-- created a staging table. 
CREATE TABLE layoffs.layoffs_staging 
LIKE layoffs.layoffs;

INSERT layoffs_staging 
SELECT * FROM layoffs.layoffs;


-- 1. Removing Duplicates


SELECT *
FROM layoffs.layoffs_staging
;

SELECT company, industry, total_laid_off,`date`,stage, country, funds_raised_millions,
		ROW_NUMBER() OVER (
			PARTITION BY company, industry, total_laid_off,`date`) AS row_num
	FROM 
		layoffs.layoffs_staging;
        
SELECT *
FROM (
	SELECT company, industry, total_laid_off,`date`,
		ROW_NUMBER() OVER (
			PARTITION BY company, industry, total_laid_off,`date`
			) AS row_num
	FROM 
		layoffs.layoffs_staging
) duplicates
WHERE 
	row_num > 1;
    
    
    WITH duplicate_CTE AS 
(
	SELECT *,
			ROW_NUMBER() OVER (
			PARTITION BY company, location, industry, total_laid_off,percentage_laid_off,`date`, stage, country, funds_raised_millions
			) AS row_num
	FROM 
		layoffs.layoffs_staging
)
DELETE
FROM duplicate_CTE
WHERE row_num > 1
;
    
    
    CREATE TABLE `layoffs`.`layoffs_staging2` (
`company` text,
`location`text,
`industry`text,
`total_laid_off` INT,
`percentage_laid_off` text,
`date` text,
`stage`text,
`country` text,
`funds_raised_millions` int,
row_num INT
);

INSERT INTO `layoffs`.`layoffs_staging2`
(`company`,`location`,`industry`,`total_laid_off`,`percentage_laid_off`,`date`,`stage`,`country`,`funds_raised_millions`,`row_num`)
SELECT `company`,`location`,`industry`,`total_laid_off`,`percentage_laid_off`,`date`,`stage`,`country`,`funds_raised_millions`,
		ROW_NUMBER() OVER (
			PARTITION BY company, location, industry, total_laid_off,percentage_laid_off,`date`, stage, country, funds_raised_millions
			) AS row_num
	FROM 
		layoffs.layoffs_staging;
        


-- now that we have this we can delete rows were row_num is greater than 2

DELETE FROM layoffs.layoffs_staging2
WHERE row_num >= 2;

 SELECT *  from layoffs.layoffs_staging2;
 
 -- 2. Standardize Data
 
  SELECT *  from layoffs.layoffs_staging2;
  
  -- if we look at industry it looks like we have some null and empty rows, let's take a look at these
  SELECT DISTINCT industry
  FROM layoffs.layoffs_staging2
  ORDER BY 1;
  
SELECT company, TRIM(company)
FROM layoffs.layoffs_staging2;

UPDATE layoffs.layoffs_staging2
SET company =  TRIM(company);

SELECT *
  FROM layoffs.layoffs_staging2
WHERE industry LIKE 'Crypto%';

UPDATE layoffs.layoffs_staging2
SET industry = 'Crypto'
WHERE industry LIKE 'Crypto%';

SELECT DISTINCT country
FROM layoffs.layoffs_staging2
ORDER BY 1;


UPDATE layoffs.layoffs_staging2
SET country = TRIM(TRAILING '.'  FROM country)
WHERE country LIKE 'United States%';

SELECT `date`,
STR_TO_DATE(`date`,'%m/%d/%Y')
FROM layoffs.layoffs_staging2;

UPDATE layoffs.layoffs_staging2
SET `date` = STR_TO_DATE(`date`,'%m/%d/%Y');

ALTER TABLE layoffs.layoffs_staging2
MODIFY COLUMN  `date` DATE;


-- 3. Look at Null Values
UPDATE layoffs.layoffs_staging2
SET industry =  NULL
WHERE industry = '';

SELECT * 
FROM layoffs.layoffs_staging2
WHERE industry IS NULL
OR industry = '';

SELECT * 
FROM layoffs.layoffs_staging2
WHERE company = 'Airbnb';

SELECT * 
FROM layoffs.layoffs_staging2 t1
JOIN  layoffs.layoffs_staging2 t2
  ON t1.company = t2.company
WHERE t1.industry IS NULL
AND t2.industry IS NOT NULL;

UPDATE layoffs.layoffs_staging2 t1
JOIN  layoffs.layoffs_staging2 t2
    ON t1.company = t2.company
SET t1.industry = t2.industry
WHERE t1.industry IS NULL
AND t2.industry IS NOT NULL;

-- 4. remove any columns and rows we need to
    
    
SELECT *
FROM layoffs.layoffs_staging2
WHERE total_laid_off IS NULL
AND percentage_laid_off IS NULL;

-- Delete Useless data we can't really use
DELETE FROM layoffs.layoffs_staging2
WHERE total_laid_off IS NULL
AND percentage_laid_off IS NULL;

SELECT * 
FROM layoffs.layoffs_staging2;

ALTER TABLE layoffs_staging2
DROP COLUMN row_num;


SELECT * 
FROM layoffs.layoffs_staging2;
