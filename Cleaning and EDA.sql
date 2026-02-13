USE salary_portfolio_project;

SELECT *
FROM salary_raw;

-- Making staging table for changes:

CREATE TABLE IF NOT EXISTS salary_stg AS
SELECT * FROM salary_raw;

-- Check:
SELECT *
FROM salary_stg;


/**
==============================================================================================
    Step 1: Standardize column names to snake_case for consistent SQL style and add row_id
==============================================================================================
**/

DESCRIBE salary_stg;

-- Note: CSV import introduced an artifact in the first column name (`п»їAge`);

ALTER TABLE salary_stg
    CHANGE COLUMN `п»їAge` age SMALLINT,
    CHANGE COLUMN `Gender` gender VARCHAR(20),
    CHANGE COLUMN `Education Level` education_level VARCHAR(50),
    CHANGE COLUMN `Job Title` job_title VARCHAR(150),
    CHANGE COLUMN `Years of Experience` years_of_experience INT,
    CHANGE COLUMN `Salary` salary INT;
    

-- Adding a new column for idexing:

ALTER TABLE salary_stg
ADD COLUMN row_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY FIRST;

-- Check:
SELECT *
FROM salary_stg;


/**
====================================================================
    Step 2: Investigation for invalid values and correcting them
====================================================================
**/

-- NULL Values check:

SELECT
    SUM(age IS NULL) AS age_nulls,
    SUM(gender IS NULL) AS gender_nulls,
    SUM(education_level IS NULL) AS edu_nulls,
    SUM(job_title IS NULL) AS job_nulls,
    SUM(years_of_experience IS NULL) AS yoe_nulls,
    SUM(salary IS NULL) AS salary_nulls
FROM salary_stg;


-- Duplicate values check:

SELECT COUNT(*)
FROM salary_stg;

SELECT DISTINCT COUNT(*)
FROM salary_stg;


-- Gender column:

SELECT DISTINCT gender
FROM salary_stg;

SELECT 
    gender, COUNT(*) AS n
FROM
    salary_stg
GROUP BY gender
ORDER BY n DESC;

-- Note: 'Other' gender category has low representation (n=14). Include in totals, interpret subgroup metrics with caution;


-- Education Level:

SELECT DISTINCT
    education_level
FROM
    salary_stg;
    
-- Found empty string values;

SELECT *
FROM
    salary_stg
WHERE
    education_level = '';
    
-- Convert empty education_level to NULL (missing value):

UPDATE salary_stg 
SET 
    education_level = NULL
WHERE
    education_level IS NOT NULL
        AND TRIM(education_level) = '';
    
/** Standardize education_level into 4 categories:
    High School, Bachelor's, Master's, PhD 
    (e.g., "Bachelor's Degree" -> "Bachelor's");
**/

UPDATE salary_stg
SET education_level =
    CASE
        WHEN education_level IS NULL THEN NULL
        WHEN education_level = "Bachelor's Degree" THEN "Bachelor's"
        WHEN education_level = "Master's Degree" THEN "Master's"
        ELSE education_level
  END;
              

-- Job Title:

SELECT DISTINCT job_title
FROM salary_stg
ORDER BY job_title ASC;

SELECT 
    job_title, COUNT(*) AS n
FROM
    salary_stg
GROUP BY job_title
ORDER BY job_title ASC;

-- Note: Job Titles values are fragmented due to inconsistent naming (typos, abbreviations, and formatting);

-- Job titles cleanup: trim whitespace (prevents hidden duplicates like 'CEO ' vs 'CEO')

UPDATE salary_stg
SET job_title = TRIM(job_title)
WHERE job_title IS NOT NULL;

/** Standardize job titles: fix typos + unify clear variants to reduce category fragmentation in Tableau.
    Note: Only changes titles where the mapping is unambiguous (typos/abbreviations);
**/

UPDATE salary_stg
SET job_title = CASE
    WHEN job_title = 'Juniour HR Coordinator' THEN 'Junior HR Coordinator'
    WHEN job_title = 'Juniour HR Generalist' THEN 'Junior HR Generalist'

    WHEN job_title = 'Social Media Man' THEN 'Social Media Manager'

    WHEN job_title = 'Customer Service Rep' THEN 'Customer Service Representative'
    WHEN job_title = 'Customer Success Rep' THEN 'Customer Success Representative'

    WHEN job_title = 'Back end Developer' THEN 'Back-End Developer'
    WHEN job_title = 'Front end Developer' THEN 'Front-End Developer'

    ELSE job_title
