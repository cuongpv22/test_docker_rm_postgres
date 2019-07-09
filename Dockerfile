FROM centos:7.3.1611

LABEL author="TSDV Quan"

################################################ Proxy info ################################################
# set proxy env. Disable when deploy
ENV http_proxy http://cuongpvgmo:qazxsw@proxy.tsdv.com.vn:3128
ENV https_proxy http://cuongpvgmo:qazxsw@proxy.tsdv.com.vn:3128

########################################### Setting environment ############################################
ENV RUBY_VERSION=2.4.6 \
    BUNDLER_VERSION=1.17.3 \
    PASSENGER_VERSION=6.0.2

######################################### Setting work directory ###########################################
WORKDIR /tmp

########################################### Setting files ##################################################
COPY ./extra/database.yml ./database.yml
COPY ./extra/redmine-3.4.11.tar.gz /var/lib/redmine-3.4.11.tar.gz
COPY ./extra/Redmine_plugins.zip ./Redmine_plugins.zip
COPY ./extra/Gemfile ./Gemfile
COPY ./extra/production.rb ./production.rb
COPY ./extra/query.rb ./query.rb
COPY ./extra/plantuml ./plantuml

######################################### Setting timezone #################################################
RUN ln -fs /usr/share/zoneinfo/Asia/Tokyo /etc/localtime

########################################## Pre Installation ################################################
# Install core packages
RUN yum install -y epel-release && \
    yum install -y --nogpgcheck autoconf automake bison bzip2 gcc gcc-c++ make patch wget which unzip && \
    yum clean all

# Install CodeIT repo (For Apache 2.4.39)
RUN cd /etc/yum.repos.d && wget https://repo.codeit.guru/codeit.el`rpm -q --qf "%{VERSION}" $(rpm -q --whatprovides redhat-release)`.repo

############################################ Apache httpd ##################################################
RUN yum install -y --nogpgcheck expat-devel gdbm-devel libcurl-devel libffi-devel libicu-devel libidn-devel && \
    yum install -y --nogpgcheck libnghttp2-devel libpqxx-devel libtool libxml2-devel libxslt-devel libyaml-devel && \
    yum install -y --nogpgcheck ncurses-devel openssl-devel pcre-devel protobuf-devel readline-devel sqlite-devel zlib-devel curl-devel gettext-devel && \
    yum install -y --nogpgcheck httpd httpd-devel && \
    yum install -y --nogpgcheck ImageMagick ImageMagick-devel ipa-pgothic-fonts  perl-ExtUtils-Embed && \
    yum clean all

################################################ RUBY ######################################################
RUN curl -O https://cache.ruby-lang.org/pub/ruby/2.4/ruby-${RUBY_VERSION}.tar.gz && \
    tar zxf ruby-${RUBY_VERSION}.tar.gz && \
    rm -rf ruby-${RUBY_VERSION}.tar.gz && \
    cd ruby-${RUBY_VERSION}/ && \
    ./configure --disable-install-doc && \
    make && \
    make install

############################################## RUBY Gems ###################################################
# Install Bundler
RUN gem install bundler --no-rdoc --no-ri --version ${BUNDLER_VERSION}
# Install Passenger
RUN gem install passenger --no-rdoc --no-ri --version ${PASSENGER_VERSION} && \
    passenger-install-apache2-module --auto && \
    passenger-install-apache2-module --snippet >> /etc/httpd/conf.d/passenger.conf

############################################## Redmine #####################################################
# Install and configure Redmine
RUN cd /var/lib && \
    tar zxf redmine-3.4.11.tar.gz && \
    mv redmine-3.4.11 redmine && \
    cd /var/lib/redmine/config && \
    mv /tmp/database.yml . && \
    cp -p configuration.yml.example configuration.yml

# Install Redmine plugins
RUN cd /tmp && \
    mv Redmine_plugins.zip /var/lib/redmine/plugins && \
	cd /var/lib/redmine/plugins && \
	unzip Redmine_plugins.zip && \
	rm -rf Redmine_plugins.zip && \
    cp -rf /tmp/Gemfile /var/lib/redmine/ && \
    cp -rf /tmp/production.rb /var/lib/redmine/config/environments/ && \
    cp -rf /tmp/query.rb /var/lib/redmine/app/models/ && \
    cp -rf /tmp/plantuml /usr/bin/ && \
    chmod 755 /usr/bin/plantuml

# Initial setting
RUN mkdir -p /var/chainlogs/ && \
    chown -R apache:apache /var/chainlogs/ && \
    chmod 777 /var/chainlogs/
RUN cd /var/lib/redmine && \
    bundle install --without development test && \
    bundle exec rake generate_secret_token 

# Apache setting for Redmine
RUN echo "RackBaseURI /redmine" >> /etc/httpd/conf.d/redmine.conf && \
    ln -s /var/lib/redmine/public /var/www/html/redmine

############################################ Subversion #####################################################
# Install dependency
RUN wget https://codeload.github.com/JuliaStrings/utf8proc/tar.gz/v2.4.0 -O utf8proc-2.4.0.tar.gz && \
    tar -xzf utf8proc-2.4.0.tar.gz && \
    rm -rf utf8proc-2.4.0.tar.gz && \
    cd utf8proc-2.4.0 && \
    make && \
    make install

# Install Subversion 1.12
RUN wget https://www-us.apache.org/dist/subversion/subversion-1.12.0.tar.gz && \
    tar -xzf subversion-1.12.0.tar.gz && \
    rm -f subversion-1.12.0.tar.gz && \
    cd subversion-1.12.0 && \
    wget https://www.sqlite.org/2015/sqlite-amalgamation-3081101.zip && \
    unzip sqlite-amalgamation-3081101.zip && \
    mv sqlite-amalgamation-3081101 sqlite-amalgamation && \
    ./configure --with-lz4=internal && \
    make && \
    make install

################################################ Git ########################################################
# Install Git 2.22
RUN wget https://mirrors.edge.kernel.org/pub/software/scm/git/git-2.22.0.tar.gz && \
    tar -xzf git-2.22.0.tar.gz && rm -f git-2.22.0.tar.gz && \
    cd git-2.22.0 && \
    ./configure && \
    make && make install

######################################### Post Installation #################################################
# Clean cache
RUN rm -rf /var/cache/yum

# Set listen port
EXPOSE 80

# Make entry point
COPY entrypoint.sh /root
RUN chmod +x /root/entrypoint.sh
ENTRYPOINT /root/entrypoint.sh

