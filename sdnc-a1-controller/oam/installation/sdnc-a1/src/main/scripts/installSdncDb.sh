#!/bin/bash

###
# ============LICENSE_START=======================================================
# openECOMP : SDN-C
# ================================================================================
# Copyright (C) 2017 AT&T Intellectual Property. All rights
# 							reserved.
# Modifications Copyright (C) 2020 Nordix Foundation.
# ================================================================================
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ============LICENSE_END=========================================================
###

SDNC_HOME=${SDNC_HOME:-/opt/onap/sdnc}
MYSQL_PASSWD=${MYSQL_PASSWD:-openECOMP1.0}

SDNC_DB_USER=${SDNC_DB_USER:-sdnctl}
SDNC_DB_PASSWD=${SDNC_DB_PASSWD:-gamma}
SDNC_DB_DATABASE=${SDN_DB_DATABASE:-sdnctl}


# Create tablespace and user account
mysql -h dbhost -u root -p${MYSQL_PASSWD} mysql <<-END
CREATE DATABASE ${SDNC_DB_DATABASE};
CREATE USER '${SDNC_DB_USER}'@'localhost' IDENTIFIED BY '${SDNC_DB_PASSWD}';
CREATE USER '${SDNC_DB_USER}'@'%' IDENTIFIED BY '${SDNC_DB_PASSWD}';
GRANT ALL PRIVILEGES ON ${SDNC_DB_DATABASE}.* TO '${SDNC_DB_USER}'@'localhost' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON ${SDNC_DB_DATABASE}.* TO '${SDNC_DB_USER}'@'%' WITH GRANT OPTION;
commit;
END

# load schema
if [ -f ${SDNC_HOME}/data/sdnctl.dump ]
then
  echo "Installing ${SDNC_HOME}/data/sdnctl.dump"
  mysql -h dbhost -u root -p${MYSQL_PASSWD} sdnctl < ${SDNC_HOME}/data/sdnctl.dump
fi
