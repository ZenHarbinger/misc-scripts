#!/usr/bin/bash
# creates a new tenant/user
# optionally creates a generic network and allows ICMP/SSH
# usage :: run from openstack controller
# usage :: i.e. 'source keystonerc_admin'
# usage :: ./openstack-create-user.sh

# replace this with the ID of your admin external network
EXTERNAL_NET_ID="XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
CONTROLLER_PUB_IP="1.1.1.1"
USER_PASSWORD="changethis"
USER_DOMAIN="@example.com"

get_id() {
  echo `"$@" | awk '/id / {print $4}'`
}

create_tenant_user() {

tenant_id=$(get_id keystone tenant-get ${tenant_name})
  if [[ -z $tenant_id ]]
  then
	tenant_id=$(get_id keystone tenant-create --name=${tenant_name})
  fi

  user_id=$(get_id keystone user-create --name=$user_name --pass=$password --email=${user_name}${USER_DOMAIN})
  member_id=$(get_id keystone role-get _member_)
  echo keystone user-role-add --tenant-id $tenant_id --user-id $user_id --role-id $member_id

cat > keystonerc_${user_name} <<EOF
export OS_TENANT_NAME=$tenant_name
export OS_USERNAME=$user_name
export OS_PASSWORD=$USER_PASSWORD
export OS_AUTH_URL="http://${CONTROLLER_PUB_IP}:5000/v2.0/"
export OS_AUTH_STRATEGY=keystone
export PS1="[\u@\h \W(keystone_$user_name)]$ "
EOF
}

create_tenant_network() {
  tenant_network_name=default-network-$tenant_name
  tenant_router_name=default-router-$tenant_name
  tenant_subnet_name=default-subnet-$tenant_name
  tenant_subnet_net=192.168.1.0
  tenant_created_id=$(keystone tenant-get $tenant_name | grep id | awk '{print $4}')

  # source newly created keystonerc so we create network as that user
  source /root/keystonerc.d/keystonerc_$user_name

  # create new network, subnet and router
  neutron net-create $tenant_network_name
  neutron subnet-create $tenant_network_name $tenant_subnet_net/24 --name $tenant_subnet_name
  neutron router-create $tenant_router_name

  # obtain newly created router, network and subnet id
  tenant_router_id=$(neutron router-list | grep $tenant_router_name | awk '{print $2}')
  tenant_subnet_id=$(neutron subnet-list | grep $tenant_subnet_name | awk '{print $2}')
  tenant_network_id=$(neutron net-list | grep $tenant_network_name | awk '{print $2}')

  # associate router and add interface to the router
  neutron router-gateway-set $tenant_router_id $EXTERNAL_NET_ID
  neutron router-interface-add $tenant_router_id $tenant
}

create_tenant_securitygroup() {
	neutron security-group-rule-create   \
		--protocol icmp		     \
                --direction ingress          \
		--remote-ip-prefix 0.0.0.0/0 \
		default
	neutron security-group-rule-create   \
		--protocol tcp               \
		--port-range-min 22          \
		--port-range-max 22          \
		--direction ingress          \
		--remote-ip-prefix 0.0.0.0/0 \
		default
}

# parse input and execute functions
cat <<EndofMessage

#####################################################
#                Account Creator 6000               #
#                                                   #
#####################################################

EndofMessage

echo -en "Enter Tenant name (defaults to username): "
read tenant_name

echo -en "Enter User name: "
read user_name

echo -en "Create Generic Network? Y/N: "
read generic_net

# sanity check network input
case $generic_net in
	y|Y) create_network="1"
		;;
	n|N) create_network="0"
		;;
	*)   echo "::Error:: Answer Y/N for network creation"
	     exit 1
esac

if [ -z $generic_net ];
then
	echo "::ERROR:: Network selection empty, choose Y/N"
	exit 1
fi

# call function to create tenant and user
if [ ! -z $tenant_name ] && [ ! -z $user_name ];
then
        create_tenant_user $tenant_name $user_name $USER_PASSWORD
else
	echo "::ERROR:: either tenant or user is empty"
	exit 1
fi

# call function to create generic network
if [ $create_network == "1" ];
then
	create_tenant_network
fi

echo "moving keystonerc_$tenant_name to /root/keystonerc.d/.."
mv keystonerc_$user_name /root/keystonerc.d/

# summarize what we did
cat <<EndofMessage

####################################
#      OSLab Account Summary       #
====================================
Username:     $user_name
Tenant:       $tenant_name
Tenant ID:    $(keystone tenant-get $tenant_name | grep id | awk '{print $4}')
Network Name: $tenant_network_name
Network ID:   $tenant_network_id
====================================

EndofMessage
