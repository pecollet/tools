 #!/bin/bash


intro_banner()
{
cat << EOF
This script will download a given Neo4j enterprise .tgz file and then configure a N instance local cluster whether HA or Causal Cluster
or a single instance when no cluster type has been provided on the command line.

The script can be generally run from any path and will create N subdirectories to represent each of the instance and they will be named
instance1, instance2..instanceN. Each subdir will then have the \$NEO4J_HOME unpacked and its correspong \$NEO4J_HOME\\conf\\neo4j.conf
will be appropriately configured.

For cluster setup and regarding port configurations, for client ports, i.e. browser (HTTP/HTTPS) and Bolt the ports have been changed from their default
values and the 3rd number now represents the instance number. For example the default :7474 on instance1 will be changed to :7414.
In the same fashion the default bolt port of :7687 on instance1 will be changed to :7617. The same is done for instance2 and
instace3, i.e. instance2 :7474 goes to :7424 and Bolt port :7687 goes to :7627.

Regarding cluster communication ports
For HA, ports are typcially at 500x and 600x and x is replaced by the instance number
For CC, ports are typcially at 500x, 600x and 700x and x is replaced by the instance number

Usage: $0 <version> <type> <size>

where <version> is of the format 3.1.2
<type> is either value HA (to represent a High Availability)
CC (to represetn a Causal Cluster)
null (to represent a single instance)
<size> optional (default = 3) defines number of instances to create, valid size are between 3 and 9
EOF
}

exit_banner () {
echo "To start the cluster, run:"
echo "./$script_name start"
#start=1
#for i in $(eval echo "{$start..$size}")
#do
#echo "instance$i/neo4j-enterprise-$neo_version/bin/neo4j start"
#done
}


download () {
curl -O http://dist.neo4j.org/neo4j-enterprise-$1-unix.tar.gz
}

untar () {
echo $version
echo "Untarring .tar.gz into respective instance subdirectories"
start=1
for i in $(eval echo "{$start..$size}")
do
tar xf neo4j-enterprise-$neo_version-unix.tar.gz -C ./instance$i
done
}


configure_common () {
echo "Configuring common parameters $size"
start=1
for i in $(eval echo "{$start..$size}")
do
# disable authentication
sed -i '' -e "s/#dbms.security.auth_enabled=false/dbms.security.auth_enabled=false/g" ./instance$i/neo4j-enterprise-$neo_version/conf/neo4j.conf

# enable remote connections via the browser
sed -i '' -e "s/#dbms.connectors.default_listen_address=0.0.0.0/dbms.connectors.default_listen_address=0.0.0.0/g" ./instance$i/neo4j-enterprise-$neo_version/conf/neo4j.conf
#4.0 renaming
sed -i '' -e "s/#dbms.default_listen_address=0.0.0.0/dbms.default_listen_address=0.0.0.0/g" ./instance$i/neo4j-enterprise-$neo_version/conf/neo4j.conf


if [ "$size" -gt 1 ]; then
# only enter if we are configuring a cluster. for single instance no need to reconfigure these

# dbms.backup.address=0.0.0.0:6362
src="#dbms.backup.address=0.0.0.0:6362"
replace="dbms.backup.address=0.0.0.0:63${i}2"
sed -i '' -e "s/$src/$replace/g" ./instance$i/neo4j-enterprise-$neo_version/conf/neo4j.conf

#4.0 renaming of the property
src="#dbms.backup.listen_address=0.0.0.0:6362"
replace="dbms.backup.listen_address=0.0.0.0:63${i}2"
sed -i '' -e "s/$src/$replace/g" ./instance$i/neo4j-enterprise-$neo_version/conf/neo4j.conf

#bolt connector #dbms.connector.bolt.listen_address=:7687
src="#dbms.connector.bolt.listen_address=:7687"
replace="dbms.connector.bolt.listen_address=:76${i}7"
sed -i '' -e "s/$src/$replace/g" ./instance$i/neo4j-enterprise-$neo_version/conf/neo4j.conf


#http connector #dbms.connector.http.listen_address=:7474
src="#dbms.connector.http.listen_address=:7474"
replace="dbms.connector.http.listen_address=:74${i}4"
sed -i '' -e "s/$src/$replace/g" ./instance$i/neo4j-enterprise-$neo_version/conf/neo4j.conf

#https connector #dbms.connector.https.listen_address=:7473
src="#dbms.connector.https.listen_address=:7473"
replace="dbms.connector.https.listen_address=:74${i}3"
sed -i '' -e "s/$src/$replace/g" ./instance$i/neo4j-enterprise-$neo_version/conf/neo4j.conf
fi
done
}

