{#
create an rds that usses the two provate subnets in mgmt_vpc (via include?) as the subnet group using

Ensure myrds RDS exists:
  boto_rds.present:
#}