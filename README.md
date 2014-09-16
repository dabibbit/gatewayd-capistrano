# Capistrano Deploy Instructions #

`gatewayd` can be deployed with capistrano. It has been tested with ubuntu 13.10.

### Install capistrano and dependencies
Assuming you have ruby and bundler installed, from the `gatewayd` root, run:
```bash
bundle install
```

### Set up deploy user
You need a user with sudo access to deploy. The script is configured to use the `ubuntu` user, you can change the :user setting in capistrano if you want a different user. You should copy your ssh key to this user's authorized_keys file.

### Add a service user
An unprivileged user should be created to securely run the server, you can use this cap task to add it:
```bash
bundle exec cap HOSTS=<ip or hostnames of target server> deploy:create_user
```

### Put the configuration in place
SSH to the server and create the configuration file, or copy the `env/deploy/config.json.example` file to `env/deploy/config.json`, make your changes and run the `setup:upload_config` task.

Here's an example config that may be suitable for a staging environment where security is not important. NODE_ENV is omitted because capistrano sets it as an environment variable.
```bash
mkdir -p /var/apps/gatewayd/shared/config
cat <<END > /var/apps/gatewayd/shared/config/config.json
{
  "DATABASE_URL": "postgres://gatewayd_user:password@localhost:5432/gatewayd_db",
  "SSL": false
}
END
```
On each deploy, this configuration file will be copied to the release path.

### Deploy
Set the `HOSTS` environment variable to the target server and run:
```bash
bundle exec cap HOSTS=<ip or hostname of target server> deploy
```

You can deploy any branch by setting the `branch` environment variable
```bash
bundle exec cap HOSTS=<ip or hostname of target server> branch=mycoolfeature deploy
```

Capistrano also allows you to set (override) variables
```bash
bundle exec cap HOSTS=<ip or hostname of target server> --set repository='https://github.com/foo/gatewayd.git' deploy
```

#### Create deploy path
```bash
bundle exec cap HOSTS=<ip or hostname of target server> setup:create_deploy_path
```

#### Install prerequisite packages
This task will install the needed ubuntu packages: nodejs, postgresql, and development tools for building npm modules.
```bash
bundle exec cap HOSTS=<ip or hostname of target server> setup:install_dependencies
```

#### Install global npm packages
Some NPMs need to be installed --global
```bash
bundle exec cap HOSTS=<ip or hostname of target server> node:install_global_packages
```

#### Quickly provision a staging server
You can use this task to quickly deploy a server suitable for staging/testing. It will call the other tasks to create the service user, create the deploy path, install dependencies, upload the config file and create a database, etc.
```bash
bundle exec cap HOSTS=<ip or hostname of target server> staging:cold_setup
bundle exec cap HOSTS=<ip or hostname of target server> deploy
```

### Notes
At this time, the "bin/gateway stop" task is not functioning, so a temporary workaround was added that uses pkill to stop any 'pm2' processes. This should be removed when the stop task is fixed.

