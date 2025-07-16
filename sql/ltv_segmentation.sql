-- =============================================================================
-- CUSTOMER LIFETIME VALUE (LTV) SEGMENTATION
-- =============================================================================
-- This script segments customers based on their total spending
-- Creates quartiles and analyzes customer behavior patterns

-- Step 1: Calculate Customer Lifetime Value
WITH customer_ltv AS (
    SELECT 
        customer_id,
        customer_state,
        
        -- BASIC CUSTOMER METRICS
        COUNT(DISTINCT order_id) as total_orders,
        COUNT(*) as total_items_purchased,
        MIN(order_date) as first_order_date,
        MAX(order_date) as last_order_date,
        
        -- FINANCIAL METRICS
        SUM(payment_value) as total_ltv,
        SUM(price) as total_product_spending,
        SUM(freight_value) as total_freight_spending,
        ROUND(AVG(payment_value), 2) as avg_order_value,
        
        -- SATISFACTION METRICS
        ROUND(AVG(review_score), 2) as avg_satisfaction,
        SUM(CASE WHEN review_score <= 2 THEN 1 ELSE 0 END) as total_poor_reviews,
        
        -- CUSTOMER LIFECYCLE
        (MAX(order_date) - MIN(order_date)) as customer_lifecycle_days,
        
        -- FAVORITE CATEGORIES
        array_agg(DISTINCT category_english) as purchased_categories,
        COUNT(DISTINCT category_english) as category_diversity

    FROM master_ecommerce_dataset
    WHERE order_date >= '2017-01-01'
    GROUP BY customer_id, customer_state
),

-- Step 2: Create LTV Quartiles
ltv_quartiles AS (
    SELECT 
        *,
        -- Calculate quartiles for segmentation
        NTILE(4) OVER (ORDER BY total_ltv) as ltv_quartile,
        
        -- Calculate percentiles for more detailed analysis
        PERCENT_RANK() OVER (ORDER BY total_ltv) as ltv_percentile,
        
        -- Classify customers
        CASE 
            WHEN NTILE(4) OVER (ORDER BY total_ltv) = 4 THEN 'Top 25% (Champions)'
            WHEN NTILE(4) OVER (ORDER BY total_ltv) = 3 THEN '50-75% (Loyal)'
            WHEN NTILE(4) OVER (ORDER BY total_ltv) = 2 THEN '25-50% (Potential)'
            ELSE 'Bottom 25% (Low Value)'
        END as ltv_segment

    FROM customer_ltv
    WHERE total_ltv > 0
)

-- Main LTV Segmentation Analysis
SELECT 
    ltv_segment,
    
    -- SEGMENT SIZE
    COUNT(*) as customer_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as segment_percentage,
    
    -- LTV METRICS
    SUM(total_ltv) as segment_total_ltv,
    ROUND(AVG(total_ltv), 2) as segment_avg_ltv,
    MIN(total_ltv) as segment_min_ltv,
    MAX(total_ltv) as segment_max_ltv,
    
    -- ORDER BEHAVIOR
    ROUND(AVG(total_orders), 2) as avg_orders_per_customer,
    ROUND(AVG(total_items_purchased), 2) as avg_items_per_customer,
    ROUND(AVG(avg_order_value), 2) as avg_order_value_segment,
    
    -- CUSTOMER SATISFACTION
    ROUND(AVG(avg_satisfaction), 2) as segment_avg_satisfaction,
    ROUND(AVG(total_poor_reviews), 2) as avg_poor_reviews_per_customer,
    
    -- CUSTOMER LIFECYCLE
    ROUND(AVG(customer_lifecycle_days), 0) as avg_lifecycle_days,
    ROUND(AVG(category_diversity), 2) as avg_categories_per_customer,
    
    -- BUSINESS IMPACT
    ROUND(
        (SUM(total_ltv) * 100.0) / SUM(SUM(total_ltv)) OVER (), 2
    ) as revenue_contribution_percentage

FROM ltv_quartiles
GROUP BY ltv_segment
ORDER BY segment_avg_ltv DESC;

