# Capistrano Deploy Instructions

`gatewayd` can be deployed with capistrano. It has been tested with ubuntu 13.10.

### Install capistrano and dependencies
Assuming you have ruby and bundler installed run

    bundle install

### Set up deploy user
You need a user with sudo access to deploy, and remove its password so that
only ssh keys can be used to login the user.

    root@remote $ adduser deploy
    root@remote $ passwd -l deploy

### Prepare the deploy directory
You need to enable the `deploy` user to have permission to write to the directory
to which capistrano will deploy

    root@remote mkdir /opt/gatewayd
    root@remote mkdir /opt/tmp
    root@remote chown -R deploy /opt/gatewayd
    root@remote chown -R deploy /opt/tmp

### Deploy
Set your host 

    HOST=123.34.35.1 cap staging deploy

