#!/bin/bash

if [ -d patches/tripleo-heat-templates ]; then
	TEMPLATES=$PWD/patches/tripleo-heat-templates
else
	TEMPLATES=/usr/share/openstack-tripleo-heat-templates
fi

# When passing environment files (`-e ...`) to the `overcloud deploy`
# command, order is important! Your custom configuration
# (`$PWD/templates/deploy.yaml` in this script) should come *last*,
# in particular because the network interface configuration is
# initialized by `deployed-server-environment.yaml`.  If your custom
# configuration were provided first, the network interface
# configuration you provide would be lost and replaced with the
# defaults.

deploy_args=(
	# network_data.yaml defines a custom network configuration. In 
	# particular, we disable the StorageMgmt network, since we're not
	# using it.
	-n $PWD/templates/network/network_data.yaml

	# Enable network isolation (using different networks for different
	# purposes).
	-e $TEMPLATES/environments/network-isolation.yaml

	# Enable deployment onto pre-provisioned servers.
	-e $TEMPLATES/environments/deployed-server-environment.yaml
	-e $TEMPLATES/environments/deployed-server-bootstrap-environment-rhel.yaml
	-e $TEMPLATES/environments/deployed-server-pacemaker-environment.yaml
	-r $TEMPLATES/deployed-server/deployed-server-roles-data.yaml

	# Enable TLS for public endpoints.
	-e $TEMPLATES/environments/ssl/enable-tls.yaml
	-e $TEMPLATES/environments/tls-endpoints-public-dns.yaml

	# Enable Neutron LBaaS service.
	-e $TEMPLATES/environments/services/neutron-lbaasv2.yaml

	# Override default horizon service template with one that enables
	# the lbaas ui This is a workaround for
	# https://bugzilla.redhat.com/show_bug.cgi?id=1573808
	-e $PWD/templates/enable-lbaas-ui.yaml

	# Enable Sahara
	-e $TEMPLATES/environments/services/sahara.yaml

	# Enable OpenIDC federation
	-e $TEMPLATES/environments/enable-federation-openidc.yaml

	# Use Docker registry on the undercloud.
	-e $PWD/templates/overcloud_images.yaml

	# Enable keystone federation
	-e $PWD/templates/single-signon.yaml

	# Enable external Ceph cluster
	-e $TEMPLATES/environments/ceph-ansible/ceph-ansible-external.yaml
	-e $PWD/templates/ceph-external.yaml

	# Enable external Ceph RadosGW (object storage)
	-e $TEMPLATES/environments/swift-external.yaml
	-e $PWD/templates/swift-external.yaml

	# Most of our custom configuration.
	-e $PWD/templates/deploy.yaml

	# Passwords and other credentials (this file is not included in
	# the repository).
	-e $PWD/templates/credentials.yaml
)

if [ -d patches/puppet-modules ]; then
	upload-puppet-modules -d patches/puppet-modules
	deploy_args+=(-e $HOME/.tripleo/environments/puppet-modules-url.yaml)
fi

openstack overcloud deploy \
	--templates $TEMPLATES \
	--disable-validations --deployed-server \
	--libvirt-type kvm \
	--ntp-server pool.ntp.org \
	"${deploy_args[@]}" \
	"$@"
