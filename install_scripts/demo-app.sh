#!/usr/bin/env bash

# shellcheck source=/dev/null
source "$HOME/.bash_profile"

shared_dir=$1
hyrax_demo_dir="/vagrant/hyrax-demo"
hyku_demo_dir="/vagrant/hyku-demo"

DEMO_TASK="
task :demo do
  with_server :development do
    IO.popen('rails server -b 0.0.0.0') do |io|
      begin
        io.each do |line|
          puts line
        end
      rescue Interrupt
        puts 'Stopping server'
      end
    end
  end
end"

DEFAULT_ADMIN_SET_TASK="
task :default_admin_set do
  with_server :development do
    Rake::Task['hyrax:default_admin_set:create'].invoke
    exit
  end
end
"

echo fs.inotify.max_user_watches=524288 | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# shellcheck source=/dev/null
source /opt/rh/rh-ruby24/enable
# shellcheck source=/dev/null
source /opt/rh/rh-nodejs8/enable
# shellcheck source=/dev/null
source /opt/rh/rh-redis32/enable

echo "Creating Hyrax demo in $hyrax_demo_dir"
# shellcheck disable=SC2164
cd "$shared_dir"
rails new hyrax-demo --skip-springs
# shellcheck disable=SC2164
cd "$hyrax_demo_dir"
echo "gem 'hyrax', github: 'samvera/hyrax'" >>Gemfile
bundle install --quiet --path vendor/bundle
bundle exec rails generate hyrax:install -f -q
bundle exec rails db:migrate
bundle exec rails hyrax:workflow:load
echo "$DEFAULT_ADMIN_SET_TASK" >>Rakefile
bundle exec rails default_admin_set
bundle exec rails generate hyrax:work Image -q
bundle exec rails generate hyrax:work Book -q
echo "$DEMO_TASK" >>Rakefile

echo "Creating Hyku demo in $hyku_demo_dir"
# shellcheck disable=SC2164
cd "$shared_dir"
git clone https://github.com/samvera-labs/hyku.git hyku-demo
# shellcheck disable=SC2164
cd "$hyku_demo_dir"
sed -i -e 's/enabled: false/enabled: true/' config/settings.yml
bundle install --quiet --path vendor/bundle
bundle exec rake db:create
bundle exec rake db:migrate
echo "$DEMO_TASK" >>Rakefile
