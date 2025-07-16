# E-Commerce Profitability & Category Growth Strategy

This end-to-end analytics project analyzes Brazilian e-commerce data to identify profitability opportunities and category growth strategies. Using the Olist dataset, we built comprehensive SQL data models, Excel-based financial analysis, and interactive Power BI dashboards to drive strategic business decisions.

-----

## Table of Contents

  - [Project Overview](https://www.google.com/search?q=%23project-overview)
  - [Objectives](https://www.google.com/search?q=%23objectives)
  - [Dataset Description](https://www.google.com/search?q=%23dataset-description)
  - [Tools Used](https://www.google.com/search?q=%23tools-used)
  - [Project Structure](https://www.google.com/search?q=%23project-structure)
  - [Key Metrics Defined](https://www.google.com/search?q=%23key-metrics-defined)
  - [How to Run the Project](https://www.google.com/search?q=%23how-to-run-the-project)
  - [Key Insights Summary](https://www.google.com/search?q=%23key-insights-summary)
  - [Strategic Recommendations](https://www.google.com/search?q=%23strategic-recommendations)
  - [Next Steps](https://www.google.com/search?q=%23next-steps)
  - [Contributing](https://www.google.com/search?q=%23contributing)
  - [Contact](https://www.google.com/search?q=%23contact)
  - [License](https://www.google.com/search?q=%23license)
  - [Acknowledgments](https://www.google.com/search?q=%23acknowledgments)

-----

## Project Overview

### Key Focus Areas:

  - Category profitability analysis and margin optimization
  - Return rate impact assessment and leakage quantification
  - Customer lifetime value segmentation for targeted strategies
  - Monthly trend analysis for seasonal planning

## Objectives

### Primary Goals

  - **Profit Optimization**: Identify high-margin categories and optimize underperforming segments.
  - **Return Management**: Quantify the financial impact of returns and develop mitigation strategies.
  - **Customer Segmentation**: Segment customers by LTV to personalize marketing approaches.
  - **Strategic Planning**: Provide actionable insights for category investment decisions.

### Success Metrics

  - Gross Margin % improvement by category
  - Return Rate reduction across product lines
  - Customer LTV segmentation accuracy
  - Monthly GMV trend forecasting capability

## Dataset Description

  - **Source**: Olist Brazilian E-Commerce Dataset (Kaggle)
  - **Period**: 2016-2018
  - **Records**: 100k+ orders across 45k+ products
  - **Coverage**: 27 Brazilian states, 3k+ cities

### Key Tables

| Table | Records | Description |
|---|---|---|
| `orders` | 99,441 | Order details and status |
| `order_items` | 112,650 | Product-level order line items |
| `products` | 32,951 | Product catalog with categories |
| `customers` | 99,441 | Customer demographics and location |
| `payments` | 103,886 | Payment methods and values |
| `reviews` | 99,224 | Customer ratings and reviews |
| `sellers` | 3,095 | Seller information and location |

## Tools Used

  - **Data Processing & Analysis**: SQL Server, Microsoft Excel
  - **Data Visualization**: Power BI
  - **Technical Stack**:
      - **Database**: SQL Server 2019+
      - **Visualization**: Power BI Desktop
      - **Analysis**: Excel 365 with Power Query
      - **Version Control**: Git/GitHub

## Key Metrics Defined

### Profitability Metrics

  - **Gross Margin %**: `(Revenue - COGS - Freight) / Revenue * 100`
  - **Net Profit**: `Revenue - COGS - Freight - Returns_Loss`
  - **Category ROI**: `Net_Profit / Total_Investment * 100`

### Customer Metrics

  - **Customer LTV**: `Total_Revenue_Per_Customer / Customer_Lifespan`
  - **Average Order Value**: `Total_Revenue / Number_of_Orders`
  - **Purchase Frequency**: `Number_of_Orders / Number_of_Customers`

### Operational Metrics

  - **Return Rate**: `Returned_Orders / Total_Orders * 100`
  - **Estimated Returns Loss**: `Return_Rate * Average_Order_Value * (1 + Avg_Freight_Rate)`
  - **GMV Growth**: `(Current_Month_GMV - Previous_Month_GMV) / Previous_Month_GMV * 100`

## How to Run the Project

### Prerequisites

  - SQL Server 2019+
  - Microsoft Excel 365 or Excel 2019
  - Power BI Desktop (latest version)
  - Git

### Step 1: Data Setup

1.  Clone the repository:
    ```bash
    git clone https://github.com/yourusername/ecommerce-analytics.git
    cd ecommerce-analytics
    ```
2.  Download the Olist dataset from Kaggle.
3.  Place the CSV files in the `data/raw/` directory.

### Step 2: SQL Analysis

Run the SQL scripts in the specified order.

```bash
# 1. Execute data cleaning
sqlcmd -S your_server -d your_database -i sql/01_data_cleaning.sql

# 2. Calculate key metrics
sqlcmd -S your_server -d your_database -i sql/02_metrics_calculation.sql

# 3. Perform LTV segmentation
sqlcmd -S your_server -d your_database -i sql/03_ltv_segmentation.sql

# 4. Analyze category performance
sqlcmd -S your_server -d your_database -i sql/04_category_analysis.sql
```

### Step 3: Excel Analysis

1.  Open `excel/financial_model.xlsx`.
2.  Go to `Data` → `Get Data` → `From Database` → `From SQL Server`.
3.  Connect to your SQL Server instance and import the processed tables created in Step 2.
4.  Refresh all pivot tables and charts.

### Step 4: Power BI Dashboard

1.  Open `powerbi/ecommerce_dashboard.pbix`.
2.  Go to `Home` → `Transform Data` → `Data Source Settings`.
3.  Update the connection to point to your SQL Server.
4.  Click `Close & Apply` to refresh all visuals.
5.  (Optional) Publish the report to the Power BI Service.

## Key Insights Summary

  - **Profitability Findings**:

      - **Top Performing**: Health & Beauty (18% margin), Sports & Leisure (15% margin).
      - **Underperforming**: Electronics (-2% margin), Furniture (-1% margin).
      - **Opportunity**: 12% potential margin uplift through category optimization.

  - **Returns Analysis**:

      - **Average Rate**: 8.5% across all categories.
      - **Highest Return**: Fashion (15%), Electronics (12%).
      - **Estimated Annual Loss**: $2.3M from returns.

  - **Customer Segmentation**:

      - **Premium LTV (Top 25%)**: $485 avg. LTV, 3.2x higher AOV.
      - **Low LTV (Bottom 25%)**: $65 avg. LTV, mostly single-purchase customers.

  - **Growth Opportunities**:

      - **Seasonality**: 35% GMV increase during the Q4 holiday season.
      - **Geographic Focus**: São Paulo and Rio represent 45% of total GMV.
      - **Category Growth**: Health & Beauty shows 25% month-over-month growth.

## Strategic Recommendations

### Immediate Actions (0-3 months)

  - **Reduce Electronics Returns**: Implement enhanced product descriptions and customer reviews.
  - **Optimize Freight Costs**: Negotiate better rates for high-volume, low-margin categories.
  - **Target Premium LTV Customers**: Launch a loyalty program for the top 25% of customers.

### Medium-term Strategy (3-12 months)

  - **Category Portfolio Rebalancing**: Increase investment in Health & Beauty, reduce Electronics exposure.
  - **Seller Performance Management**: Implement seller scorecards focusing on return rates.
  - **Seasonal Inventory Planning**: Optimize stock levels based on historical trend analysis.

### Long-term Vision (12+ months)

  - **Market Expansion**: Enter new geographic markets based on customer density analysis.
  - **Category Diversification**: Explore adjacency opportunities in high-margin segments.
  - **Technology Investment**: Implement predictive analytics for demand forecasting.

## Next Steps

  - [ ] Implement A/B testing framework for category optimization.
  - [ ] Develop automated anomaly detection for return rate monitoring.
  - [ ] Create predictive models for customer LTV forecasting.
  - [ ] Establish a monthly business review process using dashboard insights.
  - [ ] Expand analysis to include supplier performance metrics.

## Contributing

We welcome contributions to improve this analysis\! Please follow these steps:

1.  Fork the repository.
2.  Create a feature branch (`git checkout -b feature/AmazingInsight`).
3.  Commit your changes (`git commit -m 'Add some AmazingInsight'`).
4.  Push to the branch (`git push origin feature/AmazingInsight`).
5.  Open a Pull Request.

## Contact

  - **Project Lead**: [Your Name]
  - **Email**: `your.email@company.com`
  - **LinkedIn**: `[Your LinkedIn Profile]`
  - **GitHub**: `@yourusername`

## License

This project is licensed under the MIT License - see the `LICENSE` file for details.

## Acknowledgments

  - **Olist**: For providing the comprehensive e-commerce dataset.
  - **Kaggle Community**: For dataset curation and documentation.
  - **Microsoft**: For Power BI and Excel tools that enabled this analysis.
  - **SQL Community**: For query optimization techniques and best practices.