configure_ha () {
echo "Configuring for a HA (High Avaialability) cluster."
start=1
for i in $(eval echo "{$start..$size}")
do
#dbms.mode
src="#dbms.mode=HA"
replace="dbms.mode=HA"
sed -i '' -e "s/$src/$replace/g" ./instance$i/neo4j-enterprise-$neo_version/conf/neo4j.conf

# use double quotes in sed cmd, single quotes will not expand the varaible $i
# set ha.server_id
sed -i '' -e "s/#ha.server_id=/ha.server_id=$i/g" ./instance$i/neo4j-enterprise-$neo_version/conf/neo4j.conf

#intiial hosts are defined at :5001, :5002, :5003 out of the box
src="#ha.initial_hosts=127.0.0.1:5001,127.0.0.1:5002,127.0.0.1:5003"
replace="ha.initial_hosts=127.0.0.1:5001,127.0.0.1:5002,127.0.0.1:5003"
sed -i '' -e "s/$src/$replace/g" ./instance$i/neo4j-enterprise-$neo_version/conf/neo4j.conf

src="#ha.host.coordination=127.0.0.1:5001"
replace="ha.host.coordination=127.0.0.1:500${i}"
sed -i '' -e "s/$src/$replace/g" ./instance$i/neo4j-enterprise-$neo_version/conf/neo4j.conf


src="#ha.host.data=127.0.0.1:6001"
replace="ha.host.data=127.0.0.1:600${i}"
sed -i '' -e "s/$src/$replace/g" ./instance$i/neo4j-enterprise-$neo_version/conf/neo4j.conf


done
}


configure_cc () {
echo "Configuring for a Causal Cluster"
start=1
cc_discovery_members=""
for i in $(eval echo "{$start..$size}")
do
  cc_discovery_members="${cc_discovery_members},localhost:500${i}"
done
cc_discovery_members=${cc_discovery_members:1}
echo "CC discovery members: ${cc_discovery_members}"
for i in $(eval echo "{$start..$size}")
do
#dbms.mode
src="#dbms.mode=CORE"
replace="dbms.mode=CORE"
sed -i '' -e "s/$src/$replace/g" ./instance$i/neo4j-enterprise-$neo_version/conf/neo4j.conf

src="#causal_clustering.expected_core_cluster_size=3"
replace="causal_clustering.expected_core_cluster_size=3"
sed -i '' -e "s/$src/$replace/g" ./instance$i/neo4j-enterprise-$neo_version/conf/neo4j.conf

src="#causal_clustering.initial_discovery_members=localhost:5000,localhost:5001,localhost:5002"
replace="causal_clustering.initial_discovery_members=${cc_discovery_members}"
sed -i '' -e "s/$src/$replace/g" ./instance$i/neo4j-enterprise-$neo_version/conf/neo4j.conf

src="#causal_clustering.discovery_listen_address=:5000"
replace="causal_clustering.discovery_listen_address=:500${i}"
sed -i '' -e "s/$src/$replace/g" ./instance$i/neo4j-enterprise-$neo_version/conf/neo4j.conf

src="#causal_clustering.transaction_listen_address=:6000"
replace="causal_clustering.transaction_listen_address=:600${i}"
sed -i '' -e "s/$src/$replace/g" ./instance$i/neo4j-enterprise-$neo_version/conf/neo4j.conf

src="#causal_clustering.raft_listen_address=:7000"
replace="causal_clustering.raft_listen_address=:700${i}"
sed -i '' -e "s/$src/$replace/g" ./instance$i/neo4j-enterprise-$neo_version/conf/neo4j.conf

src="#causal_clustering.raft_advertised_address=:7000"
replace="causal_clustering.raft_advertised_address=:700${i}"
sed -i '' -e "s/$src/$replace/g" ./instance$i/neo4j-enterprise-$neo_version/conf/neo4j.conf

src="#causal_clustering.transaction_advertised_address=:6000"
replace="causal_clustering.transaction_advertised_address=:600${i}"
sed -i '' -e "s/$src/$replace/g" ./instance$i/neo4j-enterprise-$neo_version/conf/neo4j.conf
done

}

