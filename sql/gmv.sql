-- =============================================================================
-- MASTER DATASET CREATION
-- =============================================================================
-- This script creates a comprehensive master dataset by joining all relevant tables
-- Perfect for beginners to understand complex joins step by step

-- Step 1: Start with the orders table as our base
-- Think of this as the foundation of our analysis
WITH base_orders AS (
    SELECT 
        o.order_id,
        o.customer_id,
        o.order_status,
        o.order_purchase_timestamp,
        o.order_delivered_customer_date,
        -- Extract year and month for easier analysis
        EXTRACT(YEAR FROM o.order_purchase_timestamp) as order_year,
        EXTRACT(MONTH FROM o.order_purchase_timestamp) as order_month,
        -- Create order date in YYYY-MM format
        TO_CHAR(o.order_purchase_timestamp, 'YYYY-MM') as order_period
    FROM clean_orders o
),

-- Step 2: Join order items to get product and pricing information
-- This tells us what was bought and how much it cost
order_details AS (
    SELECT 
        bo.*,
        oi.order_item_id,
        oi.product_id,
        oi.seller_id,
        oi.price,
        oi.freight_value
    FROM base_orders bo
    INNER JOIN clean_order_items oi ON bo.order_id = oi.order_id
),

-- Step 3: Add product information and category details
-- This gives us the product category for our analysis
product_details AS (
    SELECT 
        od.*,
        p.product_category_name,
        p.product_weight_g,
        p.product_length_cm,
        p.product_height_cm,
        p.product_width_cm,
        -- Translate category names to English
        COALESCE(pct.product_category_name_english, p.product_category_name) as category_english
    FROM order_details od
    INNER JOIN clean_products p ON od.product_id = p.product_id
    LEFT JOIN product_category_name_translation pct ON p.product_category_name = pct.product_category_name
),

-- Step 4: Add payment information
-- This shows us how customers paid and the total amount
payment_details AS (
    SELECT 
        pd.*,
        pay.payment_type,
        pay.payment_installments,
        pay.payment_value
    FROM product_details pd
    INNER JOIN clean_order_payments pay ON pd.order_id = pay.order_id
),

-- Step 5: Add customer review information
-- This helps us understand customer satisfaction
review_details AS (
    SELECT 
        payd.*,
        rev.review_score,
        rev.review_creation_date,
        -- Create a simple satisfaction flag
        CASE 
            WHEN rev.review_score <= 2 THEN 'Unsatisfied'
            WHEN rev.review_score = 3 THEN 'Neutral'
            WHEN rev.review_score >= 4 THEN 'Satisfied'
            ELSE 'No Review'
        END as satisfaction_level
    FROM payment_details payd
    LEFT JOIN clean_order_reviews rev ON payd.order_id = rev.order_id
),

-- Step 6: Add customer location information
-- This gives us geographical context
final_dataset AS (
    SELECT 
        rd.*,
        c.customer_city,
        c.customer_state,
        c.customer_zip_code_prefix
    FROM review_details rd
    INNER JOIN clean_customers c ON rd.customer_id = c.customer_id
)

-- Final Master Dataset
-- This is our complete dataset ready for analysis
SELECT 
    -- Order Information
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp::DATE as order_date,
    order_year,
    order_month,
    order_period,
    
    -- Product Information
    product_id,
    product_category_name,
    category_english,
    
    -- Financial Information
    price,
    freight_value,
    payment_value,
    payment_type,
    payment_installments,
    
    -- Customer Satisfaction
    review_score,
    satisfaction_level,
    
    -- Customer Location
    customer_city,
    customer_state,
    
    -- Calculated Fields for Analysis
    (price + freight_value) as total_item_cost,
    CASE 
        WHEN review_score <= 2 THEN 1 
        ELSE 0 
    END as is_return_proxy,
    
    -- Order sequence for customer analysis
    ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_purchase_timestamp) as customer_order_sequence

FROM final_dataset
ORDER BY order_purchase_timestamp DESC;

-- Save this as a materialized view for better performance
CREATE MATERIALIZED VIEW master_ecommerce_dataset AS
SELECT * FROM (
    -- Insert the complete query above here
    -- This creates a physical table that updates when refreshed
);

-- Create index for faster queries
CREATE INDEX idx_master_category ON master_ecommerce_dataset(category_english);
CREATE INDEX idx_master_date ON master_ecommerce_dataset(order_date);
CREATE INDEX idx_master_customer ON master_ecommerce_dataset(customer_id);