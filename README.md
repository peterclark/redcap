# Redcap [![Build Status](https://travis-ci.org/peterclark/redcap.svg?branch=master)](https://travis-ci.org/peterclark/redcap) [![Code Climate](https://codeclimate.com/github/peterclark/redcap/badges/gpa.svg)](https://codeclimate.com/github/peterclark/redcap)

A Ruby gem for interacting with the REDCap API

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'redcap', git: 'https://github.com/peterclark/redcap.git'
```

And then execute:

    $ bundle

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

##### Create a class that inherits from `Redcap::Record`
```ruby
class Person < Redcap::Record
end
```

###### Find a record by `record_id`
```ruby
bob = Person.find 1
```

###### Find records using an array of ids
```ruby
people = Person.where id: [1,4,5]
```

###### Find a record by a field value
```ruby
bob = Person.where(first_name: 'Bob').first
```

###### Return all records
```ruby
people = Person.all
```

###### Return all records with only `first_name` and `age`
```ruby
people = Person.select(:first_name, :age)
```

###### Pluck a field from all records
```ruby
names = Person.pluck(:first_name)
# ['Joe', 'Sal', 'Luke']
```

###### Update a record
```ruby
bob = Person.where(first_name: 'bob').first
bob.last_name = 'Smith'
bob.save
```

###### Create a record
```ruby
joe = Person.new(first_name: 'Joe', email: 'joe@google.com')
joe.save
```

###### Using the `Redcap` class to return raw data
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

# Get records with the given ids and a subset of fields matching a filter
redcap.records records: [1,4], fields: %w(email age), filter: '[age] < 35'
```

## TODO

1. Method chaining
  - `Person.where(age: 40).select(:first_name)`
2. Advanced filter logic
  - `Person.where(age.gt: 40)` # greater than

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/peterclark/redcap.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
