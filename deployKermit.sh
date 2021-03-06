#!/bin/bash -e

_exec_cmd(){
  exec_string="$1"
  echo ""
  echo "Executing command: $exec_string"
  echo "-------------------------------------"
  ssh -A $BASTION_USER@$BASTION_IP ssh $ONEBOX_USER@$ONEBOX_IP "$exec_string"
  echo "-------------------------------------"
  echo "Successfully executed command: $exec_string"
  echo ""
}

set_context() {
  echo "CURR_JOB=$JOB_NAME"
  echo "DEPLOY_VERSION=$DEPLOY_VERSION"
  echo "BASTION_USER=$BASTION_USER"
  echo "BASTION_IP=$BASTION_IP"
  echo "ONEBOX_USER=$ONEBOX_USER"
  echo "ONEBOX_IP=$ONEBOX_IP"
}

configure_ssh_creds() {
  echo "Extracting AWS PEM"
  echo "-----------------------------------"
  pushd $(shipctl get_resource_meta "$RES_PEM")
  if [ ! -f "integration.json" ]; then
    echo "No credentials file found at location: $RES_PEM"
    return 1
  fi

  cat integration.json | jq -r '.key' > key.pem
  chmod 600 key.pem

  echo "Completed Extracting AWS PEM"
  echo "-----------------------------------"

  ssh-add key.pem
  echo "SSH key added successfully"
  echo "--------------------------------------"

  echo "SSH key file list"
  ssh-add -L

  _exec_cmd "ip addr"

  popd
}

pull_installer_repo() {
  _exec_cmd "git -C /home/centos/installer pull origin master"
}

pull_images() {
  echo "Pulling images to deploy for $DEPLOY_VERSION to OneBox"

  _exec_cmd "sudo docker pull $INSTALLER_IMG:$DEPLOY_VERSION"
  _exec_cmd "sudo docker pull $KWWW_IMG:$DEPLOY_VERSION"
  _exec_cmd "sudo docker pull $KAPI_IMG:$DEPLOY_VERSION"
  _exec_cmd "sudo docker pull $KMICRO_IMG:$DEPLOY_VERSION"
  _exec_cmd "sudo docker pull $KSCRIPTSBASE_IMG:$DEPLOY_VERSION"

}

update_creds(){
  echo "Updating registry credentials to automatically pull images"
  local docker_config="/root/.docker/config.json"
  _exec_cmd "sudo cp -vr $docker_config /opt/jfrog/shippable/etc/registry_creds.json || true"
}

deploy() {
  echo "Deploying the release $DEPLOY_VERSION to OneBox"
  echo "--------------------------------------"

  _exec_cmd "sudo /home/centos/installer/pipelines upgrade"

  echo "--------------------------------------"
  echo "Successfully deployed release $DEPLOY_VERSION to Onebox env"
}

create_version() {
  echo "Creating a state file for" $CURR_JOB
  # create a state file so that next job can pick it up
  echo "versionName=$DEPLOY_VERSION" > "$JOB_STATE/$CURR_JOB.env" #adding version state
  echo "Completed creating a state file for" $CURR_JOB
}

main() {
  eval $(ssh-agent -s)
  set_context
  configure_ssh_creds
  pull_installer_repo
  pull_images
  update_creds
  deploy
#  create_version
}

main
