FROM ruby:2.7.5 AS base
RUN apt-get update -qq && apt-get install -y nodejs postgresql-client
RUN apt-get update -qq && apt-get install -y python3 python3-pip python3-venv
RUN apt-get update -qq && apt-get install -y libtool libffi-dev make libzmq3-dev libczmq-dev
RUN apt-get update -qq && apt-get install -y graphviz awscli

RUN gem install ffi-rzmq
RUN gem install iruby --pre
RUN gem install \
        descriptive_statistics\
        awesome_print \
        nokogiri \
        activerecord-import \
        goldiloader \
        parallel \
        pycall \
        moneta \ 
        histogram \
        dotenv \
        whenever \
        pg \
        ruby-prof \
        rails \
        enumerable-statistics \
        pandas \
        pry \
        pry-doc \
        awesome_print \
        ethereum.rb \
        webrick \
        logger \
        graphviz \
        faraday \
        vega \
        resolv-replace
RUN gem install eth -v '0.4.17'

RUN ln -s $(which python3) /usr/local/bin/python
RUN ln -s $(which pip3) /usr/local/bin/pip
ENV DEFAULT_KERNEL_NAME=ruby