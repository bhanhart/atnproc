#
# (C) Copyright Airtel ATN 2022
# 
# Unpublished - All rights reserved under the copyright laws of the
# European Union.
# 
# This software is furnished under a license and use, duplication,
# disclosure and all other uses are restricted to the rights
# specified in the written license between the licensee and Airtel ATN.
#
#

# $Name$

#
# File: rtcd_routerlog.awk
#
#
# Author: 
#
# Description: Convert tcpdump output into Airtel router log format
#
# Examples of tcpdump output format:
# 2022-02-21 00:00:06.250756 00:10:db:ff:60:09 > 40:a8:f0:2f:59:e6, ethertype IPv4 (0x0800), length 151: 57.77.136.120 > 10.94.31.22:  ip-proto-80 117
#	0x0000:  4548 0089 bdf4 0000 3450 dcaf 394d 8878
#	0x0010:  0a5e 1f16 814e 0126 9c00 7540 cb14 4700
#	0x0020:  2781 8343 5a00 0141 4101 0100 0045 5330
#	0x0030:  3101 1447 0027 4157 5a5a 0047 1f8b 0000
#	0x0040:  5341 4142 0000 0103 7c00 0000 75cd 010b
#	0x0050:  c301 d6c5 0dc0 0606 042b 1b00 0004 010f
#	0x0060:  0101 0a62 19c8 0308 0484 6d50 df0a f019
#	0x0070:  c882 0804 c650 8735 00a7 264f 3083 3434
#	0x0080:  0002 4190 8328 a515 cc
# 2023-02-01 13:54:01.295389 00:10:18:b4:e0:7c > 00:1c:7f:3c:ec:6b, ethertype 802.1Q (0x8100), length 127: vlan 3984, p 0, ethertype IPv4, 156.135.249.28 > 57.77.136.120:  ip-proto-80 89
#	0x0000:  4500 006d 4c1e 0000 4050 d6b9 9c87 f91c
#	0x0010:  394d 8878 814e 0163 9c00 5900 0014 4700
#	0x0020:  2741 5357 5200 4b17 fe00 0100 0000 0000
#	0x0030:  0101 1447 0027 8183 4348 0001 5353 0101
#	0x0040:  4553 4745 3031 016f db00 0000 59cd 010b
#	0x0050:  c50d c006 0604 2b1b 0000 0401 0f01 01c3
#	0x0060:  01c0 0a6a 6048 0708 0455 6b27 7e
#

BEGIN {
    logline         = ""; # Is used to build up the output CLNS_DT_PDU
                          # line
    dataLength      = 0;  # the length of the data as indicated by the
                          # tcpdump header
    processedLength = 0;  # Records the amount of data processed so
                          # far so that when it is equal to dataLength
                          # all the data has been processed
    # Split RTCD_SNIFFED_ADDRESS (comma separated) into IPS array
    n_ips = split(RTCD_SNIFFED_ADDRESS, IPS, /[[:space:]]*,[[:space:]]*/);
}

function print_logline () {
    # Remove Internet Protocol PDU info to keep only the data, ie
    # CLNP PDU which starts with 81 and prepend with a circuit name
    # corresponding to the remote IP address Internet Protocol PDU
    # starts with 45 and is 20 octets long in total
    # Before:
    #   2018-07-13 07:41:33.027 RCVD 90 4540006ef42f000028509fc97f0000047f000003814e01259c005a000014470027c18365750041463700010000414130310114470027814350560000000000001234567890110100630000005ac301d6c50dc00606042b1b000004010f0101cd01080bc0003300330804f9701c4e
    # After:
    #   2018-07-13 07:41:33.027 RCVD 90 <REMOTE_IP_ADDRESS> 814e01259c005a000014470027c18365750041463700010000414130310114470027814350560000000000001234567890110100630000005ac301d6c50dc00606042b1b000004010f0101cd01080bc0003300330804f9701c4e
    sub(/ 45[0-9a-f]{38}81/, " dummycir 81", logline);
    # Replace dummycir by the remote ip address
    sub(/dummycir/,ip_address, logline);
    # Prepend "ROUTER CLNS_DT_PDU " to each line
    printf "ROUTER CLNS_DT_PDU %s\n", logline ;
    fflush()
}

NF >= 15 && /^[0-9]{4}-[0-9]{2}-[0-9]{2}/ {  # this is a tcpdump header line
    # Valid entry is expected to contain a minimum of 15 fields and
    # start with a timestamp in the format YYYY-MM-DD

    # Reset processed length
    processedLength = 0 ;

    # Check the sending address to set SENT or RCVD string. Strip all
    # text apart from date and data length
    # Before:
    #   2019-08-22 14:08:13.136048 00:00:00:00:00:00 > 00:00:00:00:00:00, ethertype IPv4 (0x0800), length 124: 127.0.0.4 > 127.0.0.3:  iso-ip 90
    # After:
    #   2019-08-22 14:08:13.136 RCVD 90
    sent = -1
    ip_address = ""
    for (i = 1; i <= n_ips; i++)
    {
        pos = index($0, IPS[i] " >")
        if (pos > 0)
        {
            # Found "src >" - extract destination IP (next field after >)
            # Skip "src > " part
            ip_address = substr($0, pos + length(IPS[i]) + 3)
            # Remove everything starting from nearest colon or space
            sub(/[: ].*/, "", ip_address)
            sent = 1
            break
        }
        pos = index($0, "> " IPS[i])
        if (pos > 0)
        {
            # Found "> dst" - extract source IP (last field before >)
            # Get prefix before " > dst"
            prefix = substr($0, 1, pos - 1)
            # Extract last whitespace-separated field
            n = split(prefix, a, " ")
            ip_address = a[n]
            sent = 0
            break
        }
    }

    if (sent == 1)
    {
        if (match($0, "iso-ip"))
        {
            gsub(/[0-9]{3} [0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}.+iso-ip/, " SENT")
        }
        else
        {
            gsub(/[0-9]{3} [0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}.+ip-proto-80/, " SENT")
        }
    }
    else
    {
        if (match($0, "iso-ip"))
        {
            gsub(/[0-9]{3} [0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}.+iso-ip/, " RCVD")
        }
        else
        {
            gsub(/[0-9]{3} [0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}.+ip-proto-80/, " RCVD")
        }
    }
    # Store the data length, adding the 20 bytes header
    dataLength = $NF + 20 ;

    # Store the line into the logline data
    # Append a space to seperate from the data
    logline = $0 " ";
    next;
}

NF > 1 && /^[[:space:]]+0x/ { # This is a tcpdump packet line
    # Merge the data into a single line and remove the data address
    # 0x....
    
    # remove the data address
    sub(/^.0x[0-9a-z]+:/, "");
    # remove all spaces
    gsub(" ", "");
    # store processed length so far
    processedLength = processedLength + length() / 2 ;
    # Append the data to the logline 
    logline = logline $0

    # Print buffer if we've processed the tcpdump entry fully
        if (processedLength == dataLength)
        {
                print_logline();
                # Reset variables
                logline         = "";
                dataLength      = 0;
                processedLength = 0;
        }
    next;
}
