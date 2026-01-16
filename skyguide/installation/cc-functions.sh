#!/bin/bash
#
# Author: D. Schmutz, M. Rebmeister, Y. Gadi
# Date : 26.06.2020
# Description: The following script defines functions for moving and deleting log files
# Run Information: the functions are called from dedicated scripts
#
# History:
# - 11.12.2020: renaming function "purge" as "cc-delete"; renaming and updating function "archive-purge" as "cc-move"; new variable is used <SCRIPT_TRANSFERDIR>
# - 27.01.2021: new function cc-pushtoSFT-vdl2 dedicated to VDL2 transfer (files are renamed), timestamp function added
# - 04.08.2023: update all functions that use 'find' command to fix errors related to searching too many files or empty files
# - 07.08.2023: add new function to check the status of an IPSec connection by name and starts the one that has failed
# - 30.08.2023: remove all pushToSFT functions
#
###################################################
#
# Return the timestamp
#
function timestamp 
{
  date +'%Y-%m-%d %T' 
}
#
# Function that moves files after a certain period (in days)
# e.g.: cc-move "*.log" "/home/pi/vdl2" 20 "/home/pi/vdl2_transfer"
#
function cc-move
{
	pattern=$1
	logdir=$2
	logretention=$3
	logdir2=$4
	
	# Move files older than <logretention> days
  /usr/bin/find $logdir -type f -name "$pattern" -mtime +$logretention | xargs -r /bin/mv -t $logdir2;
 
}

#
# Function that moves files after a certain period (in minutes)
# e.g.: cc-move "*.log" "/home/pi/vdl2" 20 "/home/pi/vdl2_transfer"
#
function cc-move-min
{
	pattern=$1
	logdir=$2
	logretention=$3
	logdir2=$4
 
  # Move files older than <logretention> minutes
  /usr/bin/find $logdir -type f -name "$pattern" -mmin +$logretention | xargs -r /bin/mv -t $logdir2;

}

#
# Function that deletes files after a certain period (in days)
# e.g.: cc-delete "*.log" "/home/pi/vdl2_archive" 120
#
function cc-delete
{
	pattern=$1
	logdir=$2
	logretention=$3
	
	# Remove files older than <logretention> days
	/usr/bin/find $logdir -type f -name "$pattern" -mtime +$logretention | xargs -r /bin/rm;
  
}

#
# Function that appends the content of files into daily files and move them to another folder
# e.g.: cc-createDailyFiles "*_pdus.csv" "/usr/PDEC/livemonitoring/data" "/opt/data/xcpdlc_archive" "/opt/data/xcpdlc_daily"
# Assumption: the first 8 letters of found files is the date in format YYYYMMDD (e.g. 20230712_pdus.csv)
function cc-createDailyFiles
{
	pattern=$1
	sourcedir=$2
	destinationdir=$3
	creationdir=$4
  
	# Get files to be processed
	files=`/usr/bin/find "$sourcedir" -type f -name "$pattern" | /bin/grep '20[123][0-9][01][0-9]*' | /usr/bin/sort`
  
	# Move each file
	for f in $files
	do
    filename=$(basename "$f") # extract the filename from the sourcedir path
		date=${filename:0:8} # takes the 8 first letters of the filename
    echo "$(timestamp) Append $f to daily file: ${date}_pdus.csv"
		cat $f >> $creationdir/${date}_pdus.csv && mv $f $destinationdir
		echo "$f, $creationdir/${date}_pdus.csv"
	done
}

#
# Function to check the status of an IPSec connection by name
# e.g.: check_ipsec_status "connection_name1" "connection_name2" "connection_name3"
function cc-check_ipsec_status {

   for connection_name in "$@"; do 
        
        local status=$(swanctl --list-sas | grep "$connection_name" | grep -o "INSTALLED")

        if [[ -n "$status" ]]; then
            echo "$(timestamp) IPSec connection '$connection_name' is up."
        else
            echo "$(timestamp) IPSec connection '$connection_name' is down. Trying to reactivate..."

            # Reactivate the IPSec connection
            swanctl --initiate --child $connection_name

            # Wait for a few seconds to allow the connection to be reestablished
            sleep 10

            # Check the status again after reactivation
            status=$(swanctl --list-sas | grep "$connection_name" | grep -o "INSTALLED")
            if [[ -n "$status" ]]; then
              echo "$(timestamp) IPSec connection '$connection_name' has been reactivated and is up."
            else
              echo "$(timestamp) Failed to reactivate IPSec connection '$connection_name'."
            fi
        fi
    done
}