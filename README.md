# Redcap

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

## Usage

If variables stored in a `.env` file

```ruby
redcap = Redcap.new
```

otherwise, initialize Redcap like this:

```ruby
Redcap.configure do |config|
  config.host = "http://yourhost.com"
  config.token = 1234
end

redcap = Redcap.new
```

or like this

```ruby
redcap = Redcap.new host: 'http://yourhost.com', token: 1234
```


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/peterclark/redcap.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
