require 'capistrano_colors'
require "rvm/capistrano"

set :application, "copycopter"

set :branch, "master"
set :deploy_to, "/home/dev/apps/#{application}"

$host = 'infr.coub.com'
$rvm_string = 'ruby-1.9.3-p194-perf@copycopter'
$app_services = %w(copycopter)

set :repository,  "git://github.com/over/copycopter-server.git"

set :rvm_ruby_string, $rvm_string
set :rvm_type, :system

set :scm, :git
set :deploy_via, :remote_cache

set :keep_releases, 5
set :use_sudo, false
set :rails_env, 'production'
set :user, 'dev'

role :app, $host
role :web, $host
role :db,  $host, :primary => true

namespace :deploy do
  desc "Restart application"
  task :restart, :roles => :app do
    run "sudo sv -w 30 restart copycopter"
  end

  desc 'Compile assets'
  task :compile_assets, :roles => :app do
    #from = source.next_revision(current_revision)
    #if capture("cd #{latest_release} && #{source.local.log(from)} vendor/assets/ app/assets/ | wc -l").to_i > 0
    run %Q{cd #{latest_release} && rm -rf public/assets/* && #{rake} RAILS_ENV=#{rails_env} assets:precompile}
    #else
      #logger.info "Skipping asset pre-compilation because there were no asset changes"
    #end
  end

  desc "Bundle gems"
  task :bundle, :roles => :app do
    run "cd #{release_path}; bundle install;"
  end

  desc 'Migrate database'
  task :migrate, :roles => :app do
    run "cd #{release_path}; bundle exec rake db:migrate RAILS_ENV=production;"
  end

  desc 'link folders'
  task :link_folders, :roles => [:app, :bg, :cnv] do
    public_folders = File.readlines(File.join(File.dirname(__FILE__), '..', '.gitignore')).map{ |s| s.strip }.grep(/^public\/.+/)
    public_folders += ["db/sphinx"]
    public_folders.each do |share|
      from = "#{shared_path}/#{share}"
      to = "#{release_path}/#{share}"
      run ["mkdir -p #{from}", "ln -nfs #{from} #{to}"].join('; ')
    end

    run "ln -nfs #{shared_path}/config/database.yml #{release_path}/config/database.yml"
    run "echo 'rvm #{$rvm_string}' > #{release_path}/.rvmrc"
  end
end

after "deploy:update_code", 'deploy:link_folders'
after "deploy:link_folders", "deploy:bundle"
after "deploy:link_folders", "deploy:compile_assets"
after "deploy:link_folders", "deploy:migrate"

# after "deploy:restart", "deploy:cleanup"

# if you're still using the script/reaper helper you will need
# these http://github.com/rails/irs_process_scripts

# If you are using Passenger mod_rails uncomment this:
# namespace :deploy do
#   task :start do ; end
#   task :stop do ; end
#   task :restart, :roles => :app, :except => { :no_release => true } do
#     run "#{try_sudo} touch #{File.join(current_path,'tmp','restart.txt')}"
#   end
# end

