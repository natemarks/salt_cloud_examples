# -*- coding: utf-8 -*-
# vim: ft=sls

{% from "aws/map.jinja" import aws with context %}
{% set vpc_settings = salt['pillar.get']('mgmt_environment') %}

management_vpc:
  boto_vpc.present:
    - name: management_vpc
    - cidr_block: {{ vpc_settings.vpc_cidr_block }}
    - dns_hostnames: True
    - dns_support: True
    - profile: {{ vpc_settings.profile }}
    - tags:
        vpcEnvironment: {{ vpc_settings.vpcEnvironment }}

{#   CREATE INITIAL SUBNETS AND GATEWAYS  #}

mgmt_red_private_subnet:
  boto_vpc.subnet_present:
    - name: mgmt_red_private_subnet
    - vpc_name: management_vpc
    - cidr_block: {{ vpc_settings.vpc_cidr_prepend }}0.0/24
    - availability_zone: {{ vpc_settings.red_availability_zone }}
    - profile: {{ vpc_settings.profile }}
    - tags:
        vpcEnvironment: {{ vpc_settings.vpcEnvironment }}
        az: 'red'
        internet_access: 'private'

mgmt_blue_private_subnet:
  boto_vpc.subnet_present:
    - name: mgmt_blue_private_subnet
    - vpc_name: management_vpc
    - cidr_block: {{ vpc_settings.vpc_cidr_prepend }}1.0/24
    - availability_zone: {{ vpc_settings.blue_availability_zone }}
    - profile: {{ vpc_settings.profile }}
    - tags:
        vpcEnvironment: {{ vpc_settings.vpcEnvironment }}
        az: 'blue'
        internet_access: 'private'

mgmt_red_public_subnet:
  boto_vpc.subnet_present:
    - name: mgmt_red_public_subnet
    - vpc_name: management_vpc
    - cidr_block: {{ vpc_settings.vpc_cidr_prepend }}2.0/24
    - availability_zone: {{ vpc_settings.red_availability_zone }}
    - profile: {{ vpc_settings.profile }}
    - tags:
        vpcEnvironment: {{ vpc_settings.vpcEnvironment }}
        az: 'red'
        internet_access: 'public'

mgmt_blue_public_subnet:
  boto_vpc.subnet_present:
    - name: mgmt_blue_public_subnet
    - vpc_name: management_vpc
    - cidr_block: {{ vpc_settings.vpc_cidr_prepend }}3.0/24
    - availability_zone: {{ vpc_settings.blue_availability_zone }}
    - profile: {{ vpc_settings.profile }}
    - tags:
        vpcEnvironment: {{ vpc_settings.vpcEnvironment }}
        az: 'blue'
        internet_access: 'public'

{# NAT Gateways are used to allow outbound-only (PAT) access to the internet from private subnets#}
mgmt_red_nat_gateway:
  boto_vpc.nat_gateway_present:
    - name: mgmt_red_nat_gateway
    - subnet_name: mgmt_red_public_subnet
    - allocation_id: {{ vpc_settings.red_nat_gateway_eip_id }}
    - profile: {{ vpc_settings.profile }}

mgmt_blue_nat_gateway:
  boto_vpc.nat_gateway_present:
    - name: mgmt_blue_nat_gateway
    - subnet_name: mgmt_blue_public_subnet
    - allocation_id: {{ vpc_settings.blue_nat_gateway_eip_id }}
    - profile: {{ vpc_settings.profile }}

{# Only need one internet gateway for the VPC. It's available regardless of az status #}
mgmt_vpc_internet_gateway:
  boto_vpc.internet_gateway_present:
    - name: mgmt_vpc_internet_gateway
    - vpc_name: management_vpc
    - profile: {{ vpc_settings.profile }}

{#  The NAT Gateways take some time to create so we build in some  a wait and use retries when adding them to RT #}
wait_for_nat_gateways:
  module.run:
    - name: test.sleep
    - length: 90

mgmt_red_private_route_table:
  boto_vpc.route_table_present:
    - vpc_name: management_vpc
    - name: mgmt_red_private_route_table
    - profile: {{ vpc_settings.profile }}
    - subnet_names:
      - mgmt_red_private_subnet
    - routes:
      - destination_cidr_block: 0.0.0.0/0
        nat_gateway_subnet_name: mgmt_red_public_subnet
    - tags:
        vpcEnvironment: {{ vpc_settings.vpcEnvironment }}
        az: 'red'
    - retry:
        attempts: 5
        until: True
        interval: 60

mgmt_blue_private_route_table:
  boto_vpc.route_table_present:
    - vpc_name: management_vpc
    - name: mgmt_blue_private_route_table
    - profile: {{ vpc_settings.profile }}
    - subnet_names:
      - mgmt_blue_private_subnet
    - routes:
      - destination_cidr_block: 0.0.0.0/0
        nat_gateway_subnet_name: mgmt_blue_public_subnet
    - tags:
        vpcEnvironment: {{ vpc_settings.vpcEnvironment }}
        az: 'blue'
    - retry:
        attempts: 5
        until: True
        interval: 60

mgmt_public_route_table:
  boto_vpc.route_table_present:
    - vpc_name: management_vpc
    - name: mgmt_public_route_table
    - profile: {{ vpc_settings.profile }}
    - subnet_names:
      - mgmt_red_public_subnet
      - mgmt_blue_public_subnet
    - routes:
      - destination_cidr_block: 0.0.0.0/0
        internet_gateway_name: mgmt_vpc_internet_gateway
    - tags:
        vpcEnvironment: {{ vpc_settings.vpcEnvironment }}
    - retry:
        attempts: 5
        until: True
        interval: 60

private_zone:
  boto3_route53.hosted_zone_present:
    - name: private_mgmt_vpc_zone
    - Name: mgmt-ncareconnect.aws.ncare.
    - PrivateZone: True
    - Comment: private zone for MGMT vpc
    - VPCs:
      - VPCName: management_vpc
        VPCRegion: {{ vpc_settings.region }}
    - profile: {{ vpc_settings.profile }}

salt_master_security_group:
  boto_secgroup.present:
    - name: salt_master_security_group
    - description: allows public internet access for salt-cloud init and ongoing master access from minions
    - vpc_name: management_vpc
    - profile: {{ vpc_settings.profile }}
    - tags:
        vpcEnvironment: {{ vpc_settings.vpcEnvironment }}
    - rules:
      - ip_protocol: tcp
        from_port: 22
        to_port: 22
        cidr_ip:
{% for addr in vpc_settings.trusted_internet_ipv4_addresses %}
          - {{ addr }}
{% endfor %}
      - ip_protocol: tcp
        from_port: 4505
        to_port: 4506
        cidr_ip:
          - 0.0.0.0/0



repo_server_security_group:
  boto_secgroup.present:
    - name: repo_server_security_group
    - description: allows access to repo server
    - vpc_name: management_vpc
    - profile: {{ vpc_settings.profile }}
    - tags:
        vpcEnvironment: {{ vpc_settings.vpcEnvironment }}
    - rules:
      - ip_protocol: tcp
        from_port: 22
        to_port: 22
        cidr_ip:
          - {{ vpc_settings.vpc_cidr_block }}
      - ip_protocol: tcp
        from_port: 80
        to_port: 80
        cidr_ip:
          - 0.0.0.0/0




elasticsearch_security_group:
  boto_secgroup.present:
    - name: elasticsearch_security_group
    - description: allows access to Elasticsearch domain
    - vpc_name: management_vpc
    - profile: {{ vpc_settings.profile }}
    - tags:
        vpcEnvironment: {{ vpc_settings.vpcEnvironment }}
    - rules:
      - ip_protocol: tcp
        from_port: 9200
        to_port: 9200
        cidr_ip:
          - {{ vpc_settings.vpc_cidr_block }}ss



