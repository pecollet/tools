#!/bin/bash
usage() {
  echo "Usage: $0 key (value)"
  echo "Examples: $0 dbms.logs.query.enabled"
  echo "          $0 dbms.logs.query.threshold 0"
  echo "          $0 apoc.import.file.enabled"
}
if [ -z "$1" ] ; then
  usage
else
  key=${1}
  [ -z "$2" ] && value='true' || value=$2
  echo ${key}"="${value} >> instance1/neo4j-enterprise-3.5.12/conf/neo4j.conf
  echo "Added ${key}=${value} to instance1"
  echo ${key}"="${value} >> instance2/neo4j-enterprise-3.5.12/conf/neo4j.conf
  echo "Added ${key}=${value} to instance2"
  echo ${key}"="${value} >> instance3/neo4j-enterprise-3.5.12/conf/neo4j.conf
  echo "Added ${key}=${value} to instance3"
fi
echo 'restart cluster to take changes into account'
