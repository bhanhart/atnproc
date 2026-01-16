#!/bin/bash

#******************************************************************************
#-- FILE   : MUAC_setup.sh
#-- PROJECT: ProATN
#-- MODULE : R2MS
#-- VERSION: $Revision$
#-- DESIGN :
#-- END
#
# TITLE: Template for Cluster Configuration of the ProATN
#
# DESCRIPTION:
#  Script to configure the Resiliency function of the ProATN
#   - IP virtual addresses
#   - ProATN stack
#   - ProATN SNMP Agent
#   - Ethernet devices monitoring (optional)
#   - X25 driver (optional)
#   - Native SNMP Agent (optional)
#
# PARAMETERS:
#   None
#
# SPECIAL CONSIDERATIONS:
# Encoding rules (xxx start with a lower case):
#   pr-xxx Primitive
#   ms-xxx Master/Slave resource
#   xxx-clone Clone reseource
#   gr-xxx Groupe resource
#
# REVISION HISTORY:
# 30/03/2016 Trac#40 Initial version
# 03/07/2018 Trac#55 Add Thalix SNMP Host Agent service
# 21/05/2019 Trac#60 add daemonizer for ll_stack to use proatn. Wait 30s for the start of the ll_stack.
# 21/05/2019 Trac#60 add daemonizer for ll_agent to use user proatn.
# 09/04/2020 Trac#65 add start_max_time of sagt
# xx/xx/2022 DLFEP_2022-10: migration to NewPENS
#******************************************************************************

# ----------- BEGIN CUSTOM SECTION ------------

# VIRTUAL IP ADDRESS resource (pr-IP[x])
# ======================================
# Mandatory parameters:
IP1_addr="10.150.112.142"
IP1_nic="net3:0"
IP1_mask="29"

IP2_addr="192.168.54.8"
IP2_nic="net2:0"
IP2_mask="28"

# Optional parameters (route creation)
# route : Host routes (one or several IP addresses separated with comma).
# route_net + route_netmask : Network route
# route_gtw : Gateway

# LL_STACK resource (pr-ll_stack)
# ===============================
# Configuration of the ATN stack
LL_STACK_STARTUP_SCRIPT="/home/proatn/topology/muac/generation/CURRENT/EDYY_GBIS/start_all"
# Type of the ATN stack (BIS, IS or ES)
LL_STACK_SYSTEM_TYPE="BIS"

# LL_AGENT resource (pr-ll_agent) : LL_STACK SNMP Agent
# =====================================================
# Flag indicating if the ProATN SNMP Agent resource needs to be created (YES or NO)
LL_AGENT_IS_USED="YES"
# Configuration of the ATN stack
LL_AGENT_STARTUP_SCRIPT="/opt/ProATN/LL_AGENT/cnf/sagt.cnf"
# SNMP Agent port number
LL_AGENT_PORT_NUMBER="1161"

#
# =============================
# Additional OPTIONAL RESOURCES
# =============================
# ETHERNET DEVICES MONITORING resource (pr-eth)
# ---------------------------------------------
# Configuration of the monitoring:  logical expression using (, ), & and | operators
# "(eth0&eth1)|bond0" = if eth0 and eth1 are down or bond0 is down, node is put in standby.
# This facility is optional: when set to empty, the monitoring resource is not created.
ETH_DEVICES=""

# X25 DEVICE resource (pr-x25)
# ----------------------------
# Flag indicating if the X25 resource needs to be created (YES or NO)
# Configuration of the resource done inside the CMN_x25 script
X25_IS_USED="NO"

# Native SNMP Agent resource (pr-snmp)
# ------------------------------------
# Flag indicating if the Native SNMP Agent resource needs to be created (YES or NO)
SNMP_IS_USED="NO"

# Host SNMP Agent resource (pr-snmp-host)
# ------------------------------------
# Flag indicating if the Native SNMP Agent resource needs to be created (YES or NO)
SNMP_HOST_AGENT_IS_USED="NO"


# ----------- END CUSTOM SECTION ------------

function E {
echo "$@"
"$@"
}

