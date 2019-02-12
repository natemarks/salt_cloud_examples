# -*- coding: utf-8 -*-
# vim: ft=sls

{% from "aws/map.jinja" import aws with context %}
{% set vpc_settings = salt['pillar.get']('mgmt_environment') %}

# include:
#   - aws.create_mgmt_vpc


create_red_salt_master_instance:
  cloud.profile:
    - name: red-salt-master.{{ vpc_settings.private_domain }}
    - profile: mgmt_profile
    - size: t2.large
    - image: {{ vpc_settings.centos_ami[vpc_settings.region] }}
    - iam_profile: {{ vpc_settings.salt_master_code_commit_profile }}
    - tag:
        vpcEnvironment: {{ vpc_settings.vpcEnvironment }}
        az_side: red
    - minion:
        master: {{ vpc_settings.dev_red_salt_master_public_ip }}
    - grains:
        roles:
          - saltMaster
        vpcEnvironment: {{ vpc_settings.vpcEnvironment }}
    - network_interfaces:
      - DeviceIndex: 0
        associate_eip: {{ vpc_settings.red_salt_master_public_eip }}
        subnetname: mgmt_red_public_subnet
        securitygroupname:
          - salt_master_security_group


create_blue_salt_master_instance:
  cloud.profile:
    - name: blue-salt-master.{{ vpc_settings.private_domain }}
    - profile: mgmt_profile
    - size: t2.large
    - image: {{ vpc_settings.centos_ami[vpc_settings.region] }}
    - iam_profile: {{ vpc_settings.salt_master_code_commit_profile }}
    - tag:
        vpcEnvironment: {{ vpc_settings.vpcEnvironment }}
        az_side: blue
    - minion:
        master: {{ vpc_settings.dev_red_salt_master_public_ip }}
    - grains:
        roles:
          - saltMaster
        vpcEnvironment: {{ vpc_settings.vpcEnvironment }}
    - network_interfaces:
      - DeviceIndex: 0
        associate_eip: {{ vpc_settings.blue_salt_master_public_eip }}
        subnetname: mgmt_blue_public_subnet
        securitygroupname:
          - salt_master_security_group


create_red_master_private_dns_entry:
  boto3_route53.rr_present:
    - name: red-salt-master.{{ vpc_settings.private_domain }}.
    - DomainName: {{ vpc_settings.private_domain }}.
    - PrivateZone: True
    - Type: A
    - TTL: 60
    - ResourceRecords:
      - "magic:ec2_instance_tag:Name:red-salt-master.{{ vpc_settings.private_domain }}:private_ip_address"
    - profile: {{ vpc_settings.profile }}


create_blue_master_private_dns_entry:
  boto3_route53.rr_present:
    - name: blue-salt-master.{{ vpc_settings.private_domain }}.
    - DomainName: {{ vpc_settings.private_domain }}.
    - PrivateZone: True
    - Type: A
    - TTL: 60
    - ResourceRecords:
      - "magic:ec2_instance_tag:Name:blue-salt-master.{{ vpc_settings.private_domain }}:private_ip_address"
    - profile: {{ vpc_settings.profile }}
