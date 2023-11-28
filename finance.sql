
-- finance 

--1 create base query
--2 add order by and we see untagged 
-- 3 we fix 
Select sum(line_item_unblended_cost) as sum_line_item_unblended_cost, month , resource_tags_user_environment
from ${table}
where  ${date_filter}
group by month, resource_tags_user_environment
order by sum_line_item_unblended_cost DESC



------

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

-- split the unattged spend over year and month
sum(CASE WHEN resource_tags_user_environment is null then sum_line_item_unblended_cost else 0 END) over (partition by month, year) as untagged_spend,

sum(CASE WHEN resource_tags_user_environment is not null then sum_line_item_unblended_cost else 0 END) over (partition by month, year) as tagged_spend,

-- We can now use this to work out the % of the bill that IS is tagged that the account owns - Normal spend/CASE tagged
CASE WHEN  resource_tags_user_environment is not null then
sum_line_item_unblended_cost/sum(CASE WHEN resource_tags_user_environment is not null then sum_line_item_unblended_cost else 0 END) over (partition by month, year)
ELSE 0 END
as percentage_spend
from all_costs
)

select *,  percentage_spend*untagged_spend as untagged_distribution,  
CASE WHEN resource_tags_user_environment is not null then
(percentage_spend*untagged_spend)+sum_line_item_unblended_cost 
else 0 END
as charge_amount

from calcs

----
-- simplified

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

