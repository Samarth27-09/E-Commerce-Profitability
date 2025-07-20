-- =====================================================
-- OLIST E-COMMERCE PROFITABILITY & GROWTH ANALYSIS
-- Beginner-Friendly SQL Queries for PostgreSQL
-- =====================================================

-- =====================================================
-- QUERY 1: MONTHLY GMV AND ORDER COUNT
-- =====================================================
-- GMV = Gross Merchandise Value (total sales volume)
-- This shows business growth trends over time

SELECT 
    -- Extract year and month from order date
    DATE_TRUNC('month', o.order_purchase_timestamp) AS month_year,
    
    -- Count unique orders
    COUNT(DISTINCT o.order_id) AS total_orders,
    
    -- Sum all item prices to get GMV
    ROUND(SUM(oi.price)::numeric, 2) AS gmv_brl,
    
    -- Average order value
    ROUND(AVG(oi.price)::numeric, 2) AS avg_order_value_brl
    
FROM olist_orders_dataset o
JOIN olist_order_items_dataset oi ON o.order_id = oi.order_id

-- Only include completed orders
WHERE o.order_status = 'delivered'
    AND o.order_purchase_timestamp IS NOT NULL

GROUP BY DATE_TRUNC('month', o.order_purchase_timestamp)
ORDER BY month_year;


-- =====================================================
-- QUERY 2: AVERAGE ORDER VALUE AND REVENUE BY PRODUCT CATEGORY
-- =====================================================
-- This helps identify which product categories drive the most revenue

SELECT 
    -- Use English category names
    COALESCE(t.product_category_name_english, p.product_category_name, 'Unknown') AS category,
    
    -- Count of orders per category
    COUNT(DISTINCT oi.order_id) AS orders_count,
    
    -- Total revenue per category
    ROUND(SUM(oi.price)::numeric, 2) AS total_revenue_brl,
    
    -- Average order value per category
    ROUND(AVG(oi.price)::numeric, 2) AS avg_order_value_brl,
    
    -- Average items per order
    ROUND(AVG(oi.order_item_id)::numeric, 1) AS avg_items_per_order
    
FROM olist_order_items_dataset oi
JOIN olist_products_dataset p ON oi.product_id = p.product_id
LEFT JOIN product_category_name_translation t ON p.product_category_name = t.product_category_name
JOIN olist_orders_dataset o ON oi.order_id = o.order_id

-- Only delivered orders for accurate revenue calculation
WHERE o.order_status = 'delivered'

GROUP BY COALESCE(t.product_category_name_english, p.product_category_name, 'Unknown')
ORDER BY total_revenue_brl DESC;


-- =====================================================
-- QUERY 3: CONTRIBUTION MARGIN SIMULATION
-- =====================================================
-- Contribution Margin = Revenue - Variable Costs
-- We'll simulate: Price - Freight - Return Proxy - Commission (5%)

WITH order_metrics AS (
    SELECT 
        oi.order_id,
        oi.product_id,
        COALESCE(t.product_category_name_english, p.product_category_name, 'Unknown') AS category,
        
        -- Revenue components
        oi.price AS item_price,
        oi.freight_value AS shipping_cost,
        
        -- Commission simulation (assume 5% platform fee)
        ROUND((oi.price * 0.05)::numeric, 2) AS commission_fee,
        
        -- Return proxy using review score (score 1-2 = likely return)
        CASE 
            WHEN r.review_score <= 2 THEN oi.price * 0.3  -- 30% return cost for bad reviews
            ELSE 0 
        END AS return_proxy_cost
        
    FROM olist_order_items_dataset oi
    JOIN olist_products_dataset p ON oi.product_id = p.product_id
    LEFT JOIN product_category_name_translation t ON p.product_category_name = t.product_category_name
    JOIN olist_orders_dataset o ON oi.order_id = o.order_id
    LEFT JOIN olist_order_reviews_dataset r ON oi.order_id = r.order_id
    
    WHERE o.order_status = 'delivered'
)

