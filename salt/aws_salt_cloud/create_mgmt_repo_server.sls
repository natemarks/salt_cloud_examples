# -*- coding: utf-8 -*-
# vim: ft=sls

{% from "aws/map.jinja" import aws with context %}
{% set vpc_settings = salt['pillar.get']('mgmt_environment') %}


create_red_repo_server_instance:
  cloud.profile:
    - name: red-repo-server.{{ vpc_settings.private_domain }}
    - profile: mgmt_profile_private
    - size: t2.medium
    - image: {{ vpc_settings.centos_ami[vpc_settings.region] }}
    - iam_profile: {{ vpc_settings.repo_manager_profile }}
    - block_device_mappings:
      - device: /dev/xvdb
        volume_id: {{ vpc_settings.repo_ebs_volume_id }}
    - tag:
        vpcEnvironment: {{ vpc_settings.vpcEnvironment }}
        az_side: red
    - minion:
        master: {{ vpc_settings.red_salt_master_private_fqdn }}
    - grains:
        roles:
          - saltMaster
        vpcEnvironment: {{ vpc_settings.vpcEnvironment }}
    - network_interfaces:
      - DeviceIndex: 0
        AssociatePublicIpAddress: False
        subnetname: mgmt_red_private_subnet
        securitygroupname:
          - repo_server_security_group

