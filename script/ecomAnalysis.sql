
SELECT * FROM `alien-segment-491118-d3.ecom.customers` LIMIT 1000
--schema of table
SELECT *
FROM `ecom`.INFORMATION_SCHEMA.TABLES
WHERE table_name = 'customers';

SELECT column_name, data_type
FROM `alien-segment-491118-d3.ecom`.INFORMATION_SCHEMA.COLUMNS
WHERE table_name = 'customers';

--Get the time range between which the orders were placed.
SELECT
MIN(order_purchase_timestamp) AS min_date,
MAX(order_purchase_timestamp) AS max_date
FROM
ecom.orders;

--3.Count the Cities & States of customers who ordered during the given period.
SELECT
  COUNT(DISTINCT c.customer_city)  AS cities_num,
  COUNT(DISTINCT c.customer_state) AS states_num
FROM
  `ecom.orders` o
JOIN
  `ecom.customers` c
ON
  o.customer_id = c.customer_id
WHERE
  o.order_purchase_timestamp BETWEEN '2016-09-04' AND '2018-10-17';

  SELECT
  c.customer_state,
  COUNT(DISTINCT c.customer_city)    AS cities_per_state,
  COUNT(DISTINCT c.customer_unique_id) AS unique_customers
FROM
  `ecom.orders` o
JOIN
  `ecom.customers` c
ON
  o.customer_id = c.customer_id
GROUP BY
  c.customer_state
ORDER BY
  unique_customers DESC;

--Is there a growing trend in the no. of orders placed over the past years?
WITH yearly AS (
  SELECT
    EXTRACT(YEAR FROM order_purchase_timestamp) AS year,
    COUNT(order_id) AS total_orders_placed
  FROM `ecom.orders`
  GROUP BY year
)
SELECT
  year,
  total_orders_placed,
  ROUND(
    (total_orders_placed - LAG(total_orders_placed) OVER (ORDER BY year))
    / LAG(total_orders_placed) OVER (ORDER BY year) * 100, 2
  ) AS yoy_growth_prcnt
FROM yearly
ORDER BY year;


--Can we see some kind of monthly seasonality in terms of the no. of orders being placed?
WITH monthly AS (
  SELECT
    EXTRACT(YEAR FROM order_purchase_timestamp)  AS year,
    EXTRACT(MONTH FROM order_purchase_timestamp) AS month,
    FORMAT_TIMESTAMP('%B', order_purchase_timestamp) AS month_name,
    COUNT(order_id) AS total_orders
  FROM
    `ecom.orders`
  GROUP BY
    year, month, month_name
),
with_growth AS (
  SELECT
    year,
    month,
    month_name,
    total_orders,
    LAG(total_orders)  OVER (ORDER BY year, month) AS prev_month_orders,
  FROM monthly
)
SELECT
  year,
  month,
  month_name,
  total_orders,
  ROUND(
    
      (total_orders - prev_month_orders)/
       prev_month_orders
     * 100, 2
  ) AS mom_growth_pct
FROM
  with_growth
ORDER BY
  year, month;


--During what time of the day, do the Brazilian customers mostly place their orders? (Dawn, Morning, Afternoon or Night)
SELECT
  CASE
    WHEN EXTRACT(HOUR FROM order_purchase_timestamp) BETWEEN 0  AND 6  THEN 'Dawn (0-6h)'
    WHEN EXTRACT(HOUR FROM order_purchase_timestamp) BETWEEN 7  AND 12 THEN 'Morning (7-12h)'
    WHEN EXTRACT(HOUR FROM order_purchase_timestamp) BETWEEN 13 AND 18 THEN 'Afternoon (13-18h)'
    WHEN EXTRACT(HOUR FROM order_purchase_timestamp) BETWEEN 19 AND 23 THEN 'Night (19-23h)'
  END AS time_of_day,
  COUNT(order_id)  AS total_orders,
  ROUND(COUNT(order_id) * 100.0 / SUM(COUNT(order_id)) OVER (), 2) AS pct_of_total
FROM
  `ecom.orders`
GROUP BY
  time_of_day
ORDER BY
  total_orders DESC;





--1.	Get the month on month no. of orders placed in each state.
  SELECT
  g.geolocation_state  AS state_name,
  EXTRACT(YEAR  FROM o.order_purchase_timestamp) AS year,
  EXTRACT(MONTH FROM o.order_purchase_timestamp) AS month,
  FORMAT_TIMESTAMP('%B', o.order_purchase_timestamp) AS month_name,
  COUNT(o.order_id) AS total_orders,
                                                 
FROM
  `ecom.orders` o
JOIN
  `ecom.customers` c
ON
  o.customer_id = c.customer_id
