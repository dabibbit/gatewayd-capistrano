# config valid only for Capistrano 3.1
lock '3.2.1'

set :application, 'gatewayd'
set :repo_url, 'https://github.com/ripple/gatewayd.git'

# Default branch is :master
ask :branch, proc { `git rev-parse --abbrev-ref HEAD`.chomp }.call

# Default deploy_to directory is /var/www/my_app
set :deploy_to, '/opt/gatewayd'

# Default value for :scm is :git
# set :scm, :git

# Default value for :format is :pretty
# set :format, :pretty

# Default value for :log_level is :debug
# set :log_level, :debug

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
set :linked_files, %w{config/config.json}

# Default value for linked_dirs is []
# set :linked_dirs, %w{bin log tmp/pids tmp/cache tmp/sockets vendor/bundle public/system}

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for keep_releases is 5
# set :keep_releases, 5

namespace :gatewayd do
  desc 'Start application'
  task :start do
    on roles(:app), in: :sequence, wait: 5 do
      within release_path do
        execute 'bin/gateway', 'start'
      end
    end
  end
  desc 'Reload application'
  task :reload do
    on roles(:app), in: :sequence, wait: 5 do
      execute :pm2, 'reload all'
    end
  end
  desc 'Stop application'
  task :stop do
    on roles(:app), in: :sequence, wait: 5 do
      execute :pm2, 'kill'
    end
  end
end

namespace :setup do
  desc "Check that we can access everything"
  task :check_write_permissions do
    on roles(:all) do |host|
      if test("[ -w #{fetch(:deploy_to)} ]")
        info "#{fetch(:deploy_to)} is writable on #{host}"
      else
        error "#{fetch(:deploy_to)} is not writable on #{host}"
      end
    end
  end
  desc "Create deploy directory"
  task :setup_deploy_directory do
    on roles(:app) do
      sudo :mkdir, "-p #{fetch(:deploy_to)}"
      sudo :mkdir, "-p /tmp/gatewayd"
      sudo :chown, "-R ubuntu #{fetch(:deploy_to)}"
      sudo :chown, "-R ubuntu /tmp/gatewayd"
    end
  end
end

namespace :deploy do
  desc "install new node package dependencies"
  task :npm_install do
    on roles(:app) do
      within release_path do
        execute :npm, :install
      end
    end
  end
  after :publishing, :npm_install
  after :npm_install, :clear_cache do
    on roles(:web), in: :groups, limit: 3, wait: 10 do
      execute :pm2, 'reload all'
    end
  end
end

