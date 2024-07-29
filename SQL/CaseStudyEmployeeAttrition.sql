-- Create database HREmployeeDB.
USE SSIS

CREATE TABLE [dbo].[HREmployee](
[Attrition] varchar(10) ,
[Business Travel] varchar(40),
[CF_age band] varchar(10),
[CF_attrition label] varchar(40),
[Department] varchar(10),
[Education Field] varchar(30),
[emp no] varchar(20),
[Employee Number] int,
[Gender] varchar(10),
[Job Role] varchar(40),
[Marital Status] varchar(20),
[Over Time] varchar(10),
[Over18] varchar(10),
[Training Times Last Year] int,
[Age] int,
[CF_current Employee] int,
[Daily Rate] int,
[Distance From Home] int,
[Education] varchar(40),
[Employee Count] int,
[Environment Satisfaction] int,
[Hourly Rate] int,
[Job Involvement] int,
[Job Level] int,
[Job Satisfaction] int,
[Monthly Income] int,
[Monthly Rate] int,
[Num Companies Worked] int,
[Percent Salary Hike] int,
[Performance Rating] int,
[Relationship Satisfaction] int,
[Standard Hours] int,
[Stock Option Level] int,
[Total Working Years] int,
[Work Life Balance] int,
[Years At Company] int,
[Years In Current Role] int,
[Years Since Last Promotion] int,
[Years With Curr Manager] int
)

bulk insert HREmployee from 'D:/HREMP.csv' with (FIELDTERMINATOR= ',', FIRSTROW=2)

select * from HREmployee

-- Return the shape of the table
SELECT RowsCount, ColumnCount FROM 
(SELECT COUNT(*) AS RowsCount FROM HREmployee) AS RowCountQuery,
(SELECT COUNT(column_name) AS ColumnCount 
FROM information_schema.columns 
WHERE table_name = 'HREmployee') AS ColumnCountQuery;

-- Calculate the cumulative sum of total working years for each department
select top(5) * from HREmployee

with department_working_years as (
    select 
        [department], 
        [employee number], 
        [total working years]
    from [dbo].[hremployee]
)
select 
    [department], 
    [employee number], 
    [total working years], 
    sum([total working years]) over (
        partition by [department] 
        order by [employee number]
    ) as cumulative_total_working_years
from department_working_years
order by [department], [employee number];

-- Which gender have higher strength as workforce in each department
select Gender,count(Gender) as number,Department from HREmployee group by Department,Gender

-- Create a new column AGE_BAND and Show Distribution of Employee's Age band group (Below 25, 25-34, 35-44, 45-55. ABOVE 55).
ALTER TABLE HREmployee ADD Age_band varchar(40)

UPDATE HREmployee SET Age_band = CASE
				  WHEN Age < 25 THEN 'Below 25'
                  WHEN Age BETWEEN 25 AND 34 THEN '25-34'
                  WHEN Age BETWEEN 35 AND 44 THEN '35-44'
                  WHEN Age BETWEEN 45 AND 55 THEN '45-55'
                  ELSE 'Above 55'
               END;
SELECT AGE_BAND, COUNT(*) AS AgeBandCount
FROM HREmployee
GROUP BY AGE_BAND
ORDER BY AGE_BAND


-- Compare all marital status of employee and find the most frequent marital status
select distinct [Marital Status],count([Marital Status]) as number from HREmployee group by [Marital Status]
order by number desc


-- Show the Job Role with Highest Attrition Rate (Percentage)
select [Job Role],cast(sum(CASE when Attrition='Yes' then 1 else 0 end) as float)/(count(*))*100 as rate_of_attrition 
from HREmployee group by [Job Role] order by rate_of_attrition desc

-- Show distribution of Employee's Promotion, Find the maximum chances of employee getting promoted.
select 
    [years since last promotion],
    count(*) as promotion_count
from [dbo].[hremployee]
group by [years since last promotion]
order by promotion_count desc;

-- Find the rank of employees within each department based on their monthly income
select Department,[Employee Number],[Monthly Income],RANK() OVER(PARTITION BY department ORDER BY [Monthly Income] DESC) Rank 
from HREmployee

-- Calculate the running total of 'Total Working Years' for each employee within each department and age band.
select Department,age_band,sum([Total Working Years]) as [Total Working Years] from HREmployee group by department,age_band

