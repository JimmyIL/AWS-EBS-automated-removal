# PowerShell script file to be executed as a AWS Lambda function. 
# When executing in Lambda the following variables will be predefined.
# $LambdaInput - A PSObject that contains the Lambda function input data.
# $LambdaContext - An Amazon.Lambda.Core.ILambdaContext object that contains information about the currently running Lambda environment.
# The last item in the PowerShell pipeline will be returned as the result of the Lambda function.
# To include PowerShell modules with your Lambda function, like the AWS.Tools.S3 module, add a "#Requires" statement
# indicating the module and version. If using an AWS.Tools.* module the AWS.Tools.Common module is also required.

#Requires -Modules @{ModuleName='AWS.Tools.Common';ModuleVersion='4.1.263'}
#Requires -Modules @{ModuleName='AWS.Tools.EC2';ModuleVersion='4.1.286.0'}
#Requires -Modules @{ModuleName='AWS.Tools.EBS';ModuleVersion='4.1.286.0'}
#Requires -Modules @{ModuleName='AWS.Tools.SimpleNotificationService';ModuleVersion='4.1.286.0'}
#Requires -Modules @{ModuleName='AWS.Tools.CloudWatchLogs';ModuleVersion='4.1.286.0'}
#Requires -Modules @{ModuleName='AWS.Tools.CloudWatch';ModuleVersion='4.1.286.0'}
#Requires -Modules @{ModuleName='AWS.Tools.Lambda'; ModuleVersion='4.1.286.0'}

