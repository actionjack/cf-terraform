#!/bin/bash

set -euo pipefail # fail on error
export PATH=/opt/puppetlabs/puppet/bin/:$PATH

wget https://apt.puppetlabs.com/puppetlabs-release-pc1-trusty.deb
sudo dpkg -i puppetlabs-release-pc1-trusty.deb
sudo apt-get update
sudo apt-get install puppet-agent -y

sudo /opt/puppetlabs/puppet/bin/puppet module install maestrodev-wget
sudo /opt/puppetlabs/puppet/bin/puppet module install puppetlabs-ruby
sudo /opt/puppetlabs/puppet/bin/puppet module install ploperations-bundler
sudo /opt/puppetlabs/puppet/bin/puppet module install dsestero-download_uncompress
sudo /opt/puppetlabs/puppet/bin/puppet apply scripts/provision.pp

