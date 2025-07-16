-- =============================================================================
-- EXECUTIVE SUMMARY QUERIES
-- =============================================================================
-- Quick overview queries for management dashboards and presentations

-- Overall Business Performance Summary
SELECT 
    'Overall Business Metrics' as metric_category,
    
    -- VOLUME METRICS
    COUNT(DISTINCT order_id) as total_orders,
    COUNT(DISTINCT customer_id) as total_customers,
    COUNT(DISTINCT category_english) as total_categories,
    COUNT(*) as total_items_sold,
    
    -- FINANCIAL METRICS
    SUM(payment_value) as total_gmv,
    SUM(price) as total_revenue,
    SUM(freight_value) as total_freight,
    ROUND(AVG(payment_value), 2) as avg_order_value,
    
    -- CUSTOMER SATISFACTION
    ROUND(AVG(review_score), 2) as overall_satisfaction,
    ROUND(
        (SUM(CASE WHEN review_score <= 2 THEN 1 ELSE 0 END) * 100.0) / 
        NULLIF(SUM(CASE WHEN review_score IS NOT NULL THEN 1 ELSE 0 END), 0), 2
    ) as overall_return_rate,
    
    -- EFFICIENCY METRICS
    ROUND(
        (SUM(freight_value) * 100.0) / NULLIF(SUM(price), 0), 2
    ) as freight_to_revenue_ratio,
    
    ROUND(
        (SUM(CASE WHEN review_score <= 2 THEN price + freight_value ELSE 0 END) * 100.0) / 
        NULLIF(SUM(price + freight_value), 0), 2
    ) as total_leakage_rate

FROM master_ecommerce_dataset
WHERE order_date >= '2017-01-01';

-- Top 10 Categories Performance Dashboard
SELECT 
    category_english,
    COUNT(DISTINCT order_id) as orders,
    SUM(payment_value) as gmv,
    SUM(price) as revenue,
    ROUND(AVG(review_score), 2) as satisfaction,
    ROUND(
        (SUM(CASE WHEN review_score <= 2 THEN 1 ELSE 0 END) * 100.0) / 
        NULLIF(SUM(CASE WHEN review_score IS NOT NULL THEN 1 ELSE 0 END), 0), 2
    ) as return_rate,
    ROW_NUMBER() OVER (ORDER BY SUM(payment_value) DESC) as gmv_rank

FROM master_ecommerce_dataset
WHERE order_date >= '2017-01-01'
GROUP BY category_english
ORDER BY gmv DESC
LIMIT 10;

-- Customer Segment Distribution
SELECT 
    CASE 
        WHEN total_ltv > 1000 THEN 'High Value (>$1000)'
        WHEN total_ltv > 500 THEN 'Medium Value ($500-$1000)'
        WHEN total_ltv > 100 THEN 'Low Value ($100-$500)'
        ELSE 'Very Low Value (<$100)'
    END as customer_segment,
    
    COUNT(*) as customer_count,
    SUM(total_ltv) as segment_revenue,
    ROUND(AVG(total_ltv), 2) as avg_ltv,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as customer_percentage,
    ROUND(SUM(total_ltv) * 100.0 / SUM(SUM(total_ltv)) OVER (), 2) as revenue_percentage

FROM (
    SELECT 
        customer_id,
        SUM(payment_value) as total_ltv
    FROM master_ecommerce_dataset
    WHERE order_date >= '2017-01-01'
    GROUP BY customer_id
) customer_totals
GROUP BY customer_segment
ORDER BY avg_ltv DESC;