-- Customer Behavior by LTV Segment
-- Detailed breakdown of how different segments behave
SELECT 
    ltv_segment,
    customer_state,
    COUNT(*) as customers_in_state,
    ROUND(AVG(total_ltv), 2) as avg_ltv_in_state,
    ROUND(AVG(total_orders), 2) as avg_orders_in_state,
    ROUND(AVG(avg_satisfaction), 2) as avg_satisfaction_in_state

FROM ltv_quartiles
WHERE customer_state IS NOT NULL
GROUP BY ltv_segment, customer_state
ORDER BY ltv_segment, avg_ltv_in_state DESC;

-- Category Preferences by LTV Segment
-- Understanding what high-value customers buy
WITH segment_category_analysis AS (
    SELECT 
        lq.ltv_segment,
        med.category_english,
        COUNT(*) as category_purchases,
        SUM(med.payment_value) as category_revenue,
        COUNT(DISTINCT med.customer_id) as unique_customers,
        ROUND(AVG(med.payment_value), 2) as avg_spend_per_purchase
    FROM ltv_quartiles lq
    JOIN master_ecommerce_dataset med ON lq.customer_id = med.customer_id
    WHERE med.order_date >= '2017-01-01'
    GROUP BY lq.ltv_segment, med.category_english
),
segment_totals AS (
    SELECT 
        ltv_segment,
        SUM(category_purchases) as total_segment_purchases,
        SUM(category_revenue) as total_segment_revenue
    FROM segment_category_analysis
    GROUP BY ltv_segment
)
SELECT 
    sca.ltv_segment,
    sca.category_english,
    sca.category_purchases,
    sca.category_revenue,
    sca.unique_customers,
    sca.avg_spend_per_purchase,
    
    -- Category preference percentage within segment
    ROUND(
        (sca.category_purchases * 100.0) / st.total_segment_purchases, 2
    ) as category_purchase_percentage,
    
    ROUND(
        (sca.category_revenue * 100.0) / st.total_segment_revenue, 2
    ) as category_revenue_percentage,
    
    -- Rank categories within each segment
    ROW_NUMBER() OVER (
        PARTITION BY sca.ltv_segment 
        ORDER BY sca.category_revenue DESC
    ) as category_rank_in_segment

FROM segment_category_analysis sca
JOIN segment_totals st ON sca.ltv_segment = st.ltv_segment
ORDER BY sca.ltv_segment, category_rank_in_segment;

-- Customer Acquisition and Retention Analysis
-- When did customers from each segment first purchase?
SELECT 
    ltv_segment,
    EXTRACT(YEAR FROM first_order_date) as acquisition_year,
    EXTRACT(MONTH FROM first_order_date) as acquisition_month,
    COUNT(*) as customers_acquired,
    ROUND(AVG(total_ltv), 2) as avg_ltv_for_cohort,
    ROUND(AVG(total_orders), 2) as avg_orders_for_cohort,
    ROUND(AVG(customer_lifecycle_days), 0) as avg_lifecycle_for_cohort

FROM ltv_quartiles
GROUP BY ltv_segment, acquisition_year, acquisition_month
ORDER BY ltv_segment, acquisition_year, acquisition_month;

-- High-Value Customer Deep Dive
-- Focus on top 25% customers for retention strategies
SELECT 
    customer_id,
    customer_state,
    total_ltv,
    total_orders,
    total_items_purchased,
    first_order_date,
    last_order_date,
    customer_lifecycle_days,
    avg_satisfaction,
    total_poor_reviews,
    category_diversity,
    
    -- Customer value tier within top 25%
    CASE 
        WHEN total_ltv > (SELECT PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY total_ltv) FROM ltv_quartiles) THEN 'VIP (Top 5%)'
        WHEN total_ltv > (SELECT PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY total_ltv) FROM ltv_quartiles) THEN 'Premium (Top 10%)'
        ELSE 'High Value (Top 25%)'
    END as value_tier,
    
    -- Recency analysis
    CASE 
        WHEN last_order_date > CURRENT_DATE - INTERVAL '30 days' THEN 'Recent'
        WHEN last_order_date > CURRENT_DATE - INTERVAL '90 days' THEN 'Moderate'
        ELSE 'At Risk'
    END as recency_status

FROM ltv_quartiles
WHERE ltv_segment = 'Top 25% (Champions)'
ORDER BY total_ltv DESC;