SELECT 
    category,
    COUNT(*) AS total_items,
    
    -- Revenue
    ROUND(AVG(item_price)::numeric, 2) AS avg_item_price,
    ROUND(SUM(item_price)::numeric, 2) AS total_revenue,
    
    -- Costs
    ROUND(AVG(shipping_cost)::numeric, 2) AS avg_shipping_cost,
    ROUND(AVG(commission_fee)::numeric, 2) AS avg_commission_fee,
    ROUND(AVG(return_proxy_cost)::numeric, 2) AS avg_return_cost,
    
    -- Contribution Margin Calculation
    ROUND(AVG(item_price - shipping_cost - commission_fee - return_proxy_cost)::numeric, 2) AS avg_contribution_margin,
    
    -- Margin Percentage
    ROUND(
        (AVG(item_price - shipping_cost - commission_fee - return_proxy_cost) / AVG(item_price) * 100)::numeric, 
        1
    ) AS margin_percentage

FROM order_metrics
GROUP BY category
ORDER BY avg_contribution_margin DESC;


-- =====================================================
-- QUERY 4: RETURN RATE PER SKU/CATEGORY USING REVIEWS
-- =====================================================
-- We'll use review scores as a proxy for returns
-- Assumption: Review scores 1-2 indicate likely returns/dissatisfaction

WITH review_analysis AS (
    SELECT 
        p.product_id,
        COALESCE(t.product_category_name_english, p.product_category_name, 'Unknown') AS category,
        
        -- Count total orders with reviews
        COUNT(r.review_id) AS total_reviews,
        
        -- Count "bad" reviews (score 1-2) as return proxy
        COUNT(CASE WHEN r.review_score <= 2 THEN 1 END) AS likely_returns,
        
        -- Average review score
        ROUND(AVG(r.review_score)::numeric, 2) AS avg_review_score
        
    FROM olist_products_dataset p
    LEFT JOIN product_category_name_translation t ON p.product_category_name = t.product_category_name
    JOIN olist_order_items_dataset oi ON p.product_id = oi.product_id
    JOIN olist_orders_dataset o ON oi.order_id = o.order_id
    LEFT JOIN olist_order_reviews_dataset r ON o.order_id = r.order_id
    
    WHERE o.order_status = 'delivered'
        AND r.review_score IS NOT NULL
    
    GROUP BY p.product_id, COALESCE(t.product_category_name_english, p.product_category_name, 'Unknown')
)

-- SKU Level Analysis
SELECT 
    product_id,
    category,
    total_reviews,
    likely_returns,
    avg_review_score,
    
    -- Calculate return rate percentage
    ROUND(
        (likely_returns::float / NULLIF(total_reviews, 0) * 100)::numeric, 
        2
    ) AS estimated_return_rate_pct

FROM review_analysis
WHERE total_reviews >= 5  -- Only products with at least 5 reviews
ORDER BY estimated_return_rate_pct DESC, total_reviews DESC
LIMIT 50;

-- Category Level Summary
SELECT 
    category,
    COUNT(DISTINCT product_id) AS unique_products,
    SUM(total_reviews) AS total_reviews,
    SUM(likely_returns) AS total_likely_returns,
    ROUND(AVG(avg_review_score)::numeric, 2) AS category_avg_review_score,
    
    -- Category return rate
    ROUND(
        (SUM(likely_returns)::float / NULLIF(SUM(total_reviews), 0) * 100)::numeric, 
        2
    ) AS category_return_rate_pct

FROM review_analysis
WHERE total_reviews >= 5
GROUP BY category
ORDER BY category_return_rate_pct DESC;


-- =====================================================
-- BONUS QUERY: EXECUTIVE SUMMARY METRICS
-- =====================================================
-- Key metrics for your dashboard

SELECT 
    'Overall Business Metrics' AS metric_type,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(DISTINCT o.customer_id) AS total_customers,
    ROUND(SUM(oi.price)::numeric, 2) AS total_gmv_brl,
    ROUND(AVG(oi.price)::numeric, 2) AS avg_order_value_brl,
    ROUND(AVG(r.review_score)::numeric, 2) AS avg_customer_satisfaction

FROM olist_orders_dataset o
JOIN olist_order_items_dataset oi ON o.order_id = oi.order_id
LEFT JOIN olist_order_reviews_dataset r ON o.order_id = r.order_id

WHERE o.order_status = 'delivered'
    AND o.order_purchase_timestamp >= '2017-01-01'
    AND o.order_purchase_timestamp < '2019-01-01';