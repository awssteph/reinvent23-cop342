
-- Finance 
--This query helps you understand how your AWS costs are distributed across tagged and untagged resources, enabling accurate cost attribution and chargeback mechanisms within your organization.
--By following this step and running the provided query, you can gain insights into your AWS spending patterns, identify areas for cost optimization, and implement chargeback processes based on resource tags and usage.

--1 create base query
--2 add order by and we see untagged 

Select sum(line_item_unblended_cost) as sum_line_item_unblended_cost, month , resource_tags_user_environment
from ${table}
where  ${date_filter}
group by month, resource_tags_user_environment
order by sum_line_item_unblended_cost DESC



------
--The WITH clause is a way to define a temporary table or view within a SQL query. It allows you to break down complex queries into smaller, more manageable parts, improving readability and maintainability.
with all_costs as (
Select sum(line_item_unblended_cost) as sum_line_item_unblended_cost, resource_tags_user_environment, month, year
from ${table}
where  ${date_filter}  
group by 2,3,4
order by sum_line_item_unblended_cost DESC

), 
calcs as (
-- 1. Make the total spend per tag. The over is going to what you are splitting by. aka Per month charge-back.
select *, sum(sum_line_item_unblended_cost) over (partition by month, year) as total_spend,

-- split the untaged spend over year and month
sum(CASE WHEN resource_tags_user_environment is null then sum_line_item_unblended_cost else 0 END) over (partition by month, year) as untagged_spend,

-- split the taged spend over year and month
sum(CASE WHEN resource_tags_user_environment is not null then sum_line_item_unblended_cost else 0 END) over (partition by month, year) as tagged_spend,

-- We can now use this to work out the % of the bill that IS is tagged that the account owns - Normal spend/CASE tagged
 --The CASE statement is used to perform conditional logic within a SQL query. It allows you to evaluate a set of conditions and return different values based on the result of those conditions.	
CASE WHEN  resource_tags_user_environment is not null then  
sum_line_item_unblended_cost/sum(CASE WHEN resource_tags_user_environment is not null then sum_line_item_unblended_cost else 0 END) over (partition by month, year)
ELSE 0 END
as percentage_spend
from all_costs
)

--The final SELECT statement retrieves the results from the calcs subquery, showing the chargeback amount for each tagged resource, including the proportion of untagged spend allocated to that resource.
select *,  percentage_spend*untagged_spend as untagged_distribution,  
CASE WHEN resource_tags_user_environment is not null then
(percentage_spend*untagged_spend)+sum_line_item_unblended_cost 
else 0 END
as charge_amount

from calcs

----
-- We can simplify some of the elemets and remove the subquieres now we have the full logic above

with all_costs as (
	Select sum(line_item_unblended_cost) as sum_line_item_unblended_cost,
		resource_tags_user_environment,
		month,
		year
	from ${table}
	where  ${date_filter}
	group by 2,
		3,
		4
	order by sum_line_item_unblended_cost DESC
)

select *,
	CASE
		WHEN resource_tags_user_environment is not null then (CASE
			WHEN resource_tags_user_environment is not null then sum_line_item_unblended_cost / sum(
				CASE
					WHEN resource_tags_user_environment is not null then sum_line_item_unblended_cost else 0
				END
			) over (partition by month, year) ELSE 0
		END * sum(
			CASE
				WHEN resource_tags_user_environment is null then sum_line_item_unblended_cost else 0
			END
		) over (partition by month, year)) + sum_line_item_unblended_cost else 0
	END as charge_amount
from all_costs

