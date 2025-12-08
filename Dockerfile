# 1️⃣ Base image
FROM ubuntu:latest

# 2️⃣ Environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Manila
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV RAILS_ENV=development
ENV PATH="/root/.rbenv/shims:/root/.rbenv/bin:$PATH"

# 3️⃣ Install system dependencies (including Nokogiri build deps)
RUN apt-get update && apt-get install -y \
    git \
    curl \
    wget \
    build-essential \
    libssl-dev \
    libreadline-dev \
    zlib1g-dev \
    libxml2-dev \
    libxslt1-dev \
    liblzma-dev \
    ruby-dev \
    patch \
    nodejs \
    npm \
    ca-certificates \
    locales \
    tzdata \
    sudo \
    nano \
    net-tools \
    && apt-get clean

# 4️⃣ Generate locale
RUN locale-gen en_US.UTF-8

# 5️⃣ Install rbenv for Ruby
RUN git clone https://github.com/rbenv/rbenv.git ~/.rbenv \
    && cd ~/.rbenv && src/configure && make -C src \
    && echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc \
    && echo 'eval "$(rbenv init -)"' >> ~/.bashrc \
    && git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build

# 6️⃣ Install Ruby 2.2.0
RUN ~/.rbenv/bin/rbenv install 2.2.0 \
    && ~/.rbenv/bin/rbenv global 2.2.0

# 7️⃣ Install Bundler 1.17.3
RUN gem install bundler -v 1.17.3

# 8️⃣ Clone Rails app
RUN git clone https://github.com/234ekel234/sanro-inventory-working.git /app

# 9️⃣ Copy backup.sql into container (optional)
COPY backup.sql /app/backup.sql

# 🔟 Set working directory
WORKDIR /app


# 1️⃣2️⃣ Expose Rails port
EXPOSE 3000

# 1️⃣3️⃣ Default command: open a bash shell
CMD ["/bin/bash"]
