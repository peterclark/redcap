# Redcap [![Build Status](https://travis-ci.org/peterclark/redcap.svg?branch=master)](https://travis-ci.org/peterclark/redcap) [![Code Climate](https://codeclimate.com/github/peterclark/redcap/badges/gpa.svg)](https://codeclimate.com/github/peterclark/redcap)

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

##### Option 1 - Create your own class
```ruby
class Person < Redcap::Record
end

# find a record by id
bob = Person.find 1
# find a record by a field value
bob = Person.where(first_name: 'Bob').first
# get all records
people = Person.all
# get first_name and age for all records
people = Person.select(:first_name, :age)
# update a record
bob.last_name = 'Smith'
bob.save
```

##### Summary of available methods
```ruby
redcap = Redcap.new

# Get project info
redcap.project

# Get all records and all fields
redcap.records

# Get all records and a subset of fields
redcap.records fields: %w(first_name age)

# Get all records and all fields matching a filter
redcap.records filter: '[age] > 40'

# Get all records and a subset of fields matching a filter
redcap.records fields: %w(email age), filter: '[age] < 35'

# or, if you prefer an ActiveRecord-like interface...

Redcap::Record.find 1
Redcap::Record.all
Redcap::Record.select(:first_name, :age)
Redcap::Record.where(first_name: 'Bob')

# updating a record
bob = Redcap::Record.find 1
bob.last_name = 'Smith'
bob.save

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

##### Limiting fields with `.records` using `fields`
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

##### Limiting records with `.records` using `filter`
```ruby
redcap = Redcap.new
records = redcap.records filter: '[age] > 55'
user = records.first
user.record_id
# => 1
user.first_name
# => 'Obi'
user.age
# => '65'
```

##### Limiting records with `.records` using `records`
```ruby
redcap = Redcap.new
records = redcap.records records: [1,2]
user = records.first
user.record_id
# => 1
user.first_name
# => 'Leah'
user.age
# => '42'
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

## TODO

1. Method chaining
  - `Person.where(age: 40).select(:first_name)`
2. Create record
  - `Person.create(first_name: 'Bo', ...)`
## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/peterclark/redcap.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
