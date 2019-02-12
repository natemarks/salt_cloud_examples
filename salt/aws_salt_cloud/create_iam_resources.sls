{% set profile = salt['pillar.get']('dev_profile') %}

create codecommit readonly policy:
  boto_iam.policy_present:
    - name: Pull_Salt_Master_Repos_from_Code_Commit
    - description: 'Policy required by salt master EC2 instances to be able to pull the salt tree from code commit'
    - profile: {{ profile }}
    - policy_document: |
        {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Action": [
                        "codecommit:GitPull"
                    ],
                    "Resource": [
                        "arn:aws:codecommit:*:*:salt_master",
                        "arn:aws:codecommit:*:*:zendeploy"
                    ],
                    "Effect": "Allow"
                }
            ]
        }

create codecommit readonly role::
    boto_iam_role.present:
    - name: Salt_Master_Code_Commit_Puller
    - profile: {{ profile }}
    - managed_policies:
      - Pull_Salt_Master_Repos_from_Code_Commit


create public s3 repo access policy:
  boto_iam.policy_present:
    - name: Repo_Manager_S3_Access
    - description: 'Policy required by repo server to sync content to the public repo'
    - profile: {{ profile }}
    - policy_document: |
        {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Action": [
                        "s3:*"
                    ],
                    "Resource": [
                        "arn:aws:s3:::repo.<SOMEDOMAIN>",
                        "arn:aws:s3:::repo.<SOMEDOMAIN>/*"
                    ],
                    "Effect": "Allow"
                }
            ]
        }

create public s3 repo access role::
    boto_iam_role.present:
    - name: Repo_Manager
    - profile: {{ profile }}
    - managed_policies:
      - Repo_Manager_S3_Access

kinesis to elasticsearch access policy:
  boto_iam.policy_present:
    - name: Kinesis_to_Elasticsearch_Access
    - description: 'Policy required to move records from kinesis to elasticsearch'
    - profile: {{ profile }}
    - policy_document: |
        {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Action": [
                        "s3:*"
                    ],
                    "Resource": [
                        "arn:aws:s3:::repo.<SOMEDOMAIN>",
                        "arn:aws:s3:::repo.<SOMEDOMAIN>/*"
                    ],
                    "Effect": "Allow"
                }
            ]
        }

kinesis to elasticsearch role::
    boto_iam_role.present:
    - name: Kinesis_to_Elasticsearch
    - profile: {{ profile }}
    - managed_policies:
      - Kinesis_to_Elasticsearch_Access

