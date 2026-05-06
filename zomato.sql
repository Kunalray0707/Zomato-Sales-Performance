-- 1. CREATE DATABASE
CREATE DATABASE zomato_db;
USE zomato_db;

-- PERFORMANCE SETTINGS (to avoid connection timeout)
-- Increase read timeout (for large SELECT queries)
SET GLOBAL net_read_timeout = 600;
-- Increase write timeout (for large JOIN/INSERT queries)
SET GLOBAL net_write_timeout = 600;
-- Increase session timeout (prevents disconnection)
SET GLOBAL wait_timeout = 600;



-- 2. CREATE TABLES
-- Restaurant table
CREATE TABLE restaurant (
    restaurant_id VARCHAR(100),
    name VARCHAR(255),
    country VARCHAR(100),
    city VARCHAR(100),
    rating DECIMAL(5,2),
    rating_count VARCHAR(100),
    cuisine VARCHAR(255),
    link TEXT,
    address TEXT
);

-- Food table
CREATE TABLE food (
    food_id VARCHAR(20) PRIMARY KEY,
    name VARCHAR(255),
    type VARCHAR(100)
);

-- Users table
CREATE TABLE users (
    user_id INT,
    name VARCHAR(255),
    age INT,
    gender VARCHAR(20),
    marital_status VARCHAR(50),
    occupation VARCHAR(100)
);

-- Orders table (fact table)
CREATE TABLE orders (
    order_date DATE,
    sales_qty INT,
    sales_amount DECIMAL(10,2),
    currency VARCHAR(10),
    user_id INT,
    r_id VARCHAR(100)
);

-- Menu table
CREATE TABLE menu (
    menu_id VARCHAR(100) PRIMARY KEY,
    restaurant_id VARCHAR(100),
    item_name VARCHAR(255),
    price VARCHAR(50),
    food_id VARCHAR(100),
    category VARCHAR(255)
);

-- PERFORMANCE OPTIMIZATION (INDEXING)
-- Speed up user-based joins
CREATE INDEX idx_orders_user ON orders(user_id);
-- Speed up restaurant joins
CREATE INDEX idx_orders_restaurant ON orders(r_id);
-- Speed up restaurant lookups
CREATE INDEX idx_restaurant_id ON restaurant(restaurant_id);


-- 3. DATA TYPE CLEANING
-- Ensure correct ID formats
ALTER TABLE users MODIFY user_id INT;
ALTER TABLE orders MODIFY user_id INT;

ALTER TABLE restaurant MODIFY restaurant_id VARCHAR(100);
ALTER TABLE menu MODIFY restaurant_id VARCHAR(100);
ALTER TABLE orders MODIFY r_id VARCHAR(100);

-- 4. DATA CLEANING (NULL FIX)
-- Fix empty values in orders
UPDATE orders SET user_id = NULL WHERE user_id = '';
UPDATE orders SET r_id = NULL WHERE r_id = '';

-- Fix missing menu items
UPDATE menu
SET item_name = 'Unknown Item'
WHERE item_name IS NULL;


-- 5. IMPORT DATA (LOAD CSV)
-- Import Orders (with date conversion)
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/orders.csv'
INTO TABLE orders
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(@order_date, sales_qty, sales_amount, currency, user_id, r_id)
SET order_date = STR_TO_DATE(@order_date, '%d-%m-%Y');


-- Import Restaurant (with rating cleaning)
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/restaurant.csv'
INTO TABLE restaurant
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(restaurant_id, name, country, city, @rating, rating_count, cuisine, link, address)
SET rating = CASE
    WHEN @rating IS NULL OR @rating = '' THEN NULL
    WHEN @rating IN ('--', 'Too Few Ratings') THEN NULL
    WHEN @rating LIKE '%+%' THEN NULL
    ELSE @rating
END;


-- Import Users
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/users.csv'
INTO TABLE users
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(user_id, name, age, gender, marital_status, occupation);


-- 6. DATA VALIDATION QUERIES
-- Check table data
SELECT * FROM users;
SELECT * FROM orders;
SELECT * FROM restaurant;
SELECT * FROM food;
SELECT * FROM menu;

-- Check orphan records in orders
SELECT r_id FROM orders
WHERE r_id NOT IN (SELECT restaurant_id FROM restaurant);

-- Check duplicate restaurants
SELECT restaurant_id, COUNT(*)
FROM restaurant
GROUP BY restaurant_id
HAVING COUNT(*) > 1;


-- 7. REMOVE DUPLICATES
DELETE r1 FROM restaurant r1
JOIN restaurant r2
ON r1.restaurant_id = r2.restaurant_id
AND r1.name = r2.name;



-- 8. PRIMARY KEYS
ALTER TABLE users ADD PRIMARY KEY (user_id);
ALTER TABLE restaurant ADD PRIMARY KEY (restaurant_id);
ALTER TABLE food ADD PRIMARY KEY (food_id);
ALTER TABLE menu ADD PRIMARY KEY (menu_id);