END
WHERE job_title IS NOT NULL;


/** Note: `job_title` has many unique values with a long tail (many titles occur 1–2 times).
        For meaningful comparisons, focus on roles with sufficient sample size (e.g., n >= 20);
**/


-- Years of Experience check:

SELECT
    row_id,
    age,
    years_of_experience,
    (age - 16) AS max_plausible_experience,
    job_title,
    education_level,
    salary
FROM salary_stg
WHERE years_of_experience > (age - 16);

DELETE FROM salary_stg
WHERE years_of_experience > (age - 16);

-- Note: A few records looked unrealistic (too many years of experience for the given age);


-- Years of Experience AND Salary:

SELECT DISTINCT years_of_experience
FROM salary_stg
ORDER BY years_of_experience;

SELECT DISTINCT salary
FROM salary_stg
ORDER BY salary;

-- Salary outlier check:

SELECT row_id, age, job_title, education_level, years_of_experience, salary
FROM salary_stg
WHERE salary < 10000 OR salary > 500000
ORDER BY salary;

UPDATE salary_stg
SET salary = NULL
WHERE salary < 10000;

-- Flagged unrealistic salary values as missing (likely data entry errors / different units);


-- Create a working copy of the staging table for EDA:

CREATE TABLE IF NOT EXISTS salary_wrk AS
SELECT * FROM salary_stg;

DESCRIBE salary_wrk;

-- Note: After copying `salary_stg` into `salary_wrk`, `row_id` lost its properties.

ALTER TABLE salary_wrk
MODIFY COLUMN row_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY;

-- Check Queries:

DESCRIBE salary_wrk;

SELECT *
FROM salary_wrk;


-- Row counts:

SELECT
  (SELECT COUNT(*) FROM salary_raw) AS raw_rows,
  (SELECT COUNT(*) FROM salary_stg) AS stg_rows,
  (SELECT COUNT(*) FROM salary_wrk) AS wrk_rows;

-- Null checks in work table:

SELECT
    SUM(age IS NULL) AS age_nulls,
    SUM(gender IS NULL) AS gender_nulls,
    SUM(education_level IS NULL) AS edu_nulls,
    SUM(job_title IS NULL) AS job_nulls,
    SUM(years_of_experience IS NULL) AS yoe_nulls,
    SUM(salary IS NULL) AS salary_nulls
FROM salary_wrk;


/**
===============================================
    Step 3: Exploratory Data Analysis (EDA)
===============================================
**/

-- Basic salary distribution:

SELECT
    COUNT(*) AS employee_count,
    ROUND(AVG(salary)) AS avg_salary,
    ROUND(STD(salary)) AS salary_std,
    MIN(salary) AS min_salary,
    MAX(salary) AS max_salary
FROM salary_wrk
WHERE salary IS NOT NULL;

-- Check query:

SELECT MIN(salary), MAX(salary)
FROM salary_wrk
WHERE salary IS NOT NULL;


-- Gender differences across key indicators:

-- By Salary:

SELECT 
    gender,
    COUNT(*) AS employee_count,
    ROUND(AVG(salary)) AS avg_salary,
    ROUND(STD(salary)) AS salary_std,
    MIN(salary) AS min_salary,
    MAX(salary) AS max_salary
FROM
    salary_wrk
WHERE
    salary IS NOT NULL
GROUP BY gender
HAVING employee_count > 20
ORDER BY employee_count DESC;

-- By Education Level:

SELECT
    gender,
    education_level,
    COUNT(*) AS employee_count
FROM
    salary_wrk
GROUP BY
    gender,
    education_level
HAVING employee_count > 20
ORDER BY
    gender,
    employee_count DESC;

    
-- Salary summary by Education Level (ordered logically, not alphabetically):

WITH ranked AS (
    SELECT
        *,
        CASE education_level
            WHEN 'High School' THEN 1
            WHEN "Bachelor's" THEN 2
            WHEN "Master's" THEN 3
            WHEN 'PhD' THEN 4
            ELSE NULL
        END AS education_rank
    FROM salary_wrk
)

