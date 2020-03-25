#!/usr/bin/env bash

# Had issues with bundler version not existing in the container.
#  Resolved by deleting the Gemfile.lock and allowing dependencies to be updated.

# Move into ruby project directory
cd sinapp

# Configure bundler
bundle lock --add-platform ruby
bundle lock --add-platform x86_64-linux

bundle config --local deployment true
bundle config --local without development test
bundle config --local path ../vendor/bundle

# Build ruby gems
bundle check
bundle install

# Discard the cache
rm -rf ../vendor/bundle/ruby/2.5.0/cache

# Re-arrange the path so it works with layers.
#  to vendor/bundle/ruby/gems/2.5.0
mkdir ../vendor/bundle/ruby/gems
mv ../vendor/bundle/ruby/2.5.0 ../vendor/bundle/ruby/gems

# Reset bundler
bundle config unset --local deployment
bundle config unset --local path
bundle config unset --local without