join
`ecom.geolocation` g
ON
c.customer_zip_code_prefix=g.geolocation_zip_code_prefix

GROUP BY
  state_name, year, month, month_name
ORDER BY
  state_name, year, month;


--How are the customers distributed across all the states?
SELECT
  c.customer_state AS state,
  COUNT(DISTINCT c.customer_unique_id) AS unique_customers,
  COUNT(o.order_id) AS total_orders,
  ROUND(COUNT(DISTINCT c.customer_unique_id) * 100.0 /
    SUM(COUNT(DISTINCT c.customer_unique_id)) OVER (), 2) AS pct_of_customers,
  ROUND(COUNT(o.order_id) * 100.0 /
    SUM(COUNT(o.order_id)) OVER (), 2)   AS pct_of_orders
FROM
  `ecom.customers` c
JOIN
  `ecom.orders` o ON c.customer_id = o.customer_id
GROUP BY
  state
ORDER BY
  unique_customers DESC;

--Get the % increase in the cost of orders from year 2017 to 2018 (include months between Jan to Aug only).

WITH monthly_revenue AS (
  SELECT
    EXTRACT(YEAR  FROM o.order_purchase_timestamp) AS year,
    EXTRACT(MONTH FROM o.order_purchase_timestamp) AS month,
    FORMAT_TIMESTAMP('%B', o.order_purchase_timestamp) AS month_name,
    ROUND(SUM(p.payment_value), 2) AS total_order_cost
  FROM
    `ecom.orders` o
  JOIN
    `ecom.payments` p ON o.order_id = p.order_id
  GROUP BY
    year, month, month_name
),
lagged_revenue AS (
  SELECT
    year,
    month,
    month_name,
    total_order_cost,
    LAG(total_order_cost) OVER (ORDER BY year, month) AS prev_month_total
  FROM
    monthly_revenue
)
SELECT
  year,
  month_name,
  total_order_cost,
  prev_month_total,
  ROUND(((total_order_cost - prev_month_total) / prev_month_total) * 100, 2) AS mom_revenue_growth_pct
FROM
  lagged_revenue
WHERE
  month BETWEEN 1 AND 8
  AND year IN (2017, 2018)
ORDER BY
  year, month;



--Find out the top 5 states with the highest & lowest average freight value.
  WITH state_freight AS (
  SELECT
    c.customer_state AS state,
    ROUND(AVG(oi.freight_value), 2)AS avg_freight
  FROM
    `ecom.order_items` oi
  JOIN
    `ecom.orders` o   ON oi.order_id     = o.order_id
  JOIN
    `ecom.customers` c ON o.customer_id  = c.customer_id
  GROUP BY
    state
),
ranked AS (
  SELECT
    state,
    avg_freight,
    RANK() OVER (ORDER BY avg_freight DESC) AS rank_highest,
    RANK() OVER (ORDER BY avg_freight ASC)  AS rank_lowest
  FROM
    state_freight
)
SELECT
  state,
  avg_freight,

CASE
    WHEN rank_highest <= 5 THEN 'Top 5 Highest'
    WHEN rank_lowest  <= 5 THEN 'Top 5 Lowest'
  END AS category
 
FROM
  ranked
WHERE
  rank_highest <= 5 OR rank_lowest <= 5
ORDER BY
  avg_freight DESC;


--Find out the top 5 states with the highest & lowest average delivery time.

  WITH state_delivery AS (
  SELECT
    c.customer_state  AS state,
    ROUND(AVG(
      DATE_DIFF(
        DATE(o.order_delivered_customer_date),
        DATE(o.order_purchase_timestamp),
        DAY
      )
    ), 1)  AS avg_delivery_days
  FROM
    `ecom.orders` o
  JOIN
    `ecom.customers` c ON o.customer_id = c.customer_id
  WHERE
    o.order_delivered_customer_date IS NOT NULL
    AND o.order_status = 'delivered'
  GROUP BY
    state
),
ranked AS (
  SELECT
    state,
    avg_delivery_days,
    RANK() OVER (ORDER BY avg_delivery_days DESC) AS rank_slow,
    RANK() OVER (ORDER BY avg_delivery_days ASC)  AS rank_fast
  FROM
    state_delivery
)
SELECT
  state,
  avg_delivery_days,
  CASE
   
    WHEN rank_fast <= 5 THEN 'Top 5 Fastest'
     WHEN rank_slow <= 5 THEN 'Top 5 Slowest'
  END  AS category
FROM
  ranked
WHERE
  rank_slow <= 5 OR rank_fast <= 5
ORDER BY
  avg_delivery_days DESC;


  --Calculate the Total & Average value of order price for each state.