SELECT
    education_level,
    COUNT(*) AS employee_count,
    ROUND(AVG(salary)) AS avg_salary,
    ROUND(STD(salary)) AS salary_std,
    MIN(salary) AS min_salary,
    MAX(salary) AS max_salary
FROM ranked
WHERE salary IS NOT NULL AND
    education_level IS NOT NULL
GROUP BY education_level, education_rank
ORDER BY education_rank DESC;

/** Note: An `education_rank` was created to control the display order: PhD > Master's > Bachelor's > High School.
        A CTE was used to keep the ranking logic separate and make the aggregation query easier to read/maintain;
**/


-- Salary summary by Years of Experience:

SELECT 
    years_of_experience,
    COUNT(*) AS employee_count,
    ROUND(AVG(salary)) AS avg_salary,
    ROUND(STD(salary)) AS salary_std,
    MIN(salary) AS min_salary,
    MAX(salary) AS max_salary
FROM
    salary_wrk
WHERE
    salary IS NOT NULL
GROUP BY
    years_of_experience
ORDER BY 
    years_of_experience;
    
/** Note: This aggregation was used to observe how average salary and salary variability changed with experience,
        and to flag experience levels with very small sample sizes (potentially noisy averages);
**/


-- Salary summary by Job Title (Top paying roles with stable sample size):

SELECT 
    job_title,
    COUNT(*) AS employee_count,
    ROUND(AVG(salary)) AS avg_salary,
    ROUND(STD(salary)) AS salary_std,
    MIN(salary) AS min_salary,
    MAX(salary) AS max_salary
FROM
    salary_wrk
WHERE
    salary IS NOT NULL
GROUP BY job_title
HAVING employee_count > 20
ORDER BY avg_salary DESC;

-- Note: This view was used to highlight higher-paying roles while keeping comparisons stable via a minimum sample-size filter;


-- Top-paying Job Titles using window ranking:

WITH job_salary AS (
    SELECT
        job_title,
        COUNT(*) AS employee_count,
        ROUND(AVG(salary)) AS avg_salary
    FROM salary_wrk
    WHERE salary IS NOT NULL
    GROUP BY job_title
    HAVING employee_count > 20
)
SELECT
    job_title,
    employee_count,
    avg_salary,
    RANK() OVER (ORDER BY avg_salary DESC) AS avg_salary_rank
FROM job_salary;
    
/** Note: A window function (RANK) was used to rank job titles by `avg_salary` after applying a minimum sample-size filter (> 20),
        which helped avoid "top-paying" results driven by rare job titles;
**/


-- Salary summary by Age:

SELECT
    age,
    COUNT(*) AS employee_count,
    ROUND(AVG(salary)) AS avg_salary,
    ROUND(STD(salary)) AS salary_std,
    MIN(salary) AS min_salary,
    MAX(salary) AS max_salary
FROM
    salary_wrk
WHERE
    salary IS NOT NULL
GROUP BY age
HAVING employee_count > 20
ORDER BY age;

-- Note: This aggregation was used to observe salary patterns by age while filtering out small age groups;


-- Salary summary by Age Group:

SELECT
    CASE
        WHEN age BETWEEN 21 AND 24 THEN '1) Youth (21–24)'
        WHEN age BETWEEN 25 AND 34 THEN '2) Young Adults (25–34)'
        WHEN age BETWEEN 35 AND 44 THEN '3) Adults (35–44)'
        ELSE '4) Middle-aged (45–62)'
    END AS age_group,
    COUNT(*) AS employee_count,
    ROUND(AVG(salary)) AS avg_salary,
    ROUND(STD(salary)) AS salary_std,
    MIN(salary) AS min_salary,
    MAX(salary) AS max_salary
FROM salary_wrk
WHERE salary IS NOT NULL
GROUP BY age_group
ORDER BY MIN(age);

-- Note: Age groups were aligned with the dataset range (21–62) and labeled with ordered prefixes to keep correct sorting in Tableau;

/** Note: The `employee_count` was kept to show the sample size per age group. A minimum-sample filter was not applied
        because the analysis used only 4 broad age groups;
**/