mkdirs() {
echo "Creating $size subdirectories named ./instance1 ..... ./instance$size"
start=1
for i in $(eval echo "{$start..$size}")
do
mkdir ./instance$i
done
}

createStartScript() {
  script_name="startStopCluster-${neo_version}.sh"
  echo "#!/bin/bash" > $script_name
  echo "usage() {" >> $script_name
  echo "  echo \"Usage: \$0 start|stop\"" >> $script_name
  echo "}" >> $script_name
  echo "if [ -z \"\$1\" ] ; then">> $script_name
  echo "  usage" >> $script_name
  echo "else" >> $script_name

  start=1
  for i in $(eval echo "{$start..$size}")
  do
    echo "instance$i/neo4j-enterprise-$neo_version/bin/neo4j \$1" >> $script_name
    echo "echo '#######################################################################################################'" >> $script_name
  done
  echo "fi" >> $script_name
  chmod +x $script_name
}
createConfScript() {
  conf_script_name="addClusterConfig-${neo_version}.sh"
  echo "#!/bin/bash" > $conf_script_name
  echo "usage() {" >> $conf_script_name
  echo "  echo \"Usage: \$0 key (value)\"" >> $conf_script_name
  echo "  echo \"Examples: \$0 dbms.logs.query.enabled\"" >> $conf_script_name
  echo "  echo \"          \$0 dbms.logs.query.threshold 0\"" >> $conf_script_name
  echo "  echo \"          \$0 apoc.import.file.enabled\"" >> $conf_script_name
  echo "}" >> $conf_script_name
  echo "if [ -z \"\$1\" ] ; then">> $conf_script_name
  echo "  usage" >> $conf_script_name
  echo "else" >> $conf_script_name
  echo "  key=\${1}" >> $conf_script_name
  echo "  [ -z \"\$2\" ] && value='true' || value=\$2" >> $conf_script_name
  start=1
  for i in $(eval echo "{$start..$size}")
  do
    echo "  echo \${key}\"=\"\${value} >> instance$i/neo4j-enterprise-$neo_version/conf/neo4j.conf" >> $conf_script_name
    echo "  echo \"Added \${key}=\${value} to instance$i\"" >> $conf_script_name
  done
  echo "fi" >> $conf_script_name
  echo "echo 'restart cluster to take changes into account'" >> $conf_script_name
  chmod +x $conf_script_name
}

main () {
neo_version=$1
cluster_type=$2
if [ -z "$cluster_type" ]
then
# no cluster type was specified, lets do a simple download and untar, no config
echo "Downloading and installing for single Instance"
size=1
mkdirs $size
download $neo_version
untar $neo_version $size
configure_common $neo_version
else
size=$3
intro_banner
# download $neo_version
# passing cluster size on cmd line is optional. if not passed we will default to 3
if [[ -z $size ]]; then
size=3;
fi
mkdirs $size
download $neo_version
untar $neo_version $size
configure_common $neo_version
if [ $cluster_type = 'HA' ]; then
configure_ha $neo_version
else
configure_cc $neo_version
fi
createStartScript $neo_version
createConfScript $neo_version
fi
exit_banner $neo_version

}

main $1 $2 $3
