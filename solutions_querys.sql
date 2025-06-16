use  gdb023;
show tables;
select * from dim_customer;
select * from dim_product;
select distinct division from dim_product;
select distinct segment from dim_product;
select * from fact_gross_price;
select * from fact_manufacturing_cost;
select * from fact_pre_invoice_deductions;
select * from fact_sales_monthly;

/* 1.  Provide the list of markets in which customer  "Atliq  Exclusive"  operates its 
business in the  APAC  region. */

select distinct market from dim_customer 
where customer="Atliq Exclusive" and region="APAC";

/* 2.  What is the percentage of unique product increase in 2021 vs. 2020? The 
final output contains these fields, 
unique_products_2020 
unique_products_2021 
percentage_chg */

WITH unique_pro_20 AS (
    SELECT COUNT(DISTINCT product_code) AS products_2020 
    FROM fact_sales_monthly
    WHERE fiscal_year = "2020"
), 
unique_pro_21 AS (
    SELECT COUNT(DISTINCT product_code) AS products_2021 
    FROM fact_sales_monthly
    WHERE fiscal_year = "2021"
)

SELECT 
    products_2020 AS unique_products_2020,
    products_2021 AS unique_products_2021,
    ROUND((products_2021 - products_2020) / products_2020 * 100, 2) AS percentage_change
FROM 
    unique_pro_20, unique_pro_21;
    
 /* 3.  Provide a report with all the unique product counts for each  segment  and 
sort them in descending order of product counts. The final output contains 
2 fields, 
segment 
product_count*/

select segment, count(distinct product_code) as product_count from dim_product 
group by segment order by product_count  desc;

/* 4.  Follow-up: Which segment had the most increase in unique products in 
2021 vs 2020? The final output contains these fields, 
segment 
product_count_2020 
product_count_2021 
difference 
*/

WITH x AS (
    SELECT dm_p.segment, COUNT(DISTINCT ft_m.product_code) AS pro_20  
    FROM dim_product dm_p
    LEFT JOIN fact_sales_monthly ft_m 
      ON dm_p.product_code = ft_m.product_code
    WHERE ft_m.fiscal_year = "2020"
    GROUP BY dm_p.segment
), 
y AS (
    SELECT dm_p.segment, COUNT(DISTINCT ft_m.product_code) AS pro_21  
    FROM dim_product dm_p
    LEFT JOIN fact_sales_monthly ft_m 
      ON dm_p.product_code = ft_m.product_code
    WHERE ft_m.fiscal_year = "2021"
    GROUP BY dm_p.segment
)

SELECT 
    x.segment,
    x.pro_20 AS product_count_2020,
    y.pro_21 AS product_count_2021,
    (y.pro_21 - x.pro_20) AS Difference
FROM 
    x
JOIN 
    y 
ON 
    x.segment = y.segment
ORDER BY 
    Difference DESC;
    
/* 5.  Get the products that have the highest and lowest manufacturing costs. 
The final output should contain these fields, 
product_code 
product 
manufacturing_cost */
SELECT 
    pr.product,
    mc.product_code,
    mc.manufacturing_cost
FROM 
    fact_manufacturing_cost mc
JOIN 
    dim_product pr 
ON 
    mc.product_code = pr.product_code
WHERE 
    mc.manufacturing_cost IN (
        (SELECT MIN(manufacturing_cost) FROM fact_manufacturing_cost),
        (SELECT MAX(manufacturing_cost) FROM fact_manufacturing_cost)
        )
ORDER BY mc.manufacturing_cost desc;

