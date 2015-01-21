CUR_DIR_TMP="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$CUR_DIR_TMP/on-premise.sh"

#overrides and custom minerva100 functions


#minerva needs *real* user first
get_ssh_user() {

  #check if we can change from root user
  if [ "$requireRootFirst" ] ; then
    #"WARNINIG: connecting as root"
    echo "npoggi"
  else
    echo "$userAloja"
  fi
}

vm_initial_bootstrap() {

  local bootstrap_file="Initial_Bootstrap"

  if check_bootstraped "$bootstrap_file" ""; then
    logger "Bootstraping $vm_name "

    local home_prefix="/users/scratch"
    vm_execute "
sudo useradd --create-home --home $home_prefix/$userAloja -s /bin/bash $userAloja;
sudo echo -n '$userAloja:$passwordAloja' |sudo chpasswd;
sudo adduser $userAloja sudo;
sudo adduser $userAloja adm;

sudo bash -c \"echo '%sudo ALL=NOPASSWD:ALL' >> /etc/sudoers\";

sudo mkdir -p $home_prefix/$userAloja/.ssh;
sudo bash -c \"echo '${insecureKey}' >> sudo $home_prefix/$userAloja/.ssh/authorized_keys\";
sudo chown -R $userAloja: $home_prefix/$userAloja/.ssh;
sudo cp $home_prefix/$userAloja/.profile $home_prefix/$userAloja/.bashrc /root/;
"

    #allow sudo from our new user
    #vm_update_template "/etc/sudoers" "%sudo ALL=NOPASSWD:ALL" "secured_file"

    test_action="$(vm_execute " [ -f $home_prefix/$userAloja/.ssh/authorized_keys ] && echo '$testKey'")"

    if [ "$test_action" == "$testKey" ] ; then
      #set the lock
      check_bootstraped "$bootstrap_file" "set"
    else
      logger "ERROR at $bootstrap_file for $vm_name. Test output: $test_action"
    fi

  else
    logger "$bootstrap_file already configured"
  fi
}
