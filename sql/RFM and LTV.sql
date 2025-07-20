-- =====================================================
-- OLIST ADVANCED ANALYTICS
-- Part 1: Seller-Level Profitability Analysis
-- Part 2: Customer RFM Segmentation & LTV Modeling
-- =====================================================

-- =====================================================
-- PART 1: SELLER-LEVEL PROFITABILITY ANALYSIS
-- =====================================================

-- =====================================================
-- QUERY 1: SELLER-LEVEL PROFITABILITY (GMV, COST, MARGIN)
-- =====================================================
-- This analyzes each seller's performance and profitability

WITH seller_metrics AS (
    SELECT 
        s.seller_id,
        s.seller_city,
        s.seller_state,
        
        -- Revenue Metrics
        COUNT(DISTINCT oi.order_id) AS total_orders,
        COUNT(oi.order_item_id) AS total_items_sold,
        ROUND(SUM(oi.price)::numeric, 2) AS total_gmv_brl,
        ROUND(AVG(oi.price)::numeric, 2) AS avg_item_price_brl,
        
        -- Cost Metrics
        ROUND(SUM(oi.freight_value)::numeric, 2) AS total_shipping_cost_brl,
        ROUND(SUM(oi.price * 0.05)::numeric, 2) AS total_commission_brl, -- 5% platform fee
        
        -- Return Proxy (using review scores 1-2 as return indicator)
        ROUND(SUM(
            CASE 
                WHEN r.review_score <= 2 THEN oi.price * 0.25  -- 25% return cost
                ELSE 0 
            END
        )::numeric, 2) AS estimated_return_cost_brl,
        
        -- Customer Satisfaction
        ROUND(AVG(r.review_score)::numeric, 2) AS avg_review_score,
        COUNT(CASE WHEN r.review_score <= 2 THEN 1 END) AS poor_reviews_count
        
    FROM olist_sellers_dataset s
    JOIN olist_order_items_dataset oi ON s.seller_id = oi.seller_id
    JOIN olist_orders_dataset o ON oi.order_id = o.order_id
    LEFT JOIN olist_order_reviews_dataset r ON o.order_id = r.order_id
    
    WHERE o.order_status = 'delivered'
    
    GROUP BY s.seller_id, s.seller_city, s.seller_state
)

SELECT 
    seller_id,
    seller_city,
    seller_state,
    total_orders,
    total_items_sold,
    total_gmv_brl,
    avg_item_price_brl,
    
    -- Total Costs
    total_shipping_cost_brl,
    total_commission_brl,
    estimated_return_cost_brl,
    (total_shipping_cost_brl + total_commission_brl + estimated_return_cost_brl) AS total_costs_brl,
    
    -- Profitability Metrics
    ROUND(
        (total_gmv_brl - total_shipping_cost_brl - total_commission_brl - estimated_return_cost_brl)::numeric, 
        2
    ) AS net_profit_brl,
    
    ROUND(
        ((total_gmv_brl - total_shipping_cost_brl - total_commission_brl - estimated_return_cost_brl) / 
         NULLIF(total_gmv_brl, 0) * 100)::numeric, 
        1
    ) AS profit_margin_pct,
    
    -- Performance Indicators
    avg_review_score,
    poor_reviews_count,
    
    -- Seller Classification
    CASE 
        WHEN total_gmv_brl - total_shipping_cost_brl - total_commission_brl - estimated_return_cost_brl < 0 
        THEN 'LOSS_MAKING'
        WHEN total_orders >= 50 AND avg_review_score >= 4.0 
        THEN 'TOP_PERFORMER'
        WHEN total_orders >= 20 AND avg_review_score >= 3.5 
        THEN 'GOOD_PERFORMER'
        ELSE 'AVERAGE_PERFORMER'
    END AS seller_classification

FROM seller_metrics
WHERE total_orders >= 5  -- Only sellers with at least 5 orders
ORDER BY net_profit_brl DESC;


-- =====================================================
-- QUERY 2: REGION-LEVEL PROFITABILITY
-- =====================================================
-- Analyze profitability by Brazilian states/regions

