# Redcap [![Build Status](https://travis-ci.org/peterclark/redcap.svg?branch=master)](https://travis-ci.org/peterclark/redcap)

A Ruby gem for interacting with the REDCap API

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'redcap'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install redcap

## Initialization

You can initialize a Redcap instance in one of three ways:

##### Using a `.env` file

```ruby
# inside .env file
# REDCAP_HOST=http://yourhost.com
# REDCAP_TOKEN=12345

redcap = Redcap.new
```

##### Using a block

```ruby
Redcap.configure do |config|
  config.host = "http://yourhost.com"
  config.token = 1234
end

redcap = Redcap.new
```

##### Passing in a hash of options

```ruby
redcap = Redcap.new host: 'http://yourhost.com', token: 1234
```

## Usage

##### Summary of available methods
```ruby
redcap = Redcap.new

# Retrieve all records and all fields
redcap.records

# Retrieve only first_name and age fields for all records
redcap.records fields: %w(first_name age)

# Retrieve project info
redcap.project

```

##### Accessing records with `.records`
```ruby
redcap = Redcap.new
records = redcap.records
user = records.first
user.record_id
# => 1
user.first_name
# => 'Darth'
user.age
# => 38
```

##### Limiting fields with `.records`
```ruby
redcap = Redcap.new
records = redcap.records fields: %w(first_name age)
user = records.first
user.record_id
# => nil
user.first_name
# => 'Luke'
user.age
# => '18'
```

##### Project Info with `.project`
```ruby
redcap = Redcap.new
project = redcap.project
project.project_title
# => 'People'
project.creation_time
# => '2017-02-17 06:02:54'
```


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/peterclark/redcap.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
