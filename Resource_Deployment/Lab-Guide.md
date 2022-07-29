# Getting Stared with Customer Revenue Growth Factor Soltion Accelerator

This accelerator was built to provide developers with all of the resources needed to build a solution to identify the top factors for revenue growth from an e-commerce platform using Azure Synapse Analytics and Azure Machine Learning.

## Prerequisites

In order to successfully complete your solution, you will need to have access to and or provisioned the following:
1. Access to an Azure subscription
2. A Power BI Pro License (or free trial)

Optional
1. Azure Storage Explorer

## Process Overview  

The architecture diagram below details what you will be building for this Solution Accelerator:

![](../Reference/Architecture/SynapseArchitecture.png)
![](../Reference/Architecture/SynapseAutoMLArchitecture.png)


## Connect Power BI to Azure Machine Learning and Deploy to the Synapse Workspace

1. Launch Synapse workspace and run the following notebooks to export the results of the AutoML model and create the data model for the Power BI report:
    1. `6 - PBI Data Model` 
2. Create a new workspace in [Power BI Service](https://app.powerbi.com/)
3. Enable AI Insights with Power BI:
    - In the new workspace, click on "New > Dataflow" to create a PBI Dataflow
    - Select "Add new entities" and choose Azure Data Lake Gen2 as your data source, then enter your connection URL as `https://[adls_name].dfs.core.windows.net/`
    - Click to Transform Data and filter Folder Path to `https://[adls_name].dfs.core.windows.net/[container_name]/transformed_data/ml_data_parquet/` to connect to the dataset for ML modeling
    - Click "Remove rows" and click "Remove top rows" 
        - enter `1` and select "OK"
    - Click the two arrows next to the "Content" column to expand and combine all parquet files
    - Apply your AutoML model by clicking the "AI Insights" button
    - ![](../Resource_Deployment/imgs/pbi_ai_insights.png)
    - Select your deployed model and map the relevant columns
    - ![](../Resource_Deployment/imgs/pbi_ai_insights_select_model.png)
    - Once applied, you will see a new column with the AutoML score. Save your entity and dataflow
4. Build report visuals in Power BI:
    - In the demo's repository, go to `Analytics_Deployment\synapse-workspace\reports` and open [Customer_Growth_Factors_PBI.pbix](../Analytics_Deployment/synapse-workspace/reports/Customer_Growth_Facters_PBI.pbix) in Power BI Desktop
    - Connect to the Data Lake via "Get Data > Azure > Azure Data Lake Gen2" and filtering to the relevant tables by URL. You will need a new dataset for each folder within `https://[adls_name].dfs.core.windows.net/[container_name]/reporting/`
    - Connect to the Dataflow via "Get Data > PowerBI dataflows" and selecting your dataflow
5. Deploy your report to the Synapse workspace:
    - Launch Synapse workspace and go to "Navigate > Linked services"
        - Click "New" and search for Power BI, then enter your Power BI workspace details
        - Now your workspace is linked within Azure Synapse
    - In Power BI Desktop, click "Publish" to deploy your report, and select the same workspace
6. Now you can view and edit your report from the Synapse workspace