SELECT 
    s.seller_state,
    COUNT(DISTINCT s.seller_id) AS total_sellers,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    
    -- Revenue Metrics
    ROUND(SUM(oi.price)::numeric, 2) AS total_gmv_brl,
    ROUND(AVG(oi.price)::numeric, 2) AS avg_order_value_brl,
    
    -- Cost Metrics
    ROUND(SUM(oi.freight_value)::numeric, 2) AS total_shipping_cost_brl,
    ROUND(SUM(oi.price * 0.05)::numeric, 2) AS total_commission_brl,
    
    -- Profitability
    ROUND(
        (SUM(oi.price) - SUM(oi.freight_value) - SUM(oi.price * 0.05))::numeric, 
        2
    ) AS region_net_profit_brl,
    
    ROUND(
        ((SUM(oi.price) - SUM(oi.freight_value) - SUM(oi.price * 0.05)) / 
         NULLIF(SUM(oi.price), 0) * 100)::numeric, 
        1
    ) AS region_profit_margin_pct,
    
    -- Performance Metrics
    ROUND(AVG(r.review_score)::numeric, 2) AS avg_regional_satisfaction

FROM olist_sellers_dataset s
JOIN olist_order_items_dataset oi ON s.seller_id = oi.seller_id
JOIN olist_orders_dataset o ON oi.order_id = o.order_id
LEFT JOIN olist_order_reviews_dataset r ON o.order_id = r.order_id

WHERE o.order_status = 'delivered'

GROUP BY s.seller_state
ORDER BY region_net_profit_brl DESC;


-- =====================================================
-- QUERY 3: LOGISTICS COST PER ORDER AND PER SELLER
-- =====================================================
-- Deep dive into shipping/logistics costs

WITH logistics_analysis AS (
    SELECT 
        oi.seller_id,
        oi.order_id,
        s.seller_state,
        c.customer_state,
        
        oi.freight_value AS shipping_cost_brl,
        oi.price AS item_value_brl,
        
        -- Calculate if shipping is interstate (higher cost)
        CASE 
            WHEN s.seller_state = c.customer_state THEN 'INTRASTATE'
            ELSE 'INTERSTATE'
        END AS shipping_type,
        
        -- Days between order and shipping
        EXTRACT(DAY FROM (oi.shipping_limit_date - o.order_purchase_timestamp)) AS shipping_days
        
    FROM olist_order_items_dataset oi
    JOIN olist_sellers_dataset s ON oi.seller_id = s.seller_id
    JOIN olist_orders_dataset o ON oi.order_id = o.order_id
    JOIN olist_customers_dataset c ON o.customer_id = c.customer_id
    
    WHERE o.order_status = 'delivered'
        AND oi.freight_value > 0
)

-- Per Order Analysis
SELECT 
    'ORDER_LEVEL' AS analysis_type,
    shipping_type,
    COUNT(*) AS total_orders,
    
    -- Shipping Cost Analysis
    ROUND(AVG(shipping_cost_brl)::numeric, 2) AS avg_shipping_cost_brl,
    ROUND(MIN(shipping_cost_brl)::numeric, 2) AS min_shipping_cost_brl,
    ROUND(MAX(shipping_cost_brl)::numeric, 2) AS max_shipping_cost_brl,
    
    -- Shipping as % of item value
    ROUND(AVG(shipping_cost_brl / NULLIF(item_value_brl, 0) * 100)::numeric, 1) AS avg_shipping_pct_of_value,
    
    -- Delivery time impact
    ROUND(AVG(shipping_days)::numeric, 1) AS avg_shipping_days

FROM logistics_analysis
GROUP BY shipping_type

UNION ALL

-- Per Seller Analysis
SELECT 
    'SELLER_LEVEL' AS analysis_type,
    'ALL' AS shipping_type,
    COUNT(DISTINCT seller_id) AS total_sellers,
    
    ROUND(AVG(avg_seller_shipping)::numeric, 2) AS avg_shipping_cost_brl,
    ROUND(MIN(avg_seller_shipping)::numeric, 2) AS min_shipping_cost_brl,
    ROUND(MAX(avg_seller_shipping)::numeric, 2) AS max_shipping_cost_brl,
    ROUND(AVG(shipping_pct)::numeric, 1) AS avg_shipping_pct_of_value,
    ROUND(AVG(avg_days)::numeric, 1) AS avg_shipping_days

