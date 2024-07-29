/* 
READ ME: The database contains 8 tables. 
The relation between each table is outlined below:
-products and productlines are linked by productline
-products and orderdetails are linked by productCode
-orders and orderdetails are linked by orderNumber
-orders and customers are linked by customerNumber
-customers and payments are linked by customerNumber
-employees and offices are linked by officeCode
-employees and customers are linked by salesRepEmployeeNumber
 */

-- Create a table to give a broad overview of the database.
 
SELECT 'customers' as table_name, 
(SELECT COUNT(*) FROM pragma_table_info('customers')) AS column_count,
(SELECT COUNT(*) FROM customers) AS row_count

UNION ALL

SELECT 'employees' as table_name, 
(SELECT COUNT(*) FROM pragma_table_info('employees')) AS column_count,
(SELECT COUNT(*) FROM employees) AS row_count

UNION ALL

SELECT 'offices' as table_name, 
(SELECT COUNT(*) FROM pragma_table_info('offices')) AS column_count,
(SELECT COUNT(*) FROM offices) AS row_count

UNION ALL

SELECT 'orderdetails' as table_name, 
(SELECT COUNT(*) FROM pragma_table_info('orderdetails')) AS column_count,
(SELECT COUNT(*) FROM orderdetails) AS row_count

UNION ALL

SELECT 'orders' as table_name, 
(SELECT COUNT(*) FROM pragma_table_info('orders')) AS column_count,
(SELECT COUNT(*) FROM orders) AS row_count

UNION ALL

SELECT 'payments' as table_name, 
(SELECT COUNT(*) FROM pragma_table_info('payments')) AS column_count,
(SELECT COUNT(*) FROM payments) AS row_count

UNION ALL

SELECT 'productlines' as table_name, 
(SELECT COUNT(*) FROM pragma_table_info('productlines')) AS column_count,
(SELECT COUNT(*) FROM productlines) AS row_count

UNION ALL

SELECT 'products' as table_name, 
(SELECT COUNT(*) FROM pragma_table_info('products')) AS column_count,
(SELECT COUNT(*) FROM products) AS row_count;

-- Compute low stock for each product category.

SELECT od.productCode, ROUND(SUM(od.quantityOrdered) * 1.0 / p.quantityInStock, 2) AS low_stock
    FROM orderdetails AS od
      JOIN products AS p ON od.productCode = p.productCode
  GROUP BY od.productCode
  ORDER BY low_stock DESC
   LIMIT 10;

-- Compute product performance for each product

SELECT p.productCode, p.productName, ROUND(SUM(od.quantityOrdered * od.priceEach), 2) AS prod_perf
   FROM orderdetails AS od
    JOIN products AS p ON od.productCode = p.productCode
GROUP BY p.productCode, p.productName
ORDER BY prod_perf DESC
LIMIT 10;

-- Combine the two metrics from above

WITH 
low_stock_table AS (
SELECT od.productCode, 
				  ROUND(SUM(od.quantityOrdered) * 1.0 / p.quantityInStock, 2) AS low_stock
				  FROM orderdetails AS od
			      JOIN products AS p ON od.productCode = p.productCode
  GROUP BY od.productCode
  ORDER BY low_stock DESC
   LIMIT 10
   ),
   
priority_restock AS (
SELECT od.productCode, 
				 ROUND(SUM(od.quantityOrdered * od.priceEach), 2) AS prod_perf
   FROM orderdetails AS od
     JOIN low_stock_table AS ls 
         ON od.productCode = ls.productCode
 GROUP BY od.productCode
 ORDER BY prod_perf DESC
  LIMIT 10
)

SELECT p.productName, p.productLine
FROM products AS p
JOIN priority_restock AS pr ON p.productCode = pr.productCode;

-- Join products, orderdetails, and orders tables

SELECT o.customerNumber, SUM(od.quantityOrdered * (od.priceEach - p.buyPrice)) AS profit
FROM orderdetails AS od
JOIN products as p
ON od.productCode = p.productCode
JOIN orders AS o
ON od.orderNumber = o.orderNumber
GROUP BY customerNumber
ORDER BY profit DESC;

-- Find Top 5 Highest Spending Customers

WITH
top_customers AS (
SELECT o.customerNumber, SUM(od.quantityOrdered * (od.priceEach - p.buyPrice)) AS profit
FROM orderdetails AS od
JOIN products as p
ON od.productCode = p.productCode
JOIN orders AS o
ON od.orderNumber = o.orderNumber
GROUP BY customerNumber
ORDER BY profit DESC
)

SELECT c.contactLastName, c.contactFirstName, c.city, c.country, t.profit
FROM customers AS c
JOIN top_customers AS t
ON c.customerNumber = t.customerNumber
ORDER BY t.profit DESC
LIMIT 5;

-- Find Bottom Five Spenders

WITH 
money_in_by_customer_table AS (
SELECT o.customerNumber, SUM(quantityOrdered * (priceEach - buyPrice)) AS profit
  FROM products p
  JOIN orderdetails od
    ON p.productCode = od.productCode
  JOIN orders o
    ON o.orderNumber = od.orderNumber
 GROUP BY o.customerNumber
)

SELECT contactLastName, contactFirstName, city, country, mc.profit
  FROM customers c
  JOIN money_in_by_customer_table mc
    ON mc.customerNumber = c.customerNumber
 ORDER BY mc.profit
 LIMIT 5;
 
-- Find the Customer Lifetime Value (LTV), which represents the average amount of money a customer generates.

WITH 
profits_per_customer AS (
SELECT o.customerNumber, SUM(od.quantityOrdered * (od.priceEach - p.buyPrice)) AS profit
FROM orderdetails AS od
JOIN products as p
ON od.productCode = p.productCode
JOIN orders AS o
ON od.orderNumber = o.orderNumber
GROUP BY o.customerNumber
ORDER BY profit DESC
)

SELECT AVG(profit) AS customer_LTV
FROM profits_per_customer;

-- Average profit per order

WITH

profits_per_customer AS (
SELECT p.productCode, SUM(od.quantityOrdered * (od.priceEach - p.buyPrice)) AS profit
FROM orderdetails AS od
JOIN products AS p
ON od.productCode = p.productCode
GROUP BY od.productCode
)

SELECT p.productName, AVG(ppc.profit) AS avg_profit
FROM products AS p
JOIN profits_per_customer as ppc
ON p.productCode = ppc.productCode
JOIN orderdetails AS od
ON p.productCode = od.productCode
GROUP BY p.productName
ORDER BY avg_profit DESC;