-- 9. FOREIGN KEYS (RELATIONSHIPS)
-- Users → Orders
ALTER TABLE orders
ADD CONSTRAINT fk_orders_users
FOREIGN KEY (user_id) REFERENCES users(user_id);

-- Restaurant → Orders
ALTER TABLE orders
ADD CONSTRAINT fk_orders_restaurant
FOREIGN KEY (r_id) REFERENCES restaurant(restaurant_id);

-- Restaurant → Food
ALTER TABLE food
ADD CONSTRAINT fk_food_restaurant
FOREIGN KEY (restaurant_id) REFERENCES restaurant(restaurant_id);

-- Restaurant → Menu
ALTER TABLE menu
ADD CONSTRAINT fk_menu_restaurant
FOREIGN KEY (restaurant_id) REFERENCES restaurant(restaurant_id);


-- Total Revenue
SELECT SUM(sales_amount) AS total_revenue FROM orders;

-- Top 5 Restaurants by Revenue
SELECT r.name, SUM(o.sales_amount) AS revenue
FROM orders o
JOIN restaurant r ON o.r_id = r.restaurant_id
GROUP BY r.name
ORDER BY revenue DESC
LIMIT 5;

-- Top Users by Spending
SELECT u.name, SUM(o.sales_amount) AS total_spent
FROM users u
JOIN orders o ON u.user_id = o.user_id
GROUP BY u.name
ORDER BY total_spent DESC;

-- City-wise Revenue
SELECT r.city, SUM(o.sales_amount) AS revenue
FROM orders o
JOIN restaurant r ON o.r_id = r.restaurant_id
GROUP BY r.city;

-- Monthly Sales Trend
SELECT DATE_FORMAT(order_date, '%Y-%m') AS month,
SUM(sales_amount) AS revenue
FROM orders
GROUP BY month;

-- Gender-wise Spending
SELECT u.gender, SUM(o.sales_amount) AS total_spent
FROM users u
JOIN orders o ON u.user_id = o.user_id
GROUP BY u.gender;

-- Age Group Analysis
SELECT 
CASE 
WHEN age < 25 THEN 'Youth'
WHEN age BETWEEN 25 AND 40 THEN 'Adult'
ELSE 'Senior'
END AS age_group,
SUM(o.sales_amount) AS revenue
FROM users u
JOIN orders o ON u.user_id = o.user_id
GROUP BY age_group;

-- Most Ordered Restaurants
SELECT r.name, SUM(o.sales_qty) AS total_qty
FROM orders o
JOIN restaurant r ON o.r_id = r.restaurant_id
GROUP BY r.name
ORDER BY total_qty DESC;

-- Average Rating by City
SELECT city, AVG(rating) AS avg_rating
FROM restaurant
GROUP BY city;

-- Popular Cuisine
SELECT cuisine, COUNT(*) AS total_orders
FROM restaurant r
JOIN orders o ON r.restaurant_id = o.r_id
GROUP BY cuisine
ORDER BY total_orders DESC;

--  High Value Orders (>1000)
SELECT * FROM orders
WHERE sales_amount > 1000;

--  Repeat Customers (more than 5 orders)
SELECT user_id, COUNT(*) AS total_orders
FROM orders
GROUP BY user_id
HAVING COUNT(*) > 5;

--  Top 3 Cities by Orders
SELECT r.city, COUNT(*) AS total_orders
FROM orders o
JOIN restaurant r ON o.r_id = r.restaurant_id
GROUP BY r.city
ORDER BY total_orders DESC
LIMIT 3;

--  Average Order Value
SELECT AVG(sales_amount) AS avg_order_value
FROM orders;

--  Most Active Users
SELECT user_id, COUNT(*) AS orders_count
FROM orders
GROUP BY user_id
ORDER BY orders_count DESC
LIMIT 10;

--  Restaurant Performance Score
SELECT r.name,
COUNT(o.sales_amount) AS orders,
SUM(o.sales_amount) AS revenue,
AVG(r.rating) AS rating
FROM restaurant r
JOIN orders o ON r.restaurant_id = o.r_id
GROUP BY r.name;

--  Monthly Order Count
SELECT DATE_FORMAT(order_date, '%Y-%m') AS month,
COUNT(*) AS total_orders
FROM orders
GROUP BY month;

--  Low Rated Restaurants (<3)
SELECT * FROM restaurant
WHERE rating < 3;

--  Food Type Distribution
SELECT type, COUNT(*) AS count
FROM food
GROUP BY type;

-- High Revenue Cities (>50000)
SELECT r.city, SUM(o.sales_amount) AS revenue
FROM orders o
JOIN restaurant r ON o.r_id = r.restaurant_id
GROUP BY r.city
HAVING revenue > 50000;


-- TESTING LARGE TABLE (avoid crash)
-- Fetch only sample data to check structure
SELECT * FROM orders LIMIT 100;

-- Check restaurant sample data
SELECT * FROM restaurant;