# Uncomment to send the input event to CloudWatch Logs
Write-Host `## Environment variables
Write-Host AWS_LAMBDA_LOG_GROUP_NAME=$Env:AWS_LAMBDA_LOG_GROUP_NAME
Write-Host AWS_LAMBDA_LOG_STREAM_NAME=$Env:AWS_LAMBDA_LOG_STREAM_NAME
Write-Host AWS_LAMBDA_FUNCTION_NAME=$Env:AWS_LAMBDA_FUNCTION_NAME
Write-Host (ConvertTo-Json -InputObject $LambdaInput -Compress -Depth 5)
Write-Host (ConvertTo-Json -InputObject $LambdaContext -Compress -Depth 5)

#function to check ebs volumes that are tagged for deletion today and delete them"
function remove_expired_volumes { 
    param(
        $main_region = $ENV:main_region,
        $regions = $ENV:regions,
        $exemption_tag_value = $ENV:exemption_tag_value
    )

    $erroractionpreference = "Stop"
    $regions = $regions -split ","
    Write-Host "iterating through regions most used.  Regions are--  $regions"  #TODO currently not optimized for all regions, just 1
    
    # to add ALL regions, a replica lambda function code would need to be create in each region WITHOUT the region iteration (otherwise it will just loop)
    # Loop through each region and remove the EBS volumes
 
    foreach ($region in $regions) {
        Write-Host "working with region $region"
        try {
            Write-Host "Processing EBS volume removal lookup in region $region"
            Set-DefaultAWSRegion -Region $region
            $todays_date_formatted = Get-Date -Format 'MM-dd-yyyy'
            $todays_date = "scheduled_removal_$todays_date_formatted"
            Write-Host "todays date is $todays_date"
            $ebs_volumes = ((Get-EC2Volume -Region $region) | where { ($_.State -eq "available") -and (($_.Tags.Value | Out-String) -Match $todays_date) -and (($_.Tags.Value | Out-String) -NotMatch $exemption_tag_value) })
           
            #write-host go to cw logs (in lambda metrics by name)
            Write-Host "******There are currently $($ebs_volumes.count) EBS volumes are being DELETED currently, these volumes have been queued for deletion matching the tag value of $todays_date AND are show status of AVAILABLE"
            
            $ebsvolumes_globally = @()
           
            if ($ebs_volumes.count -gt 0) {       
                
                foreach ($object in $ebs_volumes) {
                    $ebs_tag_value = $object.Tags.Value | Out-String
                    #do a second wave of tag checking CYA.
                    if (($ebs_tag_value -NotMatch $exemption_tag_value) -and ($ebs_tag_value -Match $todays_date)) {
                        #form a table of each available volumes information
                        $send_list = @(
                            Write-Output '==========================================================' &&
                            Write-Output '==========================================================' &&
                            Write-Output "creation date =  $($object.CreateTime | Get-Date -Format 'MM-dd-yyyy')" &&
                            Write-Output "Volume ID =  $($object.VolumeId)" &&
                            Write-Output "Volume Status =  $($object.State.Value)" &&
                            Write-Output "Volume SnapshotId = $($object.SnapshotId)"
                            Write-Output "----------------volume tags-------------------------------" &&
                            $object.Tags | % { Write-Output "$($_.Key) =  $($_.Value)" } 
                        )
                        
                        $ebsvolumes_globally += $send_list
                        
                        $vol_id = $object.VolumeId

                        #TODO maybe optimize in future for -->'if {$object.SnapshotId=null/whitespace, then do { create snapshot of available ($volume_id), edit scheduled_removal tag for next day, then others with snapshots ids--> else{remove-volume}   }} $

                        Remove-EC2Volume -VolumeId $vol_id -Force

                        Write-Host "VolumeID $vol_id has been deleted."
                    }
                    else {
                        Write-Host "Second Pass Check for exemption tag and tag value of $todays_date didn't match for some odd reason."
                    }
                }
                $sendbody = $ebsvolumes_globally | Out-String
                send-sns-email -body $sendbody -region $main_region -attributevalue 5
            }
            else {
                Write-Host "No tags were matched for $todays_date, no volumes were deleted.  No SNS alert email was sent."
            }
        }
        catch {        
            Write-Host "$error[0]"
        }
    }
}

#tag EBS volumes
function tag_ebs_volumes { 
    param(
        $days = $ENV:days,
        $days_until_removed = $ENV:days_until_removed,
        $exemption_tag_value = $ENV:exemption_tag_value,
        $main_region = $ENV:main_region,
        $regions = $ENV:regions
    )

    $erroractionpreference = "Stop"
    $regions = $regions -split ","
    Write-Host "iterating through regions most used.  Regions are-- $regions"
    # to add ALL regions, a replica lambda function code would need to be create in each region WITHOUT the region iteration (otherwise it will just loop)
    $futureDate = (Get-Date).AddDays($days_until_removed)  #(Get-Date).AddDays($days).AddDays($days_until_removed)
    Write-Host "future date is $futureDate"
    $dateString = $futureDate.ToString("MM-dd-yyyy")
    Write-Host "the date string is $dateString"
    $delete_soon_tag_value = "scheduled_removal_$dateString"
    Write-Host "delete_soon_tag_value is $delete_soon_tag_value"

    # Loop through each region and remove the EBS volumes
    foreach ($region in $regions) {
        Write-Host "working with region $region"
        Set-DefaultAWSRegion -Region $region

        # Get all EBS volumes in the defined region
        $volumes = ((Get-EC2Volume -Region $region) | where { $_.CreateTime -le ((Get-Date).AddDays(-$days)) -and ($_.State -eq "available") -and (($_.Tags.Value | Out-String) -NotMatch "scheduled_removal_*") -and (($_.Tags.Value | Out-String) -NotMatch $exemption_tag_value) })
        Write-Host "there are currently $($volumes.count) EBS volumes that are in "AVAILABLE" status and are $days days or older"
        $volumes_listed = @()

        # Loop through each volume and retrieve the creation dates
        foreach ($volume in $volumes) {
            $tag_value = $volume.Tags.Value | Out-String
            
            #making sure tags are checked (second wave check with 'if' statement.)
            if (($tag_value -NotMatch $exemption_tag_value) -and ($tag_value -NotMatch "scheduled_removal_*")) { 
                $send_list = @(
                    Write-Output '==========================================================' &&
                    Write-Output '==========================================================' &&
                    Write-Output "creation date =  $($volume.CreateTime | Get-Date -Format 'MM-dd-yyyy')" &&
                    Write-Output "Volume ID =  $($volume.VolumeId)" &&
                    Write-Output "Volume Status =  $($volume.State.Value)" &&
                    Write-Output "Volume SnapshotId = $($volume.SnapshotId)"
                    Write-Output "----------------volume tags-------------------------------" &&
                    $volume.Tags | % { Write-Output "$($_.Key) =  $($_.Value)" } 
                )

                $volumes_listed += $send_list

                Write-Host "the tag value being added is--  $delete_soon_tag_value"
                $tagKey = "auto-remove-policy"
                $tagValue = ($delete_soon_tag_value | Out-String)
                    
                New-EC2Tag -Region $region -Resource $volume.VolumeId -Tag @{ Key = $tagKey; Value = $tagValue } &&
                Write-Host "$($volume.VolumeId) was tagged for removal and will be removed on $dateString" &&
                Write-Host $volumes_listed
            }     
        }
            
        if ($volumes.count -gt 0) { 
            $sendbody = $volumes_listed | Out-String 
            send-sns-email -body $sendbody -region $main_region
        }
    }
} 

function send-sns-email { 
    param(
        $body,
        $region,
        $attributevalue = 0
    )

    $todays_date_formatted = Get-Date -Format 'MM-dd-yyyy'

    $sns_name = $ENV:ebs_sns_name
    #get snstopic with topicarn that matches 

    $get_sns_topics = (Get-SNSTopic).TopicArn | where { $_ -match $sns_name } 

    #remove white space after changing type to string
    $get_sns_topic = ($get_sns_topics | Out-String).trim()

    if ($attributevalue -eq 0) {
        $text = @"
the following ebs volumes WILL BE REMOVED in 5 days. 

If there is no EBS Snapshot for any of the volumes listed.  Please do so within 5 days.

To Prevent any of these unused volumes from being removed, add the following tag it.
auto-remove-policy = no-auto-removal
-------------------------------------------------
$body
"@
        Set-SNSTopicAttribute -Region $region -TopicArn $get_sns_topic -AttributeName DisplayName -AttributeValue "AWS EBS removal report  $todays_date_formatted" &&
        Publish-SNSMessage -Region $region -TopicArn $get_sns_topic -Message $text
    }
    else {

        $text2 = @"
the following unused ebs volumes were REMOVED.

any unused ("available" status) EBS volulmes that were created more than 30 days ago are auto removed with 5 days notice email sent in case of preperations needed.

To Prevent any volumes from future auto removals, add the following tag it.
auto-remove-policy = no-auto-removal
-------------------------------------------------
$body
"@
        Set-SNSTopicAttribute -Region $region -TopicArn $get_sns_topic -AttributeName DisplayName -AttributeValue "AWS EBS volumes REMOVED $todays_date_formatted" &&
        Publish-SNSMessage -Region $region -TopicArn $get_sns_topic -Message $text2
    }
}

remove_expired_volumes && tag_ebs_volumes 