FROM (
    SELECT 
        seller_id,
        AVG(shipping_cost_brl) AS avg_seller_shipping,
        AVG(shipping_cost_brl / NULLIF(item_value_brl, 0) * 100) AS shipping_pct,
        AVG(shipping_days) AS avg_days
    FROM logistics_analysis
    GROUP BY seller_id
) seller_summary;


-- =====================================================
-- QUERY 4: FLAGGING LOSS-MAKING SELLERS AND CATEGORIES
-- =====================================================
-- Identify problematic sellers and categories for action

-- Loss-Making Sellers
WITH seller_profitability AS (
    SELECT 
        s.seller_id,
        s.seller_state,
        COUNT(DISTINCT oi.order_id) AS total_orders,
        ROUND(SUM(oi.price)::numeric, 2) AS total_revenue_brl,
        ROUND(SUM(oi.freight_value + oi.price * 0.05)::numeric, 2) AS total_costs_brl,
        ROUND(SUM(oi.price - oi.freight_value - oi.price * 0.05)::numeric, 2) AS net_profit_brl,
        ROUND(AVG(r.review_score)::numeric, 2) AS avg_review_score
        
    FROM olist_sellers_dataset s
    JOIN olist_order_items_dataset oi ON s.seller_id = oi.seller_id
    JOIN olist_orders_dataset o ON oi.order_id = o.order_id
    LEFT JOIN olist_order_reviews_dataset r ON o.order_id = r.order_id
    
    WHERE o.order_status = 'delivered'
    
    GROUP BY s.seller_id, s.seller_state
)

SELECT 
    'LOSS_MAKING_SELLERS' AS alert_type,
    seller_id,
    seller_state,
    total_orders,
    total_revenue_brl,
    total_costs_brl,
    net_profit_brl,
    avg_review_score,
    
    -- Risk Level
    CASE 
        WHEN net_profit_brl < -1000 AND avg_review_score < 3.0 THEN 'HIGH_RISK'
        WHEN net_profit_brl < -500 THEN 'MEDIUM_RISK'
        ELSE 'LOW_RISK'
    END AS risk_level,
    
    'Consider seller coaching or fee adjustment' AS recommended_action

FROM seller_profitability
WHERE net_profit_brl < 0 AND total_orders >= 10
ORDER BY net_profit_brl ASC;

-- Loss-Making Categories
WITH category_profitability AS (
    SELECT 
        COALESCE(t.product_category_name_english, p.product_category_name, 'Unknown') AS category,
        COUNT(DISTINCT oi.order_id) AS total_orders,
        ROUND(SUM(oi.price)::numeric, 2) AS total_revenue_brl,
        ROUND(SUM(oi.freight_value + oi.price * 0.05)::numeric, 2) AS total_costs_brl,
        ROUND(SUM(oi.price - oi.freight_value - oi.price * 0.05)::numeric, 2) AS net_profit_brl,
        ROUND(AVG(r.review_score)::numeric, 2) AS avg_review_score
        
    FROM olist_order_items_dataset oi
    JOIN olist_products_dataset p ON oi.product_id = p.product_id
    LEFT JOIN product_category_name_translation t ON p.product_category_name = t.product_category_name
    JOIN olist_orders_dataset o ON oi.order_id = o.order_id
    LEFT JOIN olist_order_reviews_dataset r ON o.order_id = r.order_id
    
    WHERE o.order_status = 'delivered'
    
    GROUP BY COALESCE(t.product_category_name_english, p.product_category_name, 'Unknown')
)

SELECT 
    'LOSS_MAKING_CATEGORIES' AS alert_type,
    category,
    total_orders,
    total_revenue_brl,
    total_costs_brl,
    net_profit_brl,
    ROUND((net_profit_brl / NULLIF(total_revenue_brl, 0) * 100)::numeric, 1) AS profit_margin_pct,
    avg_review_score

FROM category_profitability
WHERE net_profit_brl < 0 AND total_orders >= 50
ORDER BY net_profit_brl ASC;


-- =====================================================
-- PART 2: CUSTOMER RFM SEGMENTATION & LTV MODELING
-- =====================================================