SELECT
  c.customer_state AS state,
  COUNT(o.order_id) AS total_orders,
  ROUND(SUM(oi.price), 2) AS total_order_value,
  ROUND(AVG(oi.price), 2) AS avg_order_value

FROM
  `ecom.orders` o
JOIN
  `ecom.order_items` oi ON o.order_id      = oi.order_id
JOIN
  `ecom.customers` c    ON o.customer_id   = c.customer_id
GROUP BY
  state
ORDER BY
  total_order_value DESC;

--Calculate the Total & Average value of order freight for each state.
   SELECT
    c.customer_state   AS state,
    COUNT(o.order_id)  AS total_orders,
    ROUND(SUM(oi.freight_value), 2)  AS total_freight_value,
    ROUND(AVG(oi.freight_value), 2) AS avg_freight_value
 
  FROM
    `ecom.orders` o
  JOIN
    `ecom.order_items` oi ON o.order_id    = oi.order_id
  JOIN
    `ecom.customers` c    ON o.customer_id = c.customer_id
  GROUP BY
    state
  ORDER BY
  total_freight_value DESC;

--Find the no. of days taken to deliver each order from the order’s purchase date as delivery time.
--Also, calculate the difference (in days) between the estimated & actual delivery date of an order.
--Do this in a single query.
SELECT
  order_id,
  DATE_DIFF(
    DATE(order_delivered_customer_date),
    DATE(order_purchase_timestamp),
    DAY
  )  AS deliveryTime,

  DATE_DIFF(
    DATE(order_delivered_customer_date),
    DATE(order_estimated_delivery_date),
    DAY
  ) AS diff_estimated_delivery

FROM
  `ecom.orders`
WHERE
  order_delivered_customer_date IS NOT NULL
  AND order_status = 'delivered'
ORDER BY
  deliveryTime DESC;

--Find out the top 5 states where the order delivery is really fast as compared to the estimated date of delivery.
--You can use the difference between the averages of actual & estimated delivery date to figure out how fast the --delivery was for each state.

WITH delivery_by_state AS (
  SELECT
    c.customer_state  AS state,
    ROUND(AVG(
      DATE_DIFF(
        DATE(o.order_delivered_customer_date),
        DATE(o.order_purchase_timestamp),
        DAY
      )
    ), 1)   AS avg_actual_days,
    ROUND(AVG(
      DATE_DIFF(
        DATE(o.order_estimated_delivery_date),
        DATE(o.order_purchase_timestamp),
        DAY
      )
    ), 1)    AS avg_estimated_days,
    ROUND(AVG(
      DATE_DIFF(
        DATE(o.order_delivered_customer_date),
        DATE(o.order_estimated_delivery_date),
        DAY
      )
    ), 1)  AS avg_diff_days
  FROM
    `ecom.orders` o
  JOIN
    `ecom.customers` c ON o.customer_id = c.customer_id
  WHERE
    o.order_delivered_customer_date IS NOT NULL
    AND o.order_status = 'delivered'
  GROUP BY
    state
)
SELECT
  state,
  avg_actual_days,
  avg_estimated_days,
  avg_diff_days,
  RANK() OVER (ORDER BY avg_diff_days ASC)  AS rank_fastest
FROM
  delivery_by_state
ORDER BY
  rank_fastest;

--Find the month on month no. of orders placed using different payment types.
  WITH payment_monthly AS (
  SELECT
    p.payment_type,
    EXTRACT(YEAR  FROM o.order_purchase_timestamp)AS year,
    EXTRACT(MONTH FROM o.order_purchase_timestamp)AS month,
    FORMAT_TIMESTAMP('%B', o.order_purchase_timestamp) AS month_name,
    COUNT(DISTINCT o.order_id) AS total_orders
  FROM
    `ecom.orders` o
  JOIN
    `ecom.payments` p ON o.order_id = p.order_id
  GROUP BY
    payment_type,year,month,month_name
)
SELECT
  payment_type,
  year,
  month,
  month_name,
  total_orders,
  LAG(total_orders) OVER (
    PARTITION BY payment_type
    ORDER BY year, month
  ) AS prev_month_orders,
 
FROM
  payment_monthly
ORDER BY
  payment_type,year,month;

--Find the no. of orders placed on the basis of the payment installments that have been paid.
SELECT
  p.payment_installments,
  COUNT(DISTINCT o.order_id) AS total_orders,
  ROUND(
    COUNT(DISTINCT o.order_id) * 100.0 /
    SUM(COUNT(DISTINCT o.order_id)) OVER (), 2
  )  AS percnt_of_total
FROM
  `ecom.orders` o
JOIN
  `ecom.payments` p ON o.order_id = p.order_id
GROUP BY
  p.payment_installments
ORDER BY
  p.payment_installments ASC;
