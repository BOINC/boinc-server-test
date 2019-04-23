#!/bin/bash

echo "Attempting to install ansible, java, docker, php and composer"

#This function comes from https://getcomposer.org/doc/faqs/how-to-install-composer-programmatically.md
install_composer() {
    EXPECTED_SIGNATURE="$(wget -q -O - https://composer.github.io/installer.sig)"
    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
    ACTUAL_SIGNATURE="$(php -r "echo hash_file('sha384', 'composer-setup.php');")"
    
    if [ "$EXPECTED_SIGNATURE" != "$ACTUAL_SIGNATURE" ]
    then
        >&2 echo 'ERROR: Invalid installer signature'
        rm composer-setup.php
        exit 1
    fi
    
    sudo php composer-setup.php --install-dir=/usr/local/bin --filename=composer
    RESULT=$?
    rm composer-setup.php
    if [ $RESULT -ne 0 ];
    then
        echo "Failed to install composer.  Return code: $RESULT"
        exit 1
    else
        echo "Composer installed successfully"
    fi
}

#Check if using apt
if [ -n "$(command -v apt)"  ];
then
    sudo apt -y -qq install ansible php php-xml php-mbstring zip unzip
    sudo apt -y -qq install docker-ce
    if [ $? -ne 0 ];
    then
        echo "Please set up the repository for docker-ce.  See https://docs.docker.com/engine/installation/linux/docker-ce/$(. /etc/os-release; echo "$ID")/"
        exit 1
    fi
fi

#Check if using yum
if [ -n "$(command -v yum)" ]; 
then
    sudo yum -y -q install epel-release
    sudo yum install http://rpms.remirepo.net/enterprise/remi-release-7.rpm
    sudo yum-config-manager --enable remi-php73
    sudo yum -y -q clean all
    sudo yum -y -q install ansible docker composer php php-xml php-mbstring zip unzip
fi

# Add user to docker group so that they can run docker commands
if [ `groups $USER | grep docker | wc -l` -ne 1 ];
then
    if ! grep -q docker: /etc/group
    then
         sudo groupadd docker
    fi
    sudo usermod -a -G docker $USER
    echo "You have been added to the docker group.  In order to continue you may need to log out and back in again or restart your system in order to pick up the group change"
    exit 1
fi

# Check if docker-compose is installed.  If it isn't, direct user to instructions
if [ -z "$(command -v docker-compose)" ]; 
then
    echo "Please install docker-compose.  See https://docs.docker.com/compose/install/"
    exit 1
fi

# Check if composer is installed.  If it isn't, direct user to instructions
if [ -z "$(command -v composer)" ]; 
then
    install_composer()
fi

sudo systemctl enable docker
sudo systemctl restart docker

cd tests
composer -q require phpunit/phpunit
composer -q require guzzlehttp/guzzle
composer -q update
cd ..

echo "Setup complete."