-- =====================================================
-- QUERY 5: RFM SEGMENTATION (RECENCY, FREQUENCY, MONETARY)
-- =====================================================
-- RFM helps segment customers based on purchase behavior

WITH customer_rfm_base AS (
    SELECT 
        c.customer_id,
        c.customer_state,
        
        -- Recency: Days since last purchase (lower = better)
        EXTRACT(DAY FROM ('2018-12-31'::date - MAX(o.order_purchase_timestamp::date))) AS recency_days,
        
        -- Frequency: Number of orders (higher = better)
        COUNT(DISTINCT o.order_id) AS frequency_orders,
        
        -- Monetary: Total amount spent (higher = better)
        ROUND(SUM(oi.price)::numeric, 2) AS monetary_value_brl,
        
        -- Additional metrics
        ROUND(AVG(oi.price)::numeric, 2) AS avg_order_value_brl,
        ROUND(AVG(r.review_score)::numeric, 2) AS avg_satisfaction
        
    FROM olist_customers_dataset c
    JOIN olist_orders_dataset o ON c.customer_id = o.customer_id
    JOIN olist_order_items_dataset oi ON o.order_id = oi.order_id
    LEFT JOIN olist_order_reviews_dataset r ON o.order_id = r.order_id
    
    WHERE o.order_status = 'delivered'
        AND o.order_purchase_timestamp >= '2017-01-01'
        AND o.order_purchase_timestamp <= '2018-12-31'
    
    GROUP BY c.customer_id, c.customer_state
),

customer_rfm_scored AS (
    SELECT 
        customer_id,
        customer_state,
        recency_days,
        frequency_orders,
        monetary_value_brl,
        avg_order_value_brl,
        avg_satisfaction,
        
        -- RFM Scores (1-5, where 5 is best)
        -- Recency: Lower days = higher score
        CASE 
            WHEN recency_days <= 30 THEN 5
            WHEN recency_days <= 90 THEN 4
            WHEN recency_days <= 180 THEN 3
            WHEN recency_days <= 365 THEN 2
            ELSE 1
        END AS recency_score,
        
        -- Frequency: More orders = higher score
        CASE 
            WHEN frequency_orders >= 5 THEN 5
            WHEN frequency_orders >= 3 THEN 4
            WHEN frequency_orders >= 2 THEN 3
            WHEN frequency_orders >= 1 THEN 2
            ELSE 1
        END AS frequency_score,
        
        -- Monetary: Higher value = higher score
        CASE 
            WHEN monetary_value_brl >= 1000 THEN 5
            WHEN monetary_value_brl >= 500 THEN 4
            WHEN monetary_value_brl >= 200 THEN 3
            WHEN monetary_value_brl >= 100 THEN 2
            ELSE 1
        END AS monetary_score
        
    FROM customer_rfm_base
)

SELECT 
    customer_id,
    customer_state,
    recency_days,
    frequency_orders,
    monetary_value_brl,
    avg_order_value_brl,
    recency_score,
    frequency_score,
    monetary_score,
    
    -- Combined RFM Score
    (recency_score + frequency_score + monetary_score) AS total_rfm_score,
    
    -- Customer Segments
    CASE 
        WHEN recency_score >= 4 AND frequency_score >= 4 AND monetary_score >= 4 THEN 'CHAMPIONS'
        WHEN recency_score >= 3 AND frequency_score >= 3 AND monetary_score >= 4 THEN 'LOYAL_CUSTOMERS'
        WHEN recency_score >= 4 AND frequency_score <= 2 AND monetary_score >= 3 THEN 'POTENTIAL_LOYALISTS'
        WHEN recency_score >= 4 AND frequency_score <= 2 AND monetary_score <= 2 THEN 'NEW_CUSTOMERS'
        WHEN recency_score >= 3 AND frequency_score >= 2 AND monetary_score <= 3 THEN 'PROMISING'
        WHEN recency_score <= 2 AND frequency_score >= 3 AND monetary_score >= 3 THEN 'NEED_ATTENTION'
        WHEN recency_score <= 2 AND frequency_score >= 2 AND monetary_score <= 2 THEN 'ABOUT_TO_SLEEP'
        WHEN recency_score >= 3 AND frequency_score <= 2 AND monetary_score <= 2 THEN 'AT_RISK'
        WHEN recency_score <= 2 AND frequency_score <= 2 AND monetary_score >= 3 THEN 'CANNOT_LOSE_THEM'
        ELSE 'LOST'
    END AS customer_segment,
    
    avg_satisfaction

