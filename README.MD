Remove postgres 16 and install postgres 9.4
apt-get remove -y postgresql* && apt-get autoremove -y
apt-get update
apt-get install -y build-essential libreadline-dev zlib1g-dev flex bison wget

Install postgres 9.4
    wget https://ftp.postgresql.org/pub/source/v9.4.26/postgresql-9.4.26.tar.gz
    tar xzf postgresql-9.4.26.tar.gz
    cd postgresql-9.4.26

    apt-get update
    apt-get install -y build-essential libreadline-dev zlib1g-dev flex bison

    ./configure --prefix=/usr/local/pgsql-9.4
    make
    make install

    export PATH=/usr/local/pgsql-9.4/bin:$PATH

HOW TO START SERVER

    useradd -m postgres

    su - postgres


    /usr/local/pgsql-9.4/bin/initdb -D ~/pgsql-9.4/data
    /usr/local/pgsql-9.4/bin/pg_ctl -D /home/postgres/pgsql-9.4/data -l logfile start


PREREQUISITES:
ubuntu:latest container 
sanro/                <-- main folder
├── Dockerfile         <-- the Dockerfile
├── backup.sql         <-- your database backup file
├── .dockerignore      <-- optional, to exclude unnecessary files from image
├── docker-compose.yml <-- optional, if you want to use docker-compose
Steps:
1. build the image:

    docker-compose build

2. start container:(Check docker-compose.yml to check the image created or run docker images on terminal)

    docker run -it -p 3000:3000 --name sanro1 sanro-image:latest bash
    docker run -it -p 3000:3000 --name <name of container to be made> <name of image created> bash
Once container is open:

3. Install postgres 9.4
    wget https://ftp.postgresql.org/pub/source/v9.4.26/postgresql-9.4.26.tar.gz
    tar xzf postgresql-9.4.26.tar.gz
    cd postgresql-9.4.26

    apt-get update
    apt-get install -y build-essential libreadline-dev zlib1g-dev flex bison

    ./configure --prefix=/usr/local/pgsql-9.4
    make
    make install

    export PATH=/usr/local/pgsql-9.4/bin:$PATH
4. Make sure postgres is installed so gem 'pg' will work then bundle install
    bundle _1.17.3_ install
5. Start psql server
    -create user
    useradd -m postgres 
    -log in as postgres user
    su - postgres
    -start the server
    /usr/local/pgsql-9.4/bin/initdb -D ~/pgsql-9.4/data
    /usr/local/pgsql-9.4/bin/pg_ctl -D /home/postgres/pgsql-9.4/data -l logfile start
6. Add backup.sql
    /usr/local/pgsql-9.4/bin/psql -U postgres -c "CREATE DATABASE sanro;"
    /usr/local/pgsql-9.4/bin/psql -U postgres -d sanro -f /app/backup.sql

7. Start rails server 
    -Go to app directory
    bundle exec rails server -b 0.0.0.0 -p 3000
