Content-Type: multipart/mixed; boundary="==BOUNDARY=="
MIME-Version: 1.0

--==BOUNDARY==
Content-Type: text/x-shellscript; charset="us-ascii"

#!/bin/bash
# Write the cluster configuration variable to the ecs.config file
# (add any other configuration variables here also)
cluster=pc-cluster-defenders
cat <<-'EOF' > /etc/ecs/ecs.config
        ECS_CLUSTER=pc-cluster-defenders
        ECS_INSTANCE_ATTRIBUTES={"purpose": "infra"}
EOF

yum install -y nfs-utils

START_TASK_SCRIPT_FILE="/etc/ecs/ecs-start-task.sh"
cat <<- 'EOF' > /etc/ecs/ecs-start-task.sh
	exec 2>>/var/log/ecs/ecs-start-task.log
	set -x
	
	# Install prerequisite tools
	yum install -y jq aws-cli
	
	# Wait for the ECS service to be responsive
	until curl -s http://localhost:51678/v1/metadata
	do
		sleep 1
	done

	# Grab the container instance ARN and AWS Region from instance metadata
	instance_arn=$(curl -s http://localhost:51678/v1/metadata | jq -r '. | .ContainerInstanceArn' | awk -F/ '{print $NF}' )
	cluster=$(curl -s http://localhost:51678/v1/metadata | jq -r '. | .Cluster' | awk -F/ '{print $NF}' )
	region=$(curl -s http://localhost:51678/v1/metadata | jq -r '. | .ContainerInstanceArn' | awk -F: '{print $4}')

	# Specify the task definition to run at launch
	task_definition=pc-console

	# Run the AWS CLI start-task command to start your task on this container instance
	aws ecs start-task --cluster $cluster --task-definition $task_definition --container-instances $instance_arn --started-by $instance_arn --region $region
EOF

# Write systemd unit file
UNIT="ecs-start-task.service"
cat <<- EOF > /etc/systemd/system/$UNIT
      [Unit]
      Description=ECS Start Task
      Requires=ecs.service
      After=ecs.service
 
      [Service]
      Restart=on-failure
      RestartSec=30
      ExecStart=/usr/bin/bash $START_TASK_SCRIPT_FILE

      [Install]
      WantedBy=default.target
EOF

# Enable our ecs.service dependent service with `--no-block` to prevent systemd deadlock
# See https://github.com/aws/amazon-ecs-agent/issues/1707
systemctl enable --now --no-block $UNIT
--==BOUNDARY==--