FROM customer_rfm_scored
ORDER BY total_rfm_score DESC, monetary_value_brl DESC;


-- =====================================================
-- QUERY 6: COHORT-BASED LTV MODELING
-- =====================================================
-- Track customer value over time by cohort (month they first purchased)

WITH customer_cohorts AS (
    -- Identify each customer's first purchase month (their cohort)
    SELECT 
        customer_id,
        DATE_TRUNC('month', MIN(order_purchase_timestamp)) AS cohort_month,
        MIN(order_purchase_timestamp) AS first_purchase_date
    FROM olist_orders_dataset
    WHERE order_status = 'delivered'
    GROUP BY customer_id
),

customer_orders AS (
    -- Get all orders with cohort information
    SELECT 
        co.customer_id,
        co.cohort_month,
        o.order_purchase_timestamp,
        DATE_TRUNC('month', o.order_purchase_timestamp) AS order_month,
        
        -- Calculate months since first purchase
        EXTRACT(EPOCH FROM (o.order_purchase_timestamp - co.first_purchase_date)) / (30.44 * 24 * 3600) AS months_since_first_purchase,
        
        SUM(oi.price) AS order_value_brl
        
    FROM customer_cohorts co
    JOIN olist_orders_dataset o ON co.customer_id = o.customer_id
    JOIN olist_order_items_dataset oi ON o.order_id = oi.order_id
    
    WHERE o.order_status = 'delivered'
    
    GROUP BY co.customer_id, co.cohort_month, o.order_purchase_timestamp, co.first_purchase_date
),

cohort_ltv AS (
    SELECT 
        cohort_month,
        FLOOR(months_since_first_purchase) AS month_number,
        COUNT(DISTINCT customer_id) AS active_customers,
        ROUND(SUM(order_value_brl)::numeric, 2) AS cohort_revenue_brl,
        ROUND(AVG(order_value_brl)::numeric, 2) AS avg_order_value_brl
        
    FROM customer_orders
    WHERE months_since_first_purchase >= 0 AND months_since_first_purchase <= 12
    
    GROUP BY cohort_month, FLOOR(months_since_first_purchase)
),

cohort_sizes AS (
    -- Get initial cohort sizes
    SELECT 
        cohort_month,
        COUNT(DISTINCT customer_id) AS initial_customers
    FROM customer_cohorts
    GROUP BY cohort_month
)

SELECT 
    cl.cohort_month,
    cl.month_number,
    cs.initial_customers,
    cl.active_customers,
    
    -- Retention Rate
    ROUND((cl.active_customers::float / cs.initial_customers * 100)::numeric, 1) AS retention_rate_pct,
    
    -- Revenue Metrics
    cl.cohort_revenue_brl,
    cl.avg_order_value_brl,
    
    -- Cumulative LTV calculation
    ROUND(
        SUM(cl.cohort_revenue_brl) OVER (
            PARTITION BY cl.cohort_month 
            ORDER BY cl.month_number 
            ROWS UNBOUNDED PRECEDING
        ) / cs.initial_customers::numeric, 
        2
    ) AS cumulative_ltv_per_customer_brl

FROM cohort_ltv cl
JOIN cohort_sizes cs ON cl.cohort_month = cs.cohort_month

ORDER BY cl.cohort_month, cl.month_number;


-- =====================================================
-- QUERY 7: SIMULATED CAC AND CAC:LTV RATIO
-- =====================================================
-- Customer Acquisition Cost simulation and comparison to LTV

WITH ltv_summary AS (
    -- Calculate average LTV per customer (simplified)
    SELECT 
        AVG(customer_ltv) AS avg_ltv_brl
    FROM (
        SELECT 
            c.customer_id,
            SUM(oi.price) AS customer_ltv
        FROM olist_customers_dataset c
        JOIN olist_orders_dataset o ON c.customer_id = o.customer_id
        JOIN olist_order_items_dataset oi ON o.order_id = oi.order_id
        WHERE o.order_status = 'delivered'
        GROUP BY c.customer_id
    ) customer_values
),

