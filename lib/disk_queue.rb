require 'mongo'
require 'base64'
include Mongo

class DBQueue

    DEFAULT_OPTIONS = {
        memory_buffer: 100
    }

   def initialize(name, db, options = {})
        @filling = false
        @saving = false
        @empty_db = false
        @db = db
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

      if @buffer_db.length >= @options[:memory_buffer] and not @saving
        p "SAVING #{@name}"
        @saving = true
        to_save = @buffer_db.clone
        @buffer_db = []
        @collection.insert({ :name => @name, :buffer => Base64.encode64(Marshal.dump(to_save)) })
        @saving = false
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
      if not @filling and not @empty_db
        p "FILLING #{@name}"
        @filling = true
        entity = @collection.find_one( "name" => @name )
        if not entity.nil?
          p entity["_id"]
          data = Base64.decode64(entity["buffer"])
          data = Marshal.load(data)

          @q += data
          @collection.remove(entity)
        else
          @empty_db = true
          p "ENPTY DB"
        end
        @filling = false
      end
    end
end
