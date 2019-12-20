#!/bin/bash

PWD=/var/www/vhosts/ticketmachine.de/crawler.ticketmachine.de
PATH=/var/www/vhosts/ticketmachine.de/.rbenv/shims:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games
RBENV_VERSION=2.3.7
OLDPWD=/var/www/vhosts/ticketmachine.de
RBENV_SHELL=bash
USER=citicketmachine
TERM=xterm
MAIL=/var/mail/citicketmachine
HOME=/var/www/vhosts/ticketmachine.de

cd crawler.ticketmachine.de/

bundle install --path vendor/bundle
bundle exec ruby crawl.rb