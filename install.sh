#!/bin/bash
#==============================================================================
# Copyright (C) 2007-2015 Stephen F. Norledge and Alces Software Ltd.
#
# This file/package is part of Alces Metalware.
#
# Alces Metalware is free software: you can redistribute it and/or
# modify it under the terms of the GNU Affero General Public License
# as published by the Free Software Foundation, either version 3 of
# the License, or (at your option) any later version.
#
# Alces Metalware is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this package.  If not, see <http://www.gnu.org/licenses/>.
#
# For more information on the Alces Metalware, please visit:
# https://github.com/alces-software/metalware
#==============================================================================

# Vars
src_dir="${alces_SRC_DIR:-$(mktemp -d /tmp/rootrun.XXXXXX)}"
src_url="${alces_SRC_URL:-https://github.com/alces-software/rootrun.git}"
install_dir="${alces_INSTALL_DIR:-/opt/rootrun}"
install_type="${alces_INSTALL:-install}"

# Functions
install_file() {
    cp $src_dir/$1 $2
}


install_rootrun() {
    yum -y install git ruby
    mkdir -p $src_dir $install_dir
    cd $src_dir
    git clone $src_url $src_dir
    echo "Installing files..."
    install_file rootrun.rb $install_dir/
    install_file rootrun.yaml $install_dir/
    install_file rootrun.service /etc/systemd/system/
    echo "Loading, starting and enabling service..."
    systemctl daemon-reload
    systemctl enable rootrun
    systemctl restart rootrun
}

uninstall_rootrun() {
    echo "Stopping and removing service..."
    systemctl disable rootrun
    systemctl stop rootrun
    rm -f /etc/systemd/system/rootrun.service
    systemctl daemon-reload
    echo "Removing rootrun program files..."
    rm -rf $install_dir/
}

reinstall_rootrun() {
    uninstall_rootrun
    install_rootrun
}

# Checks
if (( UID != 0 )); then
  echo "$0: must run as root"
  exit 1
fi

# Run Installer
case $install_type in
    'install')
        install_rootrun
        ;;
    'uninstall')
        uninstall_rootrun
        ;;
    'reinstall')
        reinstall_rootrun
        ;;
    *)
        echo "'$install_type' - Unknown install option, should be install, uninstall or reinstall"
        exit 1
        ;;
esac
