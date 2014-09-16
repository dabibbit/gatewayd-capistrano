require 'capistrano/node-deploy'
require 'capistrano/uptodate'

set :application, 'gatewayd'
set :scm, 'git'
set :repository, 'https://github.com/ripple/gatewayd.git'
set :branch, ENV['branch'] ? ENV['branch'] : 'develop'
set :deploy_to, "/var/apps/#{application}"
set :user, 'ubuntu' # deploy user
set :node_user, "#{application}" # run user
set :node_binary, '/usr/bin/node'
set :node_env, ENV['NODE_ENV'] ? ENV['NODE_ENV'] : 'staging'
set :app_command, 'bin/gateway'
#set :app_environment, '' # environment variables

# used in staging:configure_postgres task
set :postgres_username, 'gatewayd_user'
set :postgres_password, 'password'
set :postgres_dbname, 'gatewayd_db'

set :upstart_file_contents, <<EOD
#!upstart
description "#{application} node app"
author      "capistrano"

start on runlevel [2345]
stop on shutdown

respawn
respawn limit 99 5
kill timeout #{kill_timeout}

script
    cd #{current_path} && exec sudo -u #{node_user} NODE_ENV=#{node_env} #{app_environment} #{node_binary} #{current_path}/#{app_command} start 2>> #{stderr_log_path} 1>> #{stdout_log_path}
end script

pre-stop script
    cd #{current_path} && exec sudo -u #{node_user} NODE_ENV=#{node_env} #{app_environment} #{node_binary} #{current_path}/#{app_command} stop 2>> #{stderr_log_path} 1>> #{stdout_log_path}
end script

post-stop script
    # not nice workaround for './bin/gateway stop' not working
    sudo -u #{node_user} pkill pm2
end script
EOD

namespace :deploy do
  desc "Copy settings file to release dir"
  task :copy_config_to_release_path do
    run "if [ -f #{shared_path}/config/config.json ]; then cp -a #{shared_path}/config/config.json #{release_path}/config/; fi"
  end
end

namespace :setup do
  desc 'Create service user'
  task :create_user do
    run "sudo -u root useradd -U -m -r -s /dev/null #{application}"
  end

  desc 'Install dependencies (apt repositories and packages)'
  task :install_dependencies do
    run 'sudo apt-get -y update'
    run 'sudo apt-get -y install git python-software-properties python g++ make libpq-dev'
    run 'sudo add-apt-repository -y ppa:chris-lea/node.js'
    run 'sudo apt-get -y update'
    run 'sudo apt-get -y install nodejs postgresql postgresql-client'
    # nodejs package installs binary as /usr/bin/nodejs (?!) so we symlink it..
    run 'sudo ln -s /usr/bin/nodejs /usr/bin/node || true' # but silently fail if it's already there
  end

  desc 'Upload config file from env/deploy/config.json'
  task :upload_config do
    run_locally 'cp -n env/deploy/config.json.example env/deploy/config.json || true'
    run "mkdir -p #{shared_path}/config"
    upload 'env/deploy/config.json', "#{shared_path}/config/config.json"
  end

  desc 'Create deploy path'
  task :create_deploy_path do
    run "sudo mkdir -p #{deploy_to}"
    run "sudo chown #{user}:#{user} #{deploy_to}"
  end
end

namespace :staging do
  desc 'Setup a staging server from scratch'
  task :cold_setup do
    setup.create_user
    setup.create_deploy_path
    setup.install_dependencies
    setup.upload_config
    configure_postgres
    node.install_global_packages
  end

  desc 'Configure postgresql in a manner suitable for staging/testing'
  task :configure_postgres do
    run "sudo -u postgres psql -U postgres -c \"create user #{postgres_username} with password \'#{postgres_password}\'\""
    run "sudo -u postgres psql -U postgres -c \"create database #{postgres_dbname} with owner #{postgres_username} encoding=\'utf8\'\""
  end
end

namespace :node do
  desc 'Run migrations'
  task :migrate do
    # grunt migrations plugin seems to be ignoring the path to migrations dir, so symlink it to default location
    run "ln -s #{release_path}/lib/data/migrations #{release_path}/migrations"
    run "cd #{release_path} && grunt migrate:up --env=#{node_env}"
  end

  desc 'Install globally required NPM packages'
  task :install_global_packages do
    run 'sudo npm install --global pg pm2 grunt grunt-cli forever db-migrate'
    run "sudo chown -R #{user}:#{user} ~#{user}/tmp ~#{user}/.npm" # fix permissions
  end
end

after 'node:install_packages', 'deploy:copy_config_to_release_path'

