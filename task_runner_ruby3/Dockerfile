# docker build -t adam429/pan-repo:panworker_ruby3 .
# docker push adam429/pan-repo:panworker_ruby3
# docker container run -d -e DB_CONNECT_STR='xxx' -e WORKER_NAME='worker' --name panworker adam429/pan-repo:panworker_ruby3

FROM ruby:3.1.2 AS base
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
        resolv-replace \
        method_source \
        parser \
        unparser \
        opal \
        redis-objects \
        connection_pool
RUN gem install eth -v '0.4.17'

WORKDIR /panworker
# COPY Gemfile /panscan/Gemfile
# COPY Gemfile.lock /panscan/Gemfile.lock
COPY panworker_v2.rb /panworker/panworker.rb

# Configure the main process to run when running the image
CMD ["ruby", "panworker.rb"]