# Switch all nodes to standby
E pcs cluster standby --all
E sleep 3
E cibadmin -E --force
E pcs resource cleanup
E sleep 1
# Cluster nodes will no longer be in standby after the cibadmin command
E pcs cluster standby --all
E sleep 1
E pcs property set no-quorum-policy=ignore
E pcs property set stonith-enabled=false
E pcs cluster verify -V
E sleep 3

if [ "${SNMP_IS_USED}" == "YES" ]
then
# Configure SNMP Agent clone service
E pcs resource create pr-snmp ocf:r2ms:CMN_snmp op monitor interval=29s
E pcs resource clone pr-snmp
fi

if [ "${SNMP_HOST_AGENT_IS_USED}" == "YES" ]
then
# Configure SNMP Host Agent clone service
E pcs resource create pr-snmp-host ocf:r2ms:CMN_snmp_host_agent op monitor interval=29s
E pcs resource clone pr-snmp-host
fi

if [ "${ETH_DEVICES}" != "" ]
then
# Configure eth device clone service
E pcs resource create pr-eth ocf:r2ms:CMN_ethDevices monitored_devices="${ETH_DEVICES}" op monitor interval=13s
E pcs resource clone pr-eth
fi

# Configure Groupe of Resources
E pcs resource create pr-IP1 ocf:r2ms:CMN_IPaddr2 ip=${IP1_addr} nic=${IP1_nic} cidr_netmask=${IP1_mask} op monitor interval=73s
E pcs resource create pr-IP2 ocf:r2ms:CMN_IPaddr2 ip=${IP2_addr} nic=${IP2_nic} cidr_netmask=${IP2_mask} op monitor interval=79s
E pcs resource create pr-ll_stack ocf:r2ms:PROATN_ll_stack startup_script=${LL_STACK_STARTUP_SCRIPT} system_type=${LL_STACK_SYSTEM_TYPE} start_max_time=30 op monitor interval=5s start-delay=5s
if [ "${LL_AGENT_IS_USED}" == "YES" ]
then
E pcs resource create pr-ll_agent ocf:r2ms:PROATN_snmp startup_script=${LL_AGENT_STARTUP_SCRIPT} port=${LL_AGENT_PORT_NUMBER} start_max_time=30 op start start-delay=3s op monitor interval=17s start-delay=5s
fi

if [ "${X25_IS_USED}" == "YES" ]
then
E pcs resource create pr-x25 ocf:r2ms:CMN_x25 op monitor interval=11s
if [ "${LL_AGENT_IS_USED}" == "YES" ]
then
E pcs resource group add gr-ProATN pr-IP1 pr-IP2 pr-x25 pr-ll_stack pr-ll_agent
else
E pcs resource group add gr-ProATN pr-IP1 pr-IP2 pr-x25 pr-ll_stack
fi
else
if [ "${LL_AGENT_IS_USED}" == "YES" ]
then
E pcs resource group add gr-ProATN pr-IP1 pr-IP2 pr-ll_stack pr-ll_agent
#
# MUAC additions for capturing of ATN traffic
#
E pcs resource create pr-atn_lan_capture systemd:atn_lan_capture op monitor interval=60
# Prefer restarting on the current node and set failure-timeout < monitor-interval
# to prevent that ll_stack is moved in case of failure
E pcs resource meta pr-atn_lan_capture restart-type=restart failure-timeout=30s resource-stickiness=100
# Start ATN capture before gr-ProATN but don't block gr-ProATN startup if it fails
# shellcheck disable=SC1010
E pcs constraint order start pr-atn_lan_capture then start pr-ll_stack kind=Optional require-all=false
# Attempt to colocate ATN capture without causing gr-ProATN to move or restart on failure
E pcs constraint colocation add pr-atn_lan_capture with gr-ProATN 200
else
E pcs resource group add gr-ProATN pr-IP1 pr-IP2 pr-ll_stack
fi
fi

E pcs cluster unstandby --all
sleep 4

# For logging purposes
E pcs constraint show --full
E pcs status --full
