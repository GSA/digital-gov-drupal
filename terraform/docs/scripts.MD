# Cloud.gov Scripts

These are scripts that are located in the `scripts` directory.

## cloudgov-aws-creds.sh

This script will export credentials to `AWS_ACCESS_KEY_ID`, `AWS_BUCKET`, `AWS_DEFAULT_REGION`, and `AWS_SECRET_ACCESS_KEY`. The export below, `bucket_name` is different than `AWS_BUCKET`, as `bucket_name` is the name of the Cloud.gov service, while `AWS_BUCKET` is the name of the bucket in AWS.

After exporting the credentials, running `aws s3 ls s3://${AWS_BUCKET}/` should list the files in the bucket.

After using the script, running the script again will delete the credentials, cleaning them up.

- `deploy_space`: the space where you would like the account to be provisioned at.
- `bucket_name`: the name of the bucket to generate credentials for.

```
export deploy_space="space_name_prod"
export bucket_name="bucket_name"
source ./cloudgov-aws-creds.sh
```

## cloud-gov-create-service-account.sh

This creates pipeline service account credentials for your spaces. If credentials need to be regenerated or rotated, be sure to `tf apply` to the Terraform `bootstrap` environment to update the CircleCI variables.

- `deploy_space`: the space where you would like the account to be provisioned at.
- `org`: the name of the Cloud.gov organization your account is under.
- `prefix`: A name that can be used as a resource prefix for every resource. It is optional.
- `spaces`: A space separated string with all the spaces the service account should have access to.

```
export deploy_space="space_name_prod"
export org="org_name"
export prefix="name_prefix"
export spaces="space_name_dev space_name_stage space_name_prod"
bash init.sh
```

## egress-network-policy.sh

This script allows public internet access from the provided `deploy_space` variable.

***NOTE: This should only need to be ran once, during project setup.***

- `deploy_space`: the space where you would like the account to be provisioned at.
- `org`: the name of the Cloud.gov organization your account is under.

```
export deploy_space="space_name_dmz"
export org="org_name"
bash egress-network-policy.sh
```

## init.sh

The `init.sh` script is located in the scripts directory of this repository. This script creates the S3 buckets for the Terraform backend and backups.

After creating the S3 Buckets, the script will also execute `cloud-gov-create-service-account.sh`. This will create a service account that is used to deploy infrastructure from the pipeline.

***NOTE: This should only need to be ran once, during project setup.***

Before running this script, make sure to login to Cloud.gov with `cf login -a api.fr.cloud.gov  --sso`.

- `deploy_space`: the space where you would like the account to be provisioned at.
- `org`: the name of the Cloud.gov organization your account is under.
- `prefix`: A name that can be used as a resource prefix for every resource. It is optional.
- `spaces`: A space separated string with all the spaces the service account should have access to.

```
export deploy_space="space_name_prod"
export org="org_name"
export prefix="name_prefix"
export spaces="space_name_dev space_name_stage space_name_prod"
bash init.sh
```