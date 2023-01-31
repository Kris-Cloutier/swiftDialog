#!/bin/sh

# Get uplink network bandwidth results

result=$(awk 'NR==2 { print; exit }' /tmp/networkresults.txt)

echo "<result>$result</result>"