# Redcap [![Build Status](https://travis-ci.org/peterclark/redcap.svg?branch=master)](https://travis-ci.org/peterclark/redcap) [![Code Climate](https://codeclimate.com/github/peterclark/redcap/badges/gpa.svg)](https://codeclimate.com/github/peterclark/redcap)

A Ruby gem for interacting with the REDCap API

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'redcap', github: 'peterclark/redcap'
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

##### Create a class that inherits from `Redcap::Record`.

```ruby
# name the class after your REDCap project
# ex. Survey, Volunteer, Trial, People
class People < Redcap::Record
end
```

###### Find a record by `record_id`

```ruby
bob = People.find 1
```

###### Find records using an array of ids

```ruby
people = People.where id: [1,4,5]
```

###### Find a record by a field value

```ruby
bob = People.where(first_name: 'Bob').first
```

###### Return all records

```ruby
people = People.all
```

###### Return all records with only `first_name` and `age`

```ruby
people = People.select(:first_name, :age)
```

###### Pluck a field from all records

```ruby
names = People.pluck(:first_name)
# ['Joe', 'Sal', 'Luke']
```

###### Return all record ids

```ruby
ids = People.ids
# [1,2,3, ... ]
```

###### Return the total number of records

```ruby
total = People.count
# 125
```

###### Update a record

```ruby
bob = People.where(first_name: 'bob').first
bob.last_name = 'Smith'
bob.save
```

###### Create a record

```ruby
joe = People.new(first_name: 'Joe', email: 'joe@google.com')
joe.save
```

###### Delete a record

```ruby
joe = People.find(joe.id)
joe.destroy
# 1 (number of records deleted)
```

###### Delete multiple records

```ruby
joe = People.new(first_name: 'Joe', email: 'joe@google.com')
joe.save

ray = People.new(first_name: 'Ray', email: 'ray@google.com')
ray.save

People.delete_all [joe.id, ray.id]
# 2 (number of records deleted)
```

###### `>` Greater Than

```ruby
over40 = People.gt age: 40
```

###### `<` Less Than

```ruby
under30 = People.lt age: 30
```

###### `>=` Greater Than or Equal To

```ruby
over40 = People.gte age: 41
```

###### `<=` Less Than or Equal To

```ruby
under30 = People.lte age: 29
```

###### Logging

```ruby
# set log to true on the client
People.client.log = true
```

###### Enable Caching

Setting `REDCAP_CACHE` to `ON` inside your `.env` file will cache all calls to Redcap. A full cache flush will occur when any record is updated or created.

```ruby
# inside .env
# REDCAP_CACHE=ON
```

###### Force cache flush

If `REDCAP_CACHE` is set to `ON`, the cache can be manually flushed by calling `flush_cache` on the client.

```ruby
People.client.flush_cache
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

- `People.where(age: 40).select(:first_name)`

2. Create `RedcapRecord` module as alternative to inheritance

- `include Redcap`

3. Destroy a record

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/peterclark/redcap.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
