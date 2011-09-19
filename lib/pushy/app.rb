
require 'cgi'
require 'logger'

require 'lib/pushy/session_tracker'
require 'lib/pushy/transport'
require 'lib/pushy/channel'

module Pushy
  class App

#    ASYNC_CALLBACK = "async.callback".freeze

# Date	Mon, 19 Sep 2011 03:14:47 GMT
# Server	thin 1.2.11 codename Bat-Shit Crazy
# Content-Type	application/x-event-stream
# Keep-Alive	timeout=15, max=99
# Connection	Keep-Alive
# Transfer-Encoding	chunked
    
    AsyncResponse = [-1, {}, []].freeze
    InvalidResponse = [500, {"Content-Type" => "text/html"}, ["Invalid request"]].freeze
    
    attr_reader :session_key, :channel_key, :channel, :logger, :ping_interval
    
    # Create a new Pushy Rack app.
    # Options:
    #   session_key: the key in which the session unique ID will be passed in the request
    #   channel_key: the key in which the channel unique ID will be passed in the request
    #   channel: a channel object to subscribe to on new connections
    #   logger: Logger instance to log to
    #   ping_interval: interval at which to send ping message to clients
    def initialize(options={})
      @session_key = options[:session_key] || "session_id"
      @channel_key = options[:channel_key] || "channel_id"
      @channel = options[:channel] || Channel::AMQP.new
      @logger = options[:logger] || Logger.new(STDOUT)
      @ping_interval = options[:ping_interval] || 5
      @started = false
      @session_tracker = SessionTracker.new
    end
    
    def call(request, connection)

      on_start unless @started
      
      channel_id = request[@channel_key]
      session_id = request[@session_key]
      puts "Session id: #{session_id.inspect}"


      return InvalidResponse unless channel_id && session_id
      @logger.info "Connection on channel #{channel_id} from #{session_id}" if @logger

#      if request['msg']
#        data = {
#          :content => request['msg']
#        }.to_json
#        Pushy::Channel::AMQP.new.publish(channel_id, data)
#        return [200, {"Content-Type" => "text/plain"}, ["Rack response!"]]
#      end

      session = @session_tracker.find(session_id)
      if session
        session.update
        new_session = false
      else
        new_session = true
        session = @session_tracker.start(session_id)
      end

      puts "=========="
      puts "incoming request with transport: " + request["transport"]
   
      transport = Transport.select(request["transport"]).new(request, session, connection)
      transport.on_close { @logger.info "Connection closed on channel #{channel_id} from #{session_id}" } if @logger
      
#      EM.next_tick { puts "ENV: " + env.inspect.to_s }
#      EM.next_tick { "async.callback".freeze.call transport.render }

#      EM.next_tick { env[ASYNC_CALLBACK].call transport.render }

      puts "REQUEST: #{request.inspect}"      
      
      if request['msg'] && (request['msg'] != [])
        msg = CGI.unescape(request['msg'])
        puts "got message: " + msg
        EM.next_tick { transport.send(channel_id, request['msg']) }
      else
        @channel.subscribe(channel_id, session_id, transport)

        if new_session
          EM.next_tick { transport.write_welcome }
        end
      end

#      AsyncResponse
    end
    
    private
      def on_start
        EM.add_periodic_timer(@ping_interval) { Transport.ping_all }
        EM.add_periodic_timer(SESSION_TIMEOUT * 60 + 1) { @session_tracker.cleanup }
        @started = true
      end

  end
end
