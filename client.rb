# Client script to push messages to the browser
$:.unshift File.dirname(__FILE__) + "/lib/"

require 'rubygems'
require 'pushy'
require 'amqp'
require 'json'

abort "usage: ruby client.rb <channel_id> <message>" unless ARGV.size == 2

AMQP.start do

  channel_id = ARGV[0]
  text = ARGV[1]

  data = {
    :content => text
  }.to_json

  Pushy::Channel::AMQP.new.publish(channel_id, data)
  AMQP.stop { EM.stop }
end
