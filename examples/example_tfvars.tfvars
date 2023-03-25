#EBS lambda auto-removal variables 
#add these to your root terraform tfvars file your using.

#how many days ago the ebs volume was created, if this many days ago and 'available' function tags for deletion, and sends email with info.  the tagged date for removal = days_until_removed
days = 25

#these are the days the ebs volumes are tagged for in the future for removal
days_until_removed = 5

#name of the sns topic that you would like..
ebs_sns_name = "ebs-auto-removal"

#TODO add multi region. currently only excepts a single region
ebs_regions = ["us-east-1"]

#this is the exemption tag VALUE.  if this value is on the ebs volume tags it is not removed or tagged for removal in the future
exemption_tag_value = "no-auto-removal"

#list of emails to receive sns subscriptions, (check after deploying that you have confirmed the subscription request via email).  
ebs_cleanup_email = ["someemail1@example.com", "someemail2@example.com"]
