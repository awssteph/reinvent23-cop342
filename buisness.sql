-- Business

--1. Unit cost
 SELECT 
  bill_billing_period_start_date,
  bill_payer_account_id, 
  line_item_usage_account_id,
  round(SUM(CASE
    WHEN line_item_line_item_type = 'SavingsPlanCoveredUsage' THEN savings_plan_savings_plan_effective_cost
    WHEN line_item_line_item_type = 'DiscountedUsage' THEN reservation_effective_cost
    WHEN line_item_line_item_type = 'Usage' THEN line_item_unblended_cost
    ELSE 0 
  END),0) AS sum_amortized_cost, 
  round(SUM(line_item_usage_amount),0) AS sum_line_item_usage_amount, 
  round(SUM(CASE
    WHEN line_item_line_item_type = 'SavingsPlanCoveredUsage' THEN savings_plan_savings_plan_effective_cost
    WHEN line_item_line_item_type = 'DiscountedUsage' THEN reservation_effective_cost
    WHEN line_item_line_item_type = 'Usage' THEN line_item_unblended_cost
    ELSE 0 
  END)/SUM(line_item_usage_amount),2) as unit_cost -- price per hour of EC2
  
FROM 
 ${table}
WHERE 
  ${date_filter}
  AND (line_item_product_code = 'AmazonEC2'
    AND product_servicecode <> 'AWSDataTransfer'
    AND line_item_operation LIKE '%RunInstances%' -- EC2 running hour in CE
    AND line_item_usage_type NOT LIKE '%DataXfer%'
  )
  AND (line_item_line_item_type = 'Usage'
    OR (line_item_line_item_type = 'SavingsPlanCoveredUsage')
    OR (line_item_line_item_type = 'DiscountedUsage')
  )
  
  -- AND product_capacitystatus != 'AllocatedCapacityReservation'-- excludes consumed ODCR hours from total- ERROR Column 'product_capacitystatus'  as you only use coloumns when its there 
GROUP BY 
  bill_billing_period_start_date,
  bill_payer_account_id, 
  line_item_usage_account_id
ORDER BY 
  sum_line_item_usage_amount DESC; -- unit_cost look at kAfQ. Highest spend but NOT worst unit cost




--2. month over month

with unit_costs as (
SELECT 
  line_item_usage_account_id, month, --added month
  round(SUM(CASE
    WHEN line_item_line_item_type = 'SavingsPlanCoveredUsage' THEN savings_plan_savings_plan_effective_cost
    WHEN line_item_line_item_type = 'DiscountedUsage' THEN reservation_effective_cost
    WHEN line_item_line_item_type = 'Usage' THEN line_item_unblended_cost
    ELSE 0 
  END),0) AS sum_amortized_cost, 
  round(SUM(line_item_usage_amount),0) AS sum_line_item_usage_amount, 
  
  round(SUM(CASE
    WHEN line_item_line_item_type = 'SavingsPlanCoveredUsage' THEN savings_plan_savings_plan_effective_cost
    WHEN line_item_line_item_type = 'DiscountedUsage' THEN reservation_effective_cost
    WHEN line_item_line_item_type = 'Usage' THEN line_item_unblended_cost
    ELSE 0 
  END)/SUM(line_item_usage_amount),2) as unit_cost -- price per hour of EC2

FROM 
${table}
WHERE 
  month in ('09','10')
  AND (line_item_product_code = 'AmazonEC2'
    AND product_servicecode <> 'AWSDataTransfer'
    AND line_item_operation LIKE '%RunInstances%' 
    AND line_item_usage_type NOT LIKE '%DataXfer%'
  )
  AND (line_item_line_item_type = 'Usage'
    OR (line_item_line_item_type = 'SavingsPlanCoveredUsage')
    OR (line_item_line_item_type = 'DiscountedUsage')
  )
  
GROUP BY 
  line_item_usage_account_id, month
ORDER BY 
  sum_line_item_usage_amount DESC)
  
  select line_item_usage_account_id, 
  max(CASE when month = '09' then
  unit_cost
  ELSE 0
  END) as sept_unit_cost,
  
  max(CASE when month = '10' then
  unit_cost
  ELSE 0
  END) as oct_unit_cost
  
  from unit_costs
  --where line_item_usage_account_id like '%kAfQ%'
  group by line_item_usage_account_id
  order by oct_unit_cost DESC