-- Foreach employee who left, calculate the number of years they worked before leaving and 
-- compare it with the average years worked by employees in the same department.
with employees_left as (
    select 
        [employee number], 
        [department], 
        [years at company] as years_worked
    from [dbo].[hremployee]
    where [attrition] = 'Yes'
),
average_years_per_department as (
    select 
        [department], 
        avg([years at company]) as avg_years_worked
    from [dbo].[hremployee]
    group by [department]
)
select 
    e.[employee number], 
    e.[department], 
    e.years_worked, 
    a.avg_years_worked,
    e.years_worked - a.avg_years_worked as difference
from employees_left e
join average_years_per_department a
    on e.[department] = a.[department]
order by e.[department], e.[employee number];


-- Rank the departments by the average monthly income of employees who have left.
select department,avg([Monthly Income]) monthly_income, rank() over(order by avg([Monthly Income]) desc) as Rank1
from HREmployee where Attrition='Yes' group by department
-- Find the if there is any relation between Attrition Rate and Marital Status of Employee.
select [Marital Status],sum(case when attrition='Yes' then 1
			when attrition='No' then 0
			end) as attrition from HREmployee group by [Marital Status] order by attrition desc
-- Show the Department with Highest Attrition Rate (Percentage)
select department,(sum(case when attrition='Yes' then 1 else 0 end)*100)/(count(*)) as percentage_of_attrition 
from HREmployee group by department order by percentage_of_attrition desc

-- Calculate the moving average of monthly income over the past 3 employees for each job role.
WITH Avg_month AS (
    SELECT [Employee Number], [Job Role],
	[Monthly Income],
	row_number() over(partition by [Job Role] order by [Employee Number]) as row_num,
	avg([Monthly Income]) over(partition by [Job Role] order by [Employee Number]
	rows between 2 preceding and current row) as monthly_moving_income
    FROM HREmployee
	)

select * from Avg_month where row_num<=3 
		
-- Identify employees with outliers in monthly income within each job role. 
--[ Condition : Monthly_Income < Q1 - (Q3 - Q1) * 1.5 OR Monthly_Income > Q3 + (Q3 - Q1) ]

with ranked_data as (
    select 
        [job role],
        [employee number],
        [monthly income],
        ntile(4) over (partition by [job role] order by [monthly income]) as quartile
    from [dbo].[hremployee]
),
quartiles as (
    select 
        [job role],
        max(case when quartile = 1 then [monthly income] end) as q1,
        max(case when quartile = 3 then [monthly income] end) as q3
    from ranked_data
    group by [job role]
),
outliers as (
    select 
        e.[employee number],
        e.[job role],
        e.[monthly income],
        q.q1,
        q.q3,
        q.q3 - q.q1 as iqr
    from [dbo].[hremployee] e
    join quartiles q on e.[job role] = q.[job role]
    where e.[monthly income] < q.q1 - 1.5 * (q.q3 - q.q1)
       or e.[monthly income] > q.q3 + 1.5 * (q.q3 - q.q1)
)
-- Select and display outliers
select 
    [employee number],
    [job role],
    [monthly income],
    q1,
    q3,
    iqr
from outliers
order by [job role], [employee number];


-- Gender distribution within each job role, show each job role with its gender domination. [Male_Domination or Female_Domination]
with gender_counts as (
    select 
        [job role],
        [gender],
        count(*) as gender_count
    from [dbo].[hremployee]
    group by [job role], [gender]
),
job_role_counts as (
    select 
        [job role],
        sum(case when [gender] = 'Male' then gender_count else 0 end) as male_count,
        sum(case when [gender] = 'Female' then gender_count else 0 end) as female_count
    from gender_counts
    group by [job role]
),
gender_domination as (
    select 
        [job role],
        case 
            when male_count > female_count then 'Male_Domination'
            when female_count > male_count then 'Female_Domination'
            else 'Equal_Domination'
        end as gender_domination
    from job_role_counts
)
select 
    [job role],
    gender_domination
from gender_domination
order by [job role];
-- Percent rank of employees based on training times last year
select 
    [employee number],
    [training times last year],
    percent_rank() over (order by [training times last year]) as percent_rank
from [dbo].[hremployee]
order by percent_rank;
-- Divide employees into 5 groups based on training times last year [Use NTILE ()]
select
    [employee number],
    [training times last year],
    ntile(5) over (order by [training times last year]) as training_group
from [dbo].[hremployee]
order by training_group;
-- Categorize employees based on training times last year as - Frequent Trainee, Moderate Trainee, Infrequent Trainee.
select 
    [employee number],
    [training times last year],
    case
        when [training times last year] >= 10 then 'Frequent Trainee'
        when [training times last year] between 5 and 9 then 'Moderate Trainee'
        else 'Infrequent Trainee'
    end as trainee_category
from [dbo].[hremployee]
order by trainee_category;
-- Categorize employees as 'High', 'Medium', or 'Low' performers based on their performance rating, using a CASE WHEN statement.
select 
    [employee number],
    [performance rating],
    case
        when [performance rating] >= 4 then 'High'
        when [performance rating] = 3 then 'Medium'
        else 'Low'
    end as performance_category
from [dbo].[hremployee]
order by performance_category;
-- Use a CASE WHEN statement to categorize employees into 'Poor', 'Fair', 'Good', or 'Excellent' work-life balance based on their work-life balance score.
select 
    [employee number],
    [work life balance],
    case
        when [work life balance] >= 4 then 'Excellent'
        when [work life balance] = 3 then 'Good'
        when [work life balance] = 2 then 'Fair'
        else 'Poor'
    end as work_life_balance_category
from [dbo].[hremployee]
order by work_life_balance_category;
-- Group employees into 3 groups based on their stock option level using the [NTILE] function.
select 
    [employee number],
    [stock option level],
    ntile(3) over (order by [stock option level]) as stock_option_group
from [dbo].[hremployee]
order by stock_option_group;

-- Find key reasons for Attrition in Company
-- Combined analysis of attrition
select 
    'Job Role' as analysis_type,
    [job role] as category,
    count(*) as total_employees,
    sum(case when [attrition] = 'Yes' then 1 else 0 end) as attrition_count,
    (sum(case when [attrition] = 'Yes' then 1 else 0 end) * 1.0 / count(*)) * 100 as attrition_rate
from [dbo].[hremployee]
group by [job role]

union all

select 
    'Department' as analysis_type,
    [department] as category,
    count(*) as total_employees,
    sum(case when [attrition] = 'Yes' then 1 else 0 end) as attrition_count,
    (sum(case when [attrition] = 'Yes' then 1 else 0 end) * 1.0 / count(*)) * 100 as attrition_rate
from [dbo].[hremployee]
group by [department]

union all

select 
    'Age Group' as analysis_type,
    case
        when [age] < 30 then 'Under 30'
        when [age] between 30 and 40 then '30-40'
        when [age] between 41 and 50 then '41-50'
        else 'Above 50'
    end as category,
    count(*) as total_employees,
    sum(case when [attrition] = 'Yes' then 1 else 0 end) as attrition_count,
    (sum(case when [attrition] = 'Yes' then 1 else 0 end) * 1.0 / count(*)) * 100 as attrition_rate
from [dbo].[hremployee]
group by 
    case
        when [age] < 30 then 'Under 30'
        when [age] between 30 and 40 then '30-40'
        when [age] between 41 and 50 then '41-50'
        else 'Above 50'
    end

union all

select 
    'Work-Life Balance' as analysis_type,
    case
        when [work life balance] = 1 then 'Very Low'
        when [work life balance] = 2 then 'Low'
        when [work life balance] = 3 then 'Medium'
        when [work life balance] = 4 then 'High'
        else 'Very High'
    end as category,
    count(*) as total_employees,
    sum(case when [attrition] = 'Yes' then 1 else 0 end) as attrition_count,
    (sum(case when [attrition] = 'Yes' then 1 else 0 end) * 1.0 / count(*)) * 100 as attrition_rate
from [dbo].[hremployee]
group by 
    case
        when [work life balance] = 1 then 'Very Low'
        when [work life balance] = 2 then 'Low'
        when [work life balance] = 3 then 'Medium'
        when [work life balance] = 4 then 'High'
        else 'Very High'
    end

union all

select 
    'Gender and Marital Status' as analysis_type,
    concat([gender], ' - ', [marital status]) as category,
    count(*) as total_employees,
    sum(case when [attrition] = 'Yes' then 1 else 0 end) as attrition_count,
    (sum(case when [attrition] = 'Yes' then 1 else 0 end) * 1.0 / count(*)) * 100 as attrition_rate
from [dbo].[hremployee]
group by [gender], [marital status]

order by analysis_type, category;
