# tools

## Metrics plotting
### gnuplot configs
 * requires gnuplot
 * use `neo.metrics.gnuplot_qt` to display plot in a new window, `neo.metrics.gnuplot_svg` to write output to a svg file
 * usage (plot a single file) : 
  `gnuplot -p -c neo.metrics.gnuplot_[qt|svg] <csv> [<colNum>] [rangeStart rangeEnd]`
 * usage (plot several files) :  `gnuplot -p -c neo.metrics.gnuplot_[qt|svg] "<csv1> <csv2> ..." [<colNum>] [rangeStart rangeEnd]`
 * range : expressed with epoch values in seconds (defaults to plotting the whole data in the file(s))
 * colNum : selects with column to plot (defaults to 2nd column)
### wrapper script
 * usage : `plot_metrics.sh <metrics_directory> [rangeStart rangeEnd]`
 * plots all the metrics in the directory, including the rotated files (grouped in 1 same chart per metric)
 * range : expressed with epoch values in seconds (defaults to plotting the whole data in the file(s))
 * outputs svg files for each metric (<metric_file>.svg) and a html report (metrics_<start>_<end>.html) that gathers all those images (in <metrics_directory>)
 * Notes : only plots column 2 ; if run several times, svg files are overwritten
## Cluster control
### AWS CloudFormation templates OUTDATED (those were just for a quick fix)
  * 4.0 Template with fixes to RR networking
    * official template fails to assign correct IP addresses to RR
  * 4.1 Template with server-side routing and load-balancer
    * sets up server-side routing
    * configures all Neo4j instances to advertise the LB hostname for bolt and http endpoints
    * creates a load balancer that listens on BOLT & HTTP ports ; currently only targets 3 cores
    * Note : 4.1 drivers must be used for server-side routing to work. In 4.1.0 the driver shipped with Neo4j Browser is 4.0.11. 
### Ansible playbooks for AWS (OUTDATED)
starts a number of EC2 VMs, installs and starts a Neo4j cluster on them.
  * pre-reqs : 
    * ansible installed locally
    * export AWS_ACCESS_KEY_ID=<your key>
    * export AWS_SECRET_ACCESS_KEY=<your key secret>
  * set parameters in variables.yml
    * standard EC2 VM params
    * ec2_cluster_id : used to identify VMs in cluster, so make that unique (so they can be found when inventory-ing them, terminating them)
    * Software versions : make sure java verison is compatible with neo version
  * run `deploy.sh` to start the Neo4j cluster
  * `ansible-playbook ec2_stop_playbook.yml` to remove it
