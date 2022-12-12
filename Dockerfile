FROM ruby:2.3

RUN gem install bundler -v 1.13.5

RUN mkdir -p /app
ADD ./Gemfile /app/Gemfile
ADD ./Gemfile.lock /app/Gemfile.lock

WORKDIR /app

RUN bundle install

EXPOSE 4000

CMD bundle exec jekyll serve
