Import-Module AWSPowerShell

# Set AWS credentials if not already configured
# Initialize-AWSDefaults

$bucketName = Read-Host -Prompt 'Enter the name of the S3 bucket where the DevVM image will be stored.'
$devVmFilePath = Read-Host -Prompt 'Enter the full path to your DevVM. (Ex. C:\RelativityDevVm-11.0.\Virtual Hard Disks\DevVmBase.vhdx'
$devVmKey = Read-Host -Prompt 'Enter the desired key name of the DevVM for the S3 bucket. (i.e. the name of the .vhdx file)'

# SETUP
# Create the "vmimport" role, and give the vmie.amazonaws.com service permission to assume it - the EC2 import API looks for a role named "vmimport" by default.
$importPolicyDocument = @"
{
   "Version":"2012-10-17",
   "Statement":[
      {
         "Sid":"",
         "Effect":"Allow",
         "Principal":{
            "Service":"vmie.amazonaws.com"
         },
         "Action":"sts:AssumeRole",
         "Condition":{
            "StringEquals":{
               "sts:ExternalId":"vmimport"
            }
         }
      }
   ]
}
"@
New-IAMRole -RoleName vmimport -AssumeRolePolicyDocument $importPolicyDocument

# Add a policy that allows access to the EC2 bucket containing the image
$rolePolicyDocument = @"
{
   "Version":"2012-10-17",
   "Statement":[
      {
         "Effect":"Allow",
         "Action":[
            "s3:ListBucket",
            "s3:GetBucketLocation"
         ],
         "Resource":[
            "arn:aws:s3:::$bucketName"
         ]
      },
      {
         "Effect":"Allow",
         "Action":[
            "s3:GetObject"
         ],
         "Resource":[
            "arn:aws:s3:::$bucketName/*"
         ]
      },
      {
         "Effect":"Allow",
         "Action":[
            "ec2:ModifySnapshotAttribute",
            "ec2:CopySnapshot",
            "ec2:RegisterImage",
            "ec2:Describe*"
         ],
         "Resource":"*"
      }
   ]
}
"@
Write-IAMRolePolicy -RoleName vmimport -PolicyName vmimport -PolicyDocument $rolePolicyDocument

# UPLOAD
Write-S3Object -BucketName $bucketName -File $devVmFilePath -Key $devVmKey

# IMPORT
$windowsContainer = New-Object Amazon.EC2.Model.ImageDiskContainer
$windowsContainer.Format = "VHDX"

$userBucket = New-Object Amazon.EC2.Model.UserBucket
$userBucket.S3Bucket = $bucketName
$userBucket.S3Key = $devVmKey
$windowsContainer.UserBucket = $userBucket

$params = @{
    "ClientToken"="RelDevVm_" + (Get-Date)
    "Description"="Relativity DevVM Import"
    "Platform"="Windows"
    "LicenseType"="AWS"
}

Import-EC2Image -DiskContainer $windowsContainer @params

# Use the command "Get-EC2ImportImageTask" to get the status of the Import Job as it runs. Specify a specific Import Job using the ImportTaskID param