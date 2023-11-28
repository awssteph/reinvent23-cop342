--Devs 

select  line_item_usage_account_id, line_item_resource_id,line_item_usage_type, product_product_family
from ${table} 
where  
-- 1. see what data we have 
 product_product_name = 'Amazon Elastic Compute Cloud' 
 -- 2. filter to just EBS
  AND line_item_usage_type LIKE '%%EBS%%Volume%%' 
  AND split_part(line_item_usage_type,'.',2) = 'gp2'
-- 3. Check line item type for just usage 
ANd line_item_line_item_type = 'Usage'

And  ${date_filter}
  

----

with gp2_data as( select  line_item_usage_account_id, line_item_resource_id,line_item_usage_type, product_product_family,
-- 4. costs
sum(line_item_unblended_cost) as cost,
sum(line_item_usage_amount) as gb_usage,
sum(line_item_unblended_cost)*0.8  as gp3_cost,
sum(line_item_unblended_cost) - (sum(line_item_unblended_cost)*0.8) as gp3_savings
from ${table} 
where  
-- 1. see what data we have 
 product_product_name = 'Amazon Elastic Compute Cloud' 
 -- 2. filter to just EBS
  AND line_item_usage_type LIKE '%%EBS%%Volume%%' 
  AND SPLIT_PART(SPLIT_PART(line_item_usage_type, ':',2),'.',2) = 'gp2'
-- 3. Check line item type for just usage 
AND line_item_line_item_type = 'Usage'

And  ${date_filter}
  group by 1,2,3,4
  order by sum(line_item_unblended_cost) DESC)
  
  --5. Less than a tb
  select * from gp2_data
  where gb_usage <1000