-- =============================================================================
-- LOGISTICS LEAKAGE ANALYSIS
-- =============================================================================
-- This script analyzes freight costs and return-related logistics losses
-- Key metrics: freight efficiency, return logistics costs, delivery performance

-- Main Logistics Leakage Analysis
SELECT 
    category_english as product_category,
    
    -- BASIC FREIGHT METRICS
    COUNT(DISTINCT order_id) as total_orders,
    SUM(freight_value) as total_freight_cost,
    ROUND(AVG(freight_value), 2) as avg_freight_per_order,
    
    -- FREIGHT EFFICIENCY RATIOS
    SUM(price) as total_product_value,
    ROUND(
        (SUM(freight_value) * 100.0) / NULLIF(SUM(price), 0), 2
    ) as freight_to_product_ratio,
    
    -- RETURN-RELATED LOGISTICS LOSSES
    -- When customers return items, we lose both product value and freight
    SUM(CASE WHEN review_score <= 2 THEN price ELSE 0 END) as return_product_loss,
    SUM(CASE WHEN review_score <= 2 THEN freight_value ELSE 0 END) as return_freight_loss,
    
    -- TOTAL RETURN LOGISTICS IMPACT
    SUM(CASE WHEN review_score <= 2 THEN price + freight_value ELSE 0 END) as total_return_loss,
    
    -- LEAKAGE PERCENTAGES
    ROUND(
        (SUM(CASE WHEN review_score <= 2 THEN freight_value ELSE 0 END) * 100.0) / 
        NULLIF(SUM(freight_value), 0), 2
    ) as freight_leakage_percentage,
    
    -- LOGISTICS EFFICIENCY SCORE
    -- Higher score = better logistics efficiency
    ROUND(
        100 - (SUM(CASE WHEN review_score <= 2 THEN freight_value ELSE 0 END) * 100.0) / 
        NULLIF(SUM(freight_value), 0), 2
    ) as logistics_efficiency_score,
    
    -- COST PER SUCCESSFUL DELIVERY
    ROUND(
        SUM(freight_value) / NULLIF(
            COUNT(*) - SUM(CASE WHEN review_score <= 2 THEN 1 ELSE 0 END), 0
        ), 2
    ) as cost_per_successful_delivery

FROM master_ecommerce_dataset
WHERE order_date >= '2017-01-01'
GROUP BY category_english
ORDER BY total_return_loss DESC;

-- Monthly Logistics Leakage Trends
-- Track logistics performance over time
SELECT 
    order_period,
    category_english,
    
    -- Monthly freight metrics
    COUNT(DISTINCT order_id) as monthly_orders,
    SUM(freight_value) as monthly_freight_cost,
    SUM(CASE WHEN review_score <= 2 THEN freight_value ELSE 0 END) as monthly_freight_loss,
    
    -- Monthly leakage rate
    ROUND(
        (SUM(CASE WHEN review_score <= 2 THEN freight_value ELSE 0 END) * 100.0) / 
        NULLIF(SUM(freight_value), 0), 2
    ) as monthly_leakage_rate,
    
    -- Efficiency trend
    ROUND(
        100 - (SUM(CASE WHEN review_score <= 2 THEN freight_value ELSE 0 END) * 100.0) / 
        NULLIF(SUM(freight_value), 0), 2
    ) as monthly_efficiency_score,
    
    -- Previous month comparison
    LAG(SUM(freight_value)) OVER (
        PARTITION BY category_english 
        ORDER BY order_period
    ) as previous_month_freight

FROM master_ecommerce_dataset
WHERE order_date >= '2017-01-01'
GROUP BY order_period, category_english
ORDER BY order_period DESC, monthly_freight_loss DESC;

-- Logistics Performance Segmentation
-- Classify categories by logistics performance
WITH logistics_performance AS (
    SELECT 
        category_english,
        SUM(freight_value) as total_freight,
        SUM(CASE WHEN review_score <= 2 THEN freight_value ELSE 0 END) as freight_loss,
        COUNT(DISTINCT order_id) as total_orders,
        ROUND(AVG(freight_value), 2) as avg_freight,
        
        -- Calculate leakage rate
        ROUND(
            (SUM(CASE WHEN review_score <= 2 THEN freight_value ELSE 0 END) * 100.0) / 
            NULLIF(SUM(freight_value), 0), 2
        ) as leakage_rate,
        
        -- Calculate efficiency score
        ROUND(
            100 - (SUM(CASE WHEN review_score <= 2 THEN freight_value ELSE 0 END) * 100.0) / 
            NULLIF(SUM(freight_value), 0), 2
        ) as efficiency_score
        
    FROM master_ecommerce_dataset
    WHERE order_date >= '2017-01-01'
    GROUP BY category_english
)
SELECT 
    category_english,
    total_freight,
    freight_loss,
    leakage_rate,
    efficiency_score,
    avg_freight,
    
    -- Performance classification
    CASE 
        WHEN efficiency_score >= 95 THEN 'Excellent'
        WHEN efficiency_score >= 90 THEN 'Good'
        WHEN efficiency_score >= 85 THEN 'Average'
        WHEN efficiency_score >= 80 THEN 'Below Average'
        ELSE 'Poor'
    END as logistics_performance_tier,
    
    -- Priority for improvement (high freight loss + low efficiency)
    CASE 
        WHEN freight_loss > 1000 AND efficiency_score < 85 THEN 'High Priority'
        WHEN freight_loss > 500 AND efficiency_score < 90 THEN 'Medium Priority'
        ELSE 'Low Priority'
    END as improvement_priority

FROM logistics_performance
ORDER BY freight_loss DESC;

-- State-wise Logistics Analysis
-- Understanding regional logistics challenges
SELECT 
    customer_state,
    COUNT(DISTINCT order_id) as state_orders,
    SUM(freight_value) as state_total_freight,
    ROUND(AVG(freight_value), 2) as state_avg_freight,
    
    -- State return rate
    ROUND(
        (SUM(CASE WHEN review_score <= 2 THEN 1 ELSE 0 END) * 100.0) / 
        NULLIF(SUM(CASE WHEN review_score IS NOT NULL THEN 1 ELSE 0 END), 0), 2
    ) as state_return_rate,
    
    -- State logistics leakage
    SUM(CASE WHEN review_score <= 2 THEN freight_value ELSE 0 END) as state_freight_loss,
    ROUND(
        (SUM(CASE WHEN review_score <= 2 THEN freight_value ELSE 0 END) * 100.0) / 
        NULLIF(SUM(freight_value), 0), 2
    ) as state_leakage_rate

FROM master_ecommerce_dataset
WHERE order_date >= '2017-01-01'
  AND customer_state IS NOT NULL
GROUP BY customer_state
ORDER BY state_freight_loss DESC
LIMIT 15; -- Top 15 states by freight loss