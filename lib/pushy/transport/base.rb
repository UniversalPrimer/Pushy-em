require 'lib/pushy/deferrable_body'

module Pushy
  module Transport
    OPENED = []
    BACKENDS = {}

    def self.select(transport)
      BACKENDS[transport] || BACKENDS["default"]
    end
    
    def self.ping_all
      OPENED.each { |transport| transport.ping }
    end
    
    class Base
      attr_reader :request, :connection
      
      def initialize(request, session, connection)
        @connection = connection
        @session = session
        @request = request
#        @renderer = DeferrableBody.new
        opened
        OPENED << self
        on_close do
          OPENED.delete(self)
        end
      end
            
      def headers
        {'Content-Type' => 'text/html'}
      end
            
      def opened
      end

      # TODO needs security :-S
      def send(channel_id, data)
        amqp_data = {
          :content => data
        }.to_json

        ret_data = ''
        begin
          Pushy::Channel::AMQP.new.publish(channel_id, amqp_data)
        rescue Exception => e
          ret_data = {
            :status => 'error',
            :msg => e.message
          }.to_json
        end

        ret_data = {
          :status => 'success'
        }.to_json

        write(ret_data, :close_connection => true)
      end

      def write(data, parms={})
        # this escape is identical to javascript's encodeURIComponent
        escaped = URI.escape(data, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
        write_raw(escaped, parms)
      end

      def write_welcome
        puts "writing WELCOME"
        message = {
          :session_id => @session.id,
          :session_msg_count => @session.next_msg_count,
          :type => 'welcome'
        }.to_json

        write(message)
      end

      # called when messages are received through AMQP
      def write_message(json_data)

        begin
          data = JSON.parse(json_data)

          message = {
            :session_id => @session.id,
            :session_msg_count => @session.next_msg_count,
            :type => 'data',
            :data => data
          }.to_json

          write(message)

        rescue Exception => e
          puts "ERROR: illegal data received"
        end
      end

      def ping
        puts "pinging"
        @connection.write(' ')
#        renderer.call [' ']
      end      

      def close
        @connection.close_connection
#        renderer.succeed
      end

      def on_close(&block)
        @connection.on_close(&block)
      end
      
      def closed?
        @connection.closed?
      end
      
      def self.register(name)
        BACKENDS[name.to_s] = self
      end
    end

  end
end
