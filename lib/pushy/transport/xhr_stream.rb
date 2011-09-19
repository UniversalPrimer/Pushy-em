module Pushy
  module Transport
    class XhrStream < Base
      MAX_BYTES_SENT = 1048576 # Magic number taken from Orbited
      
      register :xhr_stream
      
      def headers
        {'Content-Type','application/x-event-stream'}
      end
      
      def opened
        # Safari requires a padding of 256 bytes to render
        @sent = 256
        @connection.write(' ' * 256)
      end

      def write_raw(escaped_data, parms={})
        puts "xhr writing"
        @sent += escaped_data.size
        escaped_data = escaped_data + ' ' # add trailing space to mark end of data
        @connection.write(escaped_data)
        if parms[:close_connection] || (@sent > MAX_BYTES_SENT)
          EM.next_tick { @connection.close_connection_after_writing }
        end
      end

    end
  end
end
