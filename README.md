# AWS-EBS-volume-automation
Cost optimization 🚀 with auto tagging, maintaining, and removing unused volumes in AWS with Terraform

## This works great, but some Optimizations are in progress:
- add switch defining all regions per account OR user defined region list this deploys to.
- check for snapshots before deletion, if no snapshot create a snapshot and update EBS volume scheduled deletion for next day. 


The EBS-volume-cleanup Lambda function automates the removal of unused AWS EBS volumes within a specified region using user defined variables on launch. 

Here are some important things to note:

- The Lambda function sends an email notification via SNS on day [25] from the EBS volume(s) "creation_date" if its status is "available" (unused).

- [5] days after the notification, the Lambda function removes the EBS volumes if they are still unused ("available") and were tagged specifying today's date. (more on tagging below)

- If any modifications, queuing for deletion, or deletions happen, an email will be sent with volumes involved and their information.

## Prerequisites  [all included in code but some things to mention for proper operations]

In order for the Lambda function to be able to remove an EBS volume, the following must be met:

- The Lambda function is run EVERY DAY by an EventBridge event. (You can change it to run more times a day, but don't have it trigger longer than 1 day i.e.(every other day) )

- EBS volumes must have been auto tagged with the current date and must not be in use. For example, a tag value for a volume getting deleted today would be: 

  key = "auto-remove-policy" ;  value = "scheduled_removal_03-15-2023"  

- EBS volumes must not have an exemption tag value tagged to it. 

- To exempt the EBS volume from any deletion, simply remove the tag starting with "scheduled_removal_<removal date>" AND add "no-auto-removal" instead. The tag should look like this: 
key = "auto-remove-policy" ;  value = "no-auto-removal"

- If an EBS volume gets re-attached to an instance and is in use when the lambda function runs, it will not be deleted/removed. In this case you must manually remove the 'auto-remove-policy' tag for it to be considered for removal ever again.  


example unintended scenario:

You look and see an ebs volume that is 'available' (unused) with a tag like this: 
"auto-remove-policy" = "scheduled_removal_<2 days ago>"
What happened: if the volume was tagged for removal 2 days ago that means it also has the exception tag added OR it was in use at the time the lambda checked for available volumes.
Solution: remove the 'scheduled_removal' tag so it can be considered in next cycle.  IF there is an exception tag there, someone had to have added it and check with the team. NO exemption tag OR already expired scheduled_removal tag should be attached to the EBS volume if you want it to be removed.


-Check the example/.tfvars file for the environment variables you can change to match the time you want to be notified, removal date tagging, and actual removal time.
