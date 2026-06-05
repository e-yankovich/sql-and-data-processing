ALTER TABLE Staging_Gym_visit
ADD COLUMN times_processed_automatically INT;
ADD COLUMN day_part day_part_enum,
ADD COLUMN visit_duration INT;
SELECT * FROM Staging_Gym_visit ORDER BY v_id

-- Populate the missing values in the Dim_date table.
INSERT INTO Dim_Date (
    date_key,
    day_number_of_month,
    month_number_of_year,
    year_number,
    day_name,
    month_name
)
SELECT 
    d::date,
    EXTRACT(DAY FROM d),
    EXTRACT(MONTH FROM d),
    EXTRACT(YEAR FROM d),
    TO_CHAR(d, 'Day'),
    TO_CHAR(d, 'Month')
FROM generate_series('2025-01-01'::date, '2025-12-31'::date, '1 day') d
WHERE NOT EXISTS (
    SELECT 1 FROM Dim_Date dd WHERE dd.date_key = d
);

SELECT * FROM Dim_Date
ORDER BY date_key;

---------------------------------------------------------------------------
-- E - TRANSFORM - L
-- Step 1:
-- Case: There is a persinal_code, but visitor's name is null
-- Solution: I believe that if we have persinal_code it is safe to extract
-- visitor's name from existing data in Dim_Member table

UPDATE Staging_Gym_visit sg
SET visitor_name = dm.last_name || ' ' || dm.first_name
FROM Dim_Member dm
WHERE sg.personal_code = dm.personal_code
  AND sg.visitor_name IS NULL;

SELECT * FROM Staging_Gym_visit

-- Step 2:
-- Case: Gym_1 stores names as <last name> <first name>,
-- while Gym_2 stores names as <first name> <last name>
-- Solution: updating rows with Gym_2 to the format of Gym_1
-- counter of how many times records were reviewed automatically

UPDATE Staging_Gym_visit
SET visitor_name = split_part(visitor_name, ' ', 2) || ' ' || split_part(visitor_name, ' ', 1)
WHERE gym_code = 'Gym_2'
  AND visitor_name IS NOT NULL
  AND visitor_name LIKE '% %'
  AND times_processed_automatically IS NULL;
  
SELECT * FROM Staging_Gym_visit

-- Step 3:
-- Case: information about a visit to Gym_1 is stored in a single row. For Gym_2, the
-- information is stored in two rows: the first row contains the Time_in value, and the second
-- row for the same visitor contains the Time_out value.
-- Solution: useв an approach where rows with missing time_in or time_out are first updated,
-- filling the missing values from other rows for the same visit, while ensuring that
-- time_in is less than time_out for data consistency
WITH Time_Filled AS (
  UPDATE Staging_Gym_visit s1
  SET time_in = s2.time_in
  FROM Staging_Gym_visit s2
  WHERE s1.gym_code = 'Gym_2'
    AND s1.time_in IS NULL
    AND s1.personal_code = s2.personal_code
    AND s1.visit_date = s2.visit_date
    AND s1.visitor_name = s2.visitor_name
    AND s2.time_in IS NOT NULL
  RETURNING s1.v_id, s1.visit_date, s1.personal_code
),
Time_Filled_2 AS (
  UPDATE Staging_Gym_visit s1
  SET time_out = s2.time_out
  FROM Staging_Gym_visit s2
  WHERE s1.gym_code = 'Gym_2'
    AND s1.time_out IS NULL
    AND s1.personal_code = s2.personal_code
    AND s1.visit_date = s2.visit_date
    AND s1.visitor_name = s2.visitor_name
    AND s2.time_out IS NOT NULL
  RETURNING s1.v_id, s1.visit_date, s1.personal_code
)
SELECT * FROM Time_Filled
UNION ALL
SELECT * FROM Time_Filled_2;

-- Step 4:
-- Case: handling duplicates and deliting them
-- Solution: assigned row numbers to each row in the group of duplicates,
-- deleted rows where row number is greater than 1
WITH RowNumbered AS (
  SELECT
    v_id,
    personal_code,
    visit_date,
    gym_code,
    visitor_name,
    time_in,
    time_out,
    ROW_NUMBER() OVER (
      PARTITION BY personal_code, visit_date, gym_code, visitor_name, time_in, time_out
      ORDER BY v_id
    ) AS row_num
  FROM Staging_Gym_visit
)
DELETE FROM Staging_Gym_visit
WHERE v_id IN (
  SELECT v_id
  FROM RowNumbered
  WHERE row_num > 1
);

