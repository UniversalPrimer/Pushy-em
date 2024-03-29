module Pushy
  module Channel
    class AMQP
      def initialize(options={})
        gem 'amqp', '=0.6.7'
        require 'amqp'
        require 'mq'
        @options = options
        # Delay connection to AMQP because we want to wait to be
        # inside the EM.run block started by Thin.
        @connected = false
        @transport
        @channel_id
        @session_id
      end
    
      def subscribe(channel_id, session_id, transport)
        connect
        key = channel_name(channel_id)
        queue = MQ.queue("#{key}.#{session_id}")

        queue.bind(@topic, :key => key).subscribe do |message|
          transport.write_message(message)
        end

        # TODO maybe delay queue deletion until unused for 1 min or so
        transport.on_close { queue.delete }
      end

      def publish(channel_id, message)
        connect
        key = channel_name(channel_id)
        @topic.publish(message, :routing_key => key)
      end
      
      private
        def connect
          return if @connected
          ::AMQP.connect(@options)
          @topic = MQ.topic("pushy")
          @connected = true
        end
        
        def channel_name(id)
          "channel.#{id}"
        end
    end
  end
end
