/* Summarize monthly sales performance, tracking total revenue, 
unique customer reach, and transaction volume to identify growth trends.
*/

select format(order_date,'yyyy-MMM') as order_year,sum(sales_amount) as total_sales,
count(distinct customer_key) as total_customer,
count(quantity)as total_quantity
from gold.fact_sales 
where order_date is not null
group by format(order_date,'yyyy-MMM')
order by format(order_date,'yyyy-MMM')

-- calculate the cumulative_sales over time 
SELECT 
    order_date,
    total_sales,
    avarege_sales,
    SUM(total_sales) OVER (ORDER BY order_date) AS cumulative_sales,
    avg(avarege_sales) OVER (ORDER BY order_date) AS avg_cumulative_sales
FROM (
    SELECT 
        DATETRUNC(year, order_date) AS order_date,
        SUM(sales_amount) AS total_sales,
        avg(sales_amount) as avarege_sales
    FROM gold.fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY DATETRUNC(year, order_date)
) as subquery

/* Analyze the yearly performance of products by comparing their sales
to both the average sales performance of the product and the previous year's sales */

with yearly_products_sales as 
(
select 
year(f.order_date)as order_year,
p.product_name,
sum(f.sales_amount) as current_sales
from gold.fact_sales f
left join gold.dim_products p
on f.product_key=p.product_key
where order_date is not null
group by year(f.order_date),p.product_name
)
select 
order_year,
product_name,
current_sales,
avg(current_sales) over(partition by product_name) as avg_sales,
current_sales-avg(current_sales) over(partition by product_name) as diff_avg,
case 
when current_sales-avg(current_sales) over(partition by product_name)>0 then 'above the avg'
when current_sales-avg(current_sales) over(partition by product_name)<0 then 'below the avg'
else 'avg'
end as avg_category,
LAG(current_sales) OVER (PARTITION BY product_name order by order_year) AS previous_sales,
current_sales-LAG(current_sales) OVER (PARTITION BY product_name order by order_year) as diff_py,
case 
when current_sales-LAG(current_sales) OVER (PARTITION BY product_name order by order_year)>0 then 'increasing'
when current_sales-LAG(current_sales) OVER (PARTITION BY product_name order by order_year)<0 then 'decreasing'
else 'no change'
end as 'diff_py_category'
from yearly_products_sales
order by product_name,order_year


-- which category contribute the most to overall sales
with category_sales as (
select category,sum(sales_amount) as 'total_sales'
from gold.fact_sales f
left join gold.dim_products p
on f.product_key=p.product_key
group by category)

select category,total_sales,
sum(total_sales) over() 'overall_sales',
concat(round((cast(total_sales as float)/sum(total_sales) over())*100,2),'%') as 'percentage_of_total'
from category_sales
order by total_sales desc




/* segment product into cost ranges 
and count how many products fall into each category*/

with product_segment as(
select product_key,product_name,cost,
case 
 when cost <100 then 'below 100'
 when cost between 100 and 500 then '100-500'
 when cost between 500 and 1000 then '500-1000'
 else 'above 1000'
end cost_range
from gold.dim_products)

select cost_range,count(product_key) from
product_segment
group by cost_range





/*Group customers into three segments based on their spending behavior:
    - VIP: Customers with at least 12 months of history and spending more than €5,000.
    - Regular: Customers with at least 12 months of history but spending €5,000 or less.
    - New: Customers with a lifespan less than 12 months.
And find the total number of customers by each group
*/

with customer_spending as(
select c.customer_key,
sum(f.sales_amonut) as 'total_spending',
min(f.order_date) as 'first_order',
max(f.order_date) as 'last_order',
datediff(month,min(f.order_date),max(f.order_date)) as 'lifespan'
from gold.dim_customers c
left join gold.fact_sales f
on c.customer_key=f.customer_key
group by c.customer_key
)

select count(customer_key) as 'total_customers',
total_spending,
lifespan
case
    when lifespan >= 12 and total spending >5000 the 'VIP'
    when lifespan > 12 and total spending <=5000 the 'Regular'
    else 'New'
end as customer_segment
from customer_spending
group by customer_segment


