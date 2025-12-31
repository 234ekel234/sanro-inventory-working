#!/bin/bash

# Use the correct Ruby version
rvm use 2.1.3

# Ensure PostgreSQL binaries are in PATH
export PATH=/usr/local/pgsql-9.4/bin:$PATH

# Start PostgreSQL as postgres user
su - postgres -c "/usr/local/pgsql-9.4/bin/pg_ctl -D /home/postgres/pgsql-9.4/data -l /home/postgres/logfile start"

# Change to Rails app directory
cd /home/sanro/sanro-inventory

# Start Rails server
bundle exec rails server -b 0.0.0.0 -p 3000