/* 6.  Generate a report which contains the top 5 customers who received an 
average high  pre_invoice_discount_pct  for the  fiscal  year 2021  and in the 
Indian  market. The final output contains these fields, 
customer_code 
customer 
average_discount_percentage */
SELECT d.customer_code ,c.customer,round(d.pre_invoice_discount_pct*100,2)
as average_discount_percentage FROM dim_customer c
JOIN fact_pre_invoice_deductions d ON c.customer_code=d.customer_code
WHERE c.market="India" and d.fiscal_year="2021" and d.pre_invoice_discount_pct >(
SELECT AVG(pre_invoice_discount_pct) avg_per FROM fact_pre_invoice_deductions)
ORDER BY d.pre_invoice_discount_pct desc limit 5;

/* 7. Get the complete report of the Gross sales amount for the customer  “Atliq 
Exclusive”  for each month  .  This analysis helps to  get an idea of low and 
high-performing months and take strategic decisions. 
The final report contains these columns: 
Month 
Year 
Gross sales Amount */

SELECT 
    MONTHNAME(m.date) AS Month, 
    m.fiscal_year,
    SUM(ROUND(g.gross_price * sold_quantity, 2)) AS total_sales
FROM 
    fact_sales_monthly m
JOIN 
    dim_customer c USING(customer_code)
JOIN 
    fact_gross_price g USING(product_code)
WHERE 
    customer = "Atliq Exclusive"
GROUP BY 
    MONTHNAME(m.date), m.fiscal_year;
/* 8.  In which quarter of 2020, got the maximum total_sold_quantity? The final 
output contains these fields sorted by the total_sold_quantity, 
Quarter 
total_sold_quantity*/


SELECT  
    CASE
        WHEN MONTH(date) IN (9,10,11) THEN "Q1"
        WHEN MONTH(date) IN (12,1,2) THEN "Q2"
        WHEN MONTH(date) IN (3,4,5) THEN "Q3"
        ELSE "Q4"
    END AS Quarters,  
    SUM(sold_quantity) AS total_sold_qty
FROM 
    fact_sales_monthly
WHERE 
    fiscal_year = "2020"
GROUP BY 
    Quarters
ORDER BY 
    total_sold_qty;
    
/*9.  Which channel helped to bring more gross sales in the fiscal year 2021 
and the percentage of contribution?  The final output  contains these fields, 
channel 
gross_sales_mln 
percentage*/
    
    WITH sales_data AS (
    SELECT 
        c.channel,
        SUM(g.gross_price * fs.sold_quantity) / 1000000 AS gross_sales_mln
    FROM 
        fact_sales_monthly fs
    JOIN 
        fact_gross_price g 
        ON fs.product_code = g.product_code 
    JOIN 
        dim_customer c on fs.customer_code=c.customer_code
       
    WHERE 
        fs.fiscal_year = '2021'
    GROUP BY 
        c.channel
),

total_sales AS (
    SELECT SUM(gross_sales_mln) AS total_sales_mln
    FROM sales_data
)

SELECT 
    sd.channel,
    ROUND(sd.gross_sales_mln, 2) AS gross_sales_mln,
    ROUND(sd.gross_sales_mln / ts.total_sales_mln * 100, 2) AS percentage
FROM 
    sales_data sd,total_sales ts
ORDER BY 
    percentage DESC;
    
/*10.  Get the Top 3 products in each division that have a high 
total_sold_quantity in the fiscal_year 2021? The final output contains these 
fields
, division ,product_code, product ,total_sold_quantity ,rank_order */
WITH x AS (
    SELECT 
        P.division, 
        S.product_code, 
        P.product, 
        SUM(S.sold_quantity) AS Total_sold_quantity,
        RANK() OVER (
            PARTITION BY P.division 
            ORDER BY SUM(S.sold_quantity) DESC
        ) AS Rank_Order
    FROM 
        dim_product P 
    JOIN 
        fact_sales_monthly S 
    ON 
        P.product_code = S.product_code
    WHERE 
        S.fiscal_year = 2021
    GROUP BY 
        P.division, S.product_code, P.product
)

SELECT * 
FROM x
WHERE Rank_Order IN (1, 2, 3)
ORDER BY division, Rank_Order;


 
