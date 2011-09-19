
require 'socket'
require 'cgi'
require 'rubygems'
require 'thin_parser'


module PushyServer

  class InvalidRequest < IOError
  end

    HTTP_HEADER =  "HTTP/1.1 200 OK\r\n" + "Server: An infinite number of monkeys\r\n" + "Content-Type: application/x-event-stream\r\n" + "Keep-Alive: timeout=15 max=99\r\n" + "Connection: Keep-Alive\r\n" + "Transfer-Encoding: chunked\r\n" + "\r\n"

    MAX_BODY          = 1024 * (80 + 32)
    MAX_HEADER        = 1024 * (80 + 32)

    INITIAL_BODY      = ''
    INITIAL_BODY.encode!(Encoding::ASCII_8BIT) if INITIAL_BODY.respond_to?(:encode!)


  def initialize(app)
    @on_close_blocks = []
    @app = app
    @is_closed = nil
    @http_strs = ['GET'].freeze
    @raw_strs = ['RAW'].freeze
    @http_max_receive_header_length = 512.freeze

  end

  def post_init
    @is_closed = false
    port, ip = Socket.unpack_sockaddr_in(get_peername)
    puts "connection from #{ip}:#{port}"
    @con_type = :unknown
    @status = :connected
    @received = ''
    @http_parser = nil
  end

  def receive_data(data)

    if @con_type == :unknown

      @received << data

      if @received.length < 3
        return
      end

      first_three = @received[0..2]

      if @http_strs.index(first_three)
        @con_type = :http
        puts "connection type: http"

        @http_parser = Thin::HttpParser.new
        @num_parsed = 0
        @env = {}
        @data = ''
        @body = StringIO.new(INITIAL_BODY)
        data = @received

      elsif @raw_strs.index(first_three)
        @con_type = :raw
        puts "connection type: raw"

        # TODO handle this

      else
        puts "unknown connection type"
        close_connection_after_writing
      end

    end

    if @con_type == :http
      receive_data_http(data)
    end

  end


  def receive_data_http(data)
    @data << data
    
    if @received.size > MAX_HEADER
      raise InvalidRequest, "Header too long"
    end
    
    @num_parsed = @http_parser.execute(@env, @data, @num_parsed)

    if @http_parser.finished? && @body.size >= @env['CONTENT_LENGTH'].to_i
      
      puts "HTTP PARSER FINISHED"
      
      send_header
      
      @data = nil
      @body.rewind
      
      # parse the parameters in the query string
      @params = CGI.parse(@env['QUERY_STRING'])
      
      @params.each_pair do |key, val|
        @params[key] = val.join
      end
      
      puts "params: #{@params.inspect}"
      
      # call the modified rack app
      @app.call(@params, self)
      
      return true
    end
  end

  def on_close(&block)
    @on_close_blocks << block
  end

  def send_header
    send_data(HTTP_HEADER)
  end

  def unbind
    @is_closed = true
    puts "connection lost"
#    close_connection
#    @on_close_blocks.each do |block|
#      block.call
#    end
  end

  # write a chunk of data
  def write(data)
    count = data.length.to_s(16)
    send_data(count+"\r\n")
    send_data(data+"\r\n")
  end

  def closed?
    return true if @is_closed
  end

end