-- Step 5:
-- Calculating the duration of each visit in minutes and value for the day_part column
UPDATE Staging_Gym_visit
SET require_manual_processing = 1
WHERE time_in IS NULL OR time_out IS NULL
   OR time_in > time_out;

UPDATE Staging_Gym_visit
SET 
    visit_duration = EXTRACT(EPOCH FROM (time_out - time_in)) / 60,  -- in minutes
    day_part = CASE
                WHEN time_in <= '10:00:00'::time THEN 'Morning'::day_part_enum
                WHEN time_in BETWEEN '10:01:00'::time AND '17:00:00'::time THEN 'Day'::day_part_enum
                ELSE 'Evening'::day_part_enum
              END
WHERE require_manual_processing = 0
AND visit_duration IS NULL
AND day_part IS NULL

-- Step 6:
-- Verifying that the personal_code matches the visitor's name and exclude any incorrect data
-- from processing.
UPDATE Staging_Gym_visit
SET require_manual_processing = 1
WHERE NOT EXISTS (
    SELECT 1
    FROM Dim_Member dm
    WHERE dm.personal_code = Staging_Gym_visit.personal_code
    AND dm.first_name = split_part(Staging_Gym_visit.visitor_name, ' ', 2)
    AND dm.last_name = split_part(Staging_Gym_visit.visitor_name, ' ', 1)
);

---------------------------------------------------------------------------

-- E - T - LOAD

-- Step 1:
-- To prevent data duplication in DWH while auloading new data:
-- Allowed multiple visits by the same member to the same gym on the same day.
-- Each visit must have a unique combination of visit_duration and day_part 
-- Duplicates are prevented if the same combination of all data in the row is already exists.
-- Multiple visits on the same day are allowed as long as the visit_duration or day_part differs.

INSERT INTO Fact_Visit (gym_id, member_id, visit_date_key, visit_duration, day_part)
SELECT 
    g.gym_id, 
    m.member_id,
    s.visit_date AS visit_date_key,
    s.visit_duration,
    s.day_part
FROM Staging_Gym_visit s
JOIN Dim_Member m ON s.personal_code = m.personal_code
JOIN Dim_Date d ON s.visit_date = d.date_key
JOIN Dim_Gym g ON s.gym_code = g.gym_code
WHERE s.require_manual_processing = 0
  AND NOT EXISTS (
    SELECT 1
    FROM Fact_Visit fv
    WHERE fv.gym_id = g.gym_id
      AND fv.member_id = m.member_id
      AND fv.visit_date_key = s.visit_date
      AND fv.visit_duration = s.visit_duration
      AND fv.day_part = s.day_part
);

SELECT * FROM Fact_Visit ORDER BY visit_date_key
-- 5 records were added to DWH (with first bathch of data)
-- + 3 records were added to DWH (with second bathch of data)

-- Step 2:
-- Removing the processed rows from the Staging table
DELETE FROM Staging_Gym_visit
WHERE require_manual_processing = 0;
-- 5 records were removed from the staging table, 5 left marked for manual processing - with first batch of data
-- 3 and 4 accordingly - with second batch of data, 

-- Step 3:
UPDATE Staging_Gym_visit
SET times_processed_automatically = COALESCE(times_processed_automatically, 0) + 1;

-- AT THISS STAGE WE CAN SEE THE FINAL LIST OF RECORDS TO PROCESS MANUALLY
SELECT * FROM Staging_Gym_visit ORDER BY v_id

---------------------------------------------------------------------------
-- it's not really optimal, but as we work with small amount of data in current task we can 
-- set require_manual_processing to 0 for all records
UPDATE Staging_Gym_visit
SET require_manual_processing = 0;

/*
Use the script HT1_part_2.sql to add a new set of data to the Staging table. 
*/

insert into Staging_Gym_visit
	(visit_date, gym_code, personal_code, visitor_name, time_in, time_out)
values
	('2025-04-04', 'Gym_1', 'P3', 'L3 F3', '19:45', '21:15'),
	('2025-04-04', 'Gym_2', 'P5', 'F5 L5', null, '10:40'),
	('2025-04-05', 'Gym_1', 'P1', 'L1 F1', '16:00', '17:00');


-- now we can preform all the steps from E - TRANSFORM - L (1, 2, 3, 4, 5, 6)
-- and then - steps from E - T - LOAD (1, 2, 3)