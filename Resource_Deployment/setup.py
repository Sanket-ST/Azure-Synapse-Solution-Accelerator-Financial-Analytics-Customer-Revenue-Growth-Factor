#!/usr/bin/env python
# coding: utf-8

# ## Notebook 2
# 
# 
# 

# In[ ]:


import numpy as np

import pandas as pd

from pyspark.sql.types import *
data_lake_account_name = 'adlsi4ryf7fd3u5u6'
file_system_name = 'source'
subscription_id = 'fa54ed0f-1041-42a5-b8a3-1cea77b9569d'
resource_group = 'ManyModels-680823'
workspace_name = 'ml-680823'
workspace_region = 'eastus'


# In[ ]:


import azureml.core
from azureml.core import Dataset, Workspace, Experiment
from azureml.core.compute import ComputeTarget, AmlCompute
from azureml.train.automl import AutoMLConfig
from azureml.train.automl.run import AutoMLRun
from azureml.widgets import RunDetails
from azureml.automl.core.featurization.featurizationconfig import FeaturizationConfig

from azureml.core.authentication import ServicePrincipalAuthentication

#sub_tenant_id = "cefcb8e7-ee30-49b8-b190-133f1daafd85" 
#svc_pr_id = "c21d62cc-31b1-432a-8a81-c4873a0471e0"
#svc_pr_password="KAG2M_sZ8Er_0.8HJtN1U66N4R.C~ajS~U"

sub_tenant_id = "cefcb8e7-ee30-49b8-b190-133f1daafd85" 
svc_pr_id = "9d5f7a67-e694-4816-a2f4-cadcc5e8b3d8"
svc_pr_password="sfj8Q~pr9kkSAlng.v_Y.Rbf.vWgOhwLPxwZtb.e"


svc_pr = ServicePrincipalAuthentication(
    tenant_id=sub_tenant_id,
    service_principal_id=svc_pr_id,
    service_principal_password=svc_pr_password)

subscription_id = 'fa54ed0f-1041-42a5-b8a3-1cea77b9569d'
resource_group = 'ManyModels-680823'
workspace_name = 'ml-680823'
ws = Workspace.get(name = workspace_name, subscription_id = subscription_id, resource_group = resource_group, auth = svc_pr)


# In[ ]:


compute_name = 'manymodel-compute'
# The minimum and maximum number of nodes of the compute instance
compute_min_nodes = 1
# Setting the number of maximum nodes to a higher value will allow Automated ML to run more experiments in parallel, but will also inccrease your costs
compute_max_nodes = 1

vm_size = 'STANDARD_DS3_V2'

# Check existing compute targets in the workspace for a compute with this name
if compute_name in ws.compute_targets:
    compute_target = ws.compute_targets[compute_name]
    if compute_target and type(compute_target) is AmlCompute:
        print(f'Found existing compute target: {compute_name}')    
else:
    print(f'A new compute target is needed: {compute_name}')
    provisioning_config = AmlCompute.provisioning_configuration(vm_size = vm_size,
                                                                min_nodes = compute_min_nodes, 
                                                                max_nodes = compute_max_nodes)

# Create the cluster
    compute_target = ComputeTarget.create(ws, compute_name, provisioning_config)
    
# Wait for provisioning to complete
    compute_target.wait_for_completion(show_output=True, min_node_count=None, timeout_in_minutes=20)


# In[ ]:


train_data = Dataset.get_by_name(ws, 'mldataset')
train_data


# In[ ]:


featurization_config = FeaturizationConfig()
featurization_config.drop_columns = ['user_id', 'year', 'month']


# In[ ]:


# Configura Automated ML
automl_config = AutoMLConfig(task = "classification",
    # Use weighted area under curve metric to evaluate the models
    primary_metric='AUC_weighted',
                             
    # Use all columns except the ones we decided to ignore
    training_data = train_data,
                             
    # The values we're trying to predict are in the `cluster` column
    label_column_name = 'growth',
                             
    # Evaluate the model with 5-fold cross validation
    n_cross_validations=5,
                             
    # The experiment should be stopped after 15 minutes, to minimize cost
    experiment_timeout_hours=.5,
    #blocked_models=['XGBoostClassifier'],
                             
    # Automated ML can try at most 1 models at the same time, this is also limited by the compute instance's maximum number of nodes
    max_concurrent_iterations=3,
                             
    # An iteration should be stopped if it takes more than 5 minutes
    iteration_timeout_minutes=3,
                             
    compute_target=compute_target,
                             
    #The total number of different algorithm and parameter combinations to test during an automated ML experiment. If not specified, the default is 1000 iterations.
    iterations = 10,

    
    #dropping columns
    featurization=featurization_config,
    
)
automl_config


# In[ ]:


exp = Experiment(ws, 'customergrowthfactors')
run = exp.submit(automl_config, show_output=True)
run.wait_for_completion()

