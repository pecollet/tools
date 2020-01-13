# tools

-log parsing

-cluster control
  Local deployment, start/stop, edit config
  Ansible playbooks for AWS : starts a number of EC2 VMs, installs and starts a Neo4j cluster on them.
    - pre-reqs : 
        ansible installed locally
        export AWS_ACCESS_KEY_ID=<your key>
        export AWS_SECRET_ACCESS_KEY=<your key secret>
    - set parameters in variables.yml
        standard EC2 VM params
        ec2_cluster_id : used to identify VMs in cluster, so make that unique (so they can be found when inventory-ing them, terminating them)
        Software versions : make sure java verison is compatible with neo version
    - run 'deploy.sh' to start the Neo4j cluster
    - 'ansible-playbook ec2_stop_playbook.yml' to remove it
