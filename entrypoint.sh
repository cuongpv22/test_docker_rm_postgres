#!/bin/bash

#####################################################################
# redmine

cd /var/lib/redmine
bundle install --without development test
bundle exec rake db:migrate RAILS_ENV=production 
bundle exec rake redmine:plugins:migrate RAILS_ENV=production
bundle exec rake redmine:load_default_data RAILS_ENV=production REDMINE_LANG=ja 
chown -R apache:apache /var/lib/redmine
chmod -R 755 files log tmp public/plugin_assets

/usr/sbin/httpd -DFOREGROUND