acquisition_simulation AS (
    -- Simulate different CAC scenarios
    SELECT 
        scenario,
        simulated_cac_brl,
        (SELECT avg_ltv_brl FROM ltv_summary) AS avg_ltv_brl
    FROM (
        VALUES 
            ('Conservative Marketing', 25.00),
            ('Moderate Marketing', 50.00),
            ('Aggressive Marketing', 100.00),
            ('Premium Marketing', 150.00)
    ) AS scenarios(scenario, simulated_cac_brl)
)

SELECT 
    scenario,
    ROUND(simulated_cac_brl::numeric, 2) AS cac_brl,
    ROUND(avg_ltv_brl::numeric, 2) AS avg_ltv_brl,
    
    -- CAC:LTV Ratio (should be < 0.33 for healthy business)
    ROUND((simulated_cac_brl / avg_ltv_brl)::numeric, 3) AS cac_ltv_ratio,
    
    -- LTV:CAC Multiple (should be > 3x for healthy business)
    ROUND((avg_ltv_brl / simulated_cac_brl)::numeric, 1) AS ltv_cac_multiple,
    
    -- Business Health Assessment
    CASE 
        WHEN simulated_cac_brl / avg_ltv_brl <= 0.25 THEN 'EXCELLENT'
        WHEN simulated_cac_brl / avg_ltv_brl <= 0.33 THEN 'GOOD'
        WHEN simulated_cac_brl / avg_ltv_brl <= 0.50 THEN 'ACCEPTABLE'
        ELSE 'CONCERNING'
    END AS business_health,
    
    ROUND((avg_ltv_brl - simulated_cac_brl)::numeric, 2) AS net_customer_value_brl

FROM acquisition_simulation
ORDER BY cac_ltv_ratio;


-- =====================================================
-- QUERY 8: SAMPLE COHORT ANALYSIS WITH EXPLANATIONS
-- =====================================================
-- Detailed cohort example for understanding

WITH sample_cohort AS (
    -- Focus on customers who first bought in Jan 2018
    SELECT 
        'January 2018 Cohort Example' AS explanation,
        c.customer_id,
        DATE_TRUNC('month', MIN(o.order_purchase_timestamp)) AS cohort_month,
        COUNT(DISTINCT o.order_id) AS total_orders,
        ROUND(SUM(oi.price)::numeric, 2) AS total_spent_brl,
        MAX(o.order_purchase_timestamp) AS last_purchase_date,
        EXTRACT(DAY FROM ('2018-12-31'::date - MAX(o.order_purchase_timestamp::date))) AS days_since_last_purchase
        
    FROM olist_customers_dataset c
    JOIN olist_orders_dataset o ON c.customer_id = o.customer_id
    JOIN olist_order_items_dataset oi ON o.order_id = oi.order_id
    
    WHERE o.order_status = 'delivered'
        AND DATE_TRUNC('month', o.order_purchase_timestamp) >= '2018-01-01'
        AND DATE_TRUNC('month', o.order_purchase_timestamp) <= '2018-01-31'
    
    GROUP BY c.customer_id
    HAVING DATE_TRUNC('month', MIN(o.order_purchase_timestamp)) = '2018-01-01'
)

SELECT 
    explanation,
    COUNT(*) AS cohort_size,
    ROUND(AVG(total_orders)::numeric, 1) AS avg_orders_per_customer,
    ROUND(AVG(total_spent_brl)::numeric, 2) AS avg_ltv_brl,
    ROUND(AVG(days_since_last_purchase)::numeric, 0) AS avg_days_since_last_purchase,
    
    -- Behavioral Segments within Cohort
    COUNT(CASE WHEN total_orders = 1 THEN 1 END) AS one_time_buyers,
    COUNT(CASE WHEN total_orders >= 2 THEN 1 END) AS repeat_buyers,
    COUNT(CASE WHEN total_spent_brl >= 200 THEN 1 END) AS high_value_customers,
    
    -- Retention Proxy
    COUNT(CASE WHEN days_since_last_purchase <= 90 THEN 1 END) AS likely_active_customers

FROM sample_cohort
GROUP BY explanation;