require 'mongo'
require 'base64'
include Mongo

class DBQueue

    DEFAULT_OPTIONS = {
        memory_buffer: 100
    }

   def initialize(name, options = {})
        @db = MongoClient.new("localhost", 27017, :pool_size => 10, :pool_timeout => 10).db("queue")
        @collection = @db.collection("queues")
        @name = name

        @options     = DEFAULT_OPTIONS.merge( options )

        @size     = 0
        @q        = []
        @buffer   = []
        @buffer_db = []
    end

    def full?
      @q.length >= @options[:memory_buffer]
    end

    def <<( object )
        if full?
            add_to_db object
        else
            @q << object
        end

        @size += 1
        self
    end
    alias :push :<<

    def add_to_db o
      @buffer_db << o

      if @buffer_db.length >= @options[:memory_buffer]
        to_save = @buffer_db.clone
        @buffer_db = []
        @collection.insert({ :name => @name, :buffer => Base64.encode64(Marshal.dump(to_save)) })
      end
    end

    def pop
        return if @q.empty?
        @size -= 1
        @q.shift
    ensure
        fill_from_db if reached_fill_threshold?
    end

    def reached_fill_threshold?
      @q.empty? and @size > 0
    end

    def empty?
      @size == 0
    end

    def size
        @size
    end

    def fill_from_db
      data = @collection.find_one( "name" => @name )
      if not data.nil?
        data = Base64.decode64(data["buffer"])
        data = Marshal.load(data)

        @q += data
        p "BING"
      end
    end

end
