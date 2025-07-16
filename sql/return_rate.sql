-- =============================================================================
-- RETURN RATE ANALYSIS BY CATEGORY
-- =============================================================================
-- This script calculates return rates using review scores as a proxy
-- Assumption: review_score <= 2 indicates a likely return/refund

-- Main Return Rate Analysis
SELECT 
    category_english as product_category,
    
    -- BASIC METRICS
    COUNT(DISTINCT order_id) as total_orders,
    COUNT(*) as total_items,
    
    -- RETURN CALCULATION
    -- Using review_score <= 2 as return proxy
    SUM(CASE WHEN review_score <= 2 THEN 1 ELSE 0 END) as likely_returns,
    SUM(CASE WHEN review_score IS NULL THEN 1 ELSE 0 END) as no_review_orders,
    
    -- RETURN RATE CALCULATION
    -- Method 1: Return rate based on all orders
    ROUND(
        (SUM(CASE WHEN review_score <= 2 THEN 1 ELSE 0 END) * 100.0) / 
        NULLIF(COUNT(*), 0), 2
    ) as return_rate_all_orders,
    
    -- Method 2: Return rate based on reviewed orders only
    ROUND(
        (SUM(CASE WHEN review_score <= 2 THEN 1 ELSE 0 END) * 100.0) / 
        NULLIF(SUM(CASE WHEN review_score IS NOT NULL THEN 1 ELSE 0 END), 0), 2
    ) as return_rate_reviewed_orders,
    
    -- SATISFACTION BREAKDOWN
    SUM(CASE WHEN review_score = 1 THEN 1 ELSE 0 END) as score_1_count,
    SUM(CASE WHEN review_score = 2 THEN 1 ELSE 0 END) as score_2_count,
    SUM(CASE WHEN review_score = 3 THEN 1 ELSE 0 END) as score_3_count,
    SUM(CASE WHEN review_score = 4 THEN 1 ELSE 0 END) as score_4_count,
    SUM(CASE WHEN review_score = 5 THEN 1 ELSE 0 END) as score_5_count,
    
    -- AVERAGE SATISFACTION SCORE
    ROUND(AVG(review_score), 2) as avg_satisfaction_score,
    
    -- FINANCIAL IMPACT OF RETURNS
    SUM(CASE WHEN review_score <= 2 THEN price ELSE 0 END) as potential_return_revenue_loss,
    SUM(CASE WHEN review_score <= 2 THEN freight_value ELSE 0 END) as potential_return_freight_loss,
    
    -- RETURN RATE TREND INDICATORS
    ROUND(
        (SUM(CASE WHEN review_score <= 2 THEN price + freight_value ELSE 0 END) * 100.0) / 
        NULLIF(SUM(price + freight_value), 0), 2
    ) as return_value_percentage

FROM master_ecommerce_dataset
WHERE order_date >= '2017-01-01'
GROUP BY category_english
ORDER BY return_rate_reviewed_orders DESC;

-- Monthly Return Rate Trends
-- Track how return rates change over time
SELECT 
    order_period,
    category_english,
    COUNT(*) as monthly_orders,
    SUM(CASE WHEN review_score <= 2 THEN 1 ELSE 0 END) as monthly_returns,
    
    -- Monthly return rate
    ROUND(
        (SUM(CASE WHEN review_score <= 2 THEN 1 ELSE 0 END) * 100.0) / 
        NULLIF(SUM(CASE WHEN review_score IS NOT NULL THEN 1 ELSE 0 END), 0), 2
    ) as monthly_return_rate,
    
    -- Average satisfaction score per month
    ROUND(AVG(review_score), 2) as monthly_avg_satisfaction,
    
    -- Previous month comparison
    LAG(ROUND(
        (SUM(CASE WHEN review_score <= 2 THEN 1 ELSE 0 END) * 100.0) / 
        NULLIF(SUM(CASE WHEN review_score IS NOT NULL THEN 1 ELSE 0 END), 0), 2
    )) OVER (
        PARTITION BY category_english 
        ORDER BY order_period
    ) as previous_month_return_rate

FROM master_ecommerce_dataset
WHERE order_date >= '2017-01-01'
  AND review_score IS NOT NULL
GROUP BY order_period, category_english
ORDER BY order_period DESC, monthly_return_rate DESC;

-- Return Rate Risk Categories
-- Classify categories by return risk level
WITH return_analysis AS (
    SELECT 
        category_english,
        COUNT(*) as total_orders,
        SUM(CASE WHEN review_score <= 2 THEN 1 ELSE 0 END) as returns,
        ROUND(
            (SUM(CASE WHEN review_score <= 2 THEN 1 ELSE 0 END) * 100.0) / 
            NULLIF(SUM(CASE WHEN review_score IS NOT NULL THEN 1 ELSE 0 END), 0), 2
        ) as return_rate,
        SUM(payment_value) as total_gmv
    FROM master_ecommerce_dataset
    WHERE review_score IS NOT NULL
    GROUP BY category_english
)
SELECT 
    category_english,
    return_rate,
    total_gmv,
    total_orders,
    returns,
    
    -- Risk classification
    CASE 
        WHEN return_rate > 15 THEN 'High Risk'
        WHEN return_rate > 8 THEN 'Medium Risk'
        WHEN return_rate > 3 THEN 'Low Risk'
        ELSE 'Very Low Risk'
    END as return_risk_level,
    
    -- Business impact score (combines return rate and GMV)
    ROUND(return_rate * (total_gmv / 1000), 2) as business_impact_score

FROM return_analysis
ORDER BY business_impact_score DESC;