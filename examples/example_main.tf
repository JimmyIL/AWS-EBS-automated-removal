#This is the reference to the module you would use in your root terraform main.tf

#add this if being deployed in current region. otherwise add the region you want it deployed in using the variable for 'main_region'.
data "aws_region" "current" {}


module "ebs-auto-clean" {

  #this source is assuming the terraform files are located in root dir->modules->ebs_volume_auto_cleanup
  source = "../modules/ebs_volume_auto_cleanup"
  days   = var.days

  days_until_removed = var.days_until_removed

  exemption_tag_value = var.exemption_tag_value

  ebs_sns_name = var.ebs_sns_name

  #if the sns topic is in a seperate region than the terraform execution region. Its like this to open to multi-region in future version
  main_region = data.aws_region.current.name

  #subscriptions are created here and these emails will get the volume tagging and deleting notifications
  ebs_cleanup_email = ["someemail1@example.com", "someemail2@example.com"]

  #filename of the .net lambda function .zip file I would just leave this alone maybe.  make sure this file is in the proper location. #main.tf:line:30
  lambda_zip_name = "ebs_volume_cleanup-20f9d10a-985c-4bbc-8bf8-b0eeaede7308.zip"

}
