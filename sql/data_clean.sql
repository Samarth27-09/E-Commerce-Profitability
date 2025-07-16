-- =============================================================================
-- DATA CLEANING AND PREPARATION
-- =============================================================================
-- This script performs comprehensive data cleaning on the Olist dataset
-- Author: Data Analytics Team
-- Date: July 2025

-- First, let's examine the data quality in key tables
-- Check for NULL values and data inconsistencies

-- 1. Clean Orders Table
-- Remove orders with invalid statuses or missing critical information
CREATE OR REPLACE VIEW clean_orders AS
SELECT 
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date
FROM olist_orders_dataset 
WHERE 
    order_status IS NOT NULL 
    AND order_purchase_timestamp IS NOT NULL
    AND order_status NOT IN ('canceled', 'unavailable'); -- Filter out canceled orders

-- 2. Clean Order Items Table
-- Remove items with invalid prices or missing product information
CREATE OR REPLACE VIEW clean_order_items AS
SELECT 
    order_id,
    order_item_id,
    product_id,
    seller_id,
    shipping_limit_date,
    price,
    freight_value
FROM olist_order_items_dataset 
WHERE 
    price > 0 -- Remove items with zero or negative prices
    AND freight_value >= 0 -- Freight can be 0 but not negative
    AND product_id IS NOT NULL;

-- 3. Clean Products Table
-- Standardize product information
CREATE OR REPLACE VIEW clean_products AS
SELECT 
    product_id,
    product_category_name,
    product_name_lenght,
    product_description_lenght,
    product_photos_qty,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm
FROM olist_products_dataset 
WHERE 
    product_id IS NOT NULL
    AND product_category_name IS NOT NULL; -- Remove products without category

-- 4. Clean Order Payments Table
-- Remove invalid payment records
CREATE OR REPLACE VIEW clean_order_payments AS
SELECT 
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value
FROM olist_order_payments_dataset 
WHERE 
    payment_value > 0 -- Remove zero-value payments
    AND payment_installments > 0; -- Remove invalid installment data

-- 5. Clean Order Reviews Table
-- Standardize review scores
CREATE OR REPLACE VIEW clean_order_reviews AS
SELECT 
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    review_creation_date,
    review_answer_timestamp
FROM olist_order_reviews_dataset 
WHERE 
    review_score BETWEEN 1 AND 5; -- Valid review scores only

-- 6. Clean Customers Table
-- Remove duplicate customers and standardize location data
CREATE OR REPLACE VIEW clean_customers AS
SELECT DISTINCT
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
FROM olist_customers_dataset 
WHERE 
    customer_id IS NOT NULL
    AND customer_state IS NOT NULL;

-- Data Quality Check Query
-- Run this to verify data cleaning results
SELECT 
    'Orders' as table_name,
    COUNT(*) as clean_records,
    (SELECT COUNT(*) FROM olist_orders_dataset) as original_records,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM olist_orders_dataset), 2) as retention_rate
FROM clean_orders
UNION ALL
SELECT 
    'Order Items' as table_name,
    COUNT(*) as clean_records,
    (SELECT COUNT(*) FROM olist_order_items_dataset) as original_records,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM olist_order_items_dataset), 2) as retention_rate
FROM clean_order_items
UNION ALL
SELECT 
    'Products' as table_name,
    COUNT(*) as clean_records,
    (SELECT COUNT(*) FROM olist_products_dataset) as original_records,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM olist_products_dataset), 2) as retention_rate
FROM clean_products;