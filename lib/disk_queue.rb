class DiskQueue

    DEFAULT_OPTIONS = {
        memory_buffer: 100
    }

   def initialize( options = {} )
        @options     = DEFAULT_OPTIONS.merge( options )
        @memory_buffer = @options[:memory_buffer]

        @size     = 0
        @q        = []
        @buffer   = @options[:disk_buffer] || get_tempfile
    end

    def <<( object )
        if full?
            push_to_disk object
        else
            @q << object
        end

        @size += 1
        self
    end
    alias :push :<<

    def pop
        return if @q.empty?
        @size -= 1
        @q.shift
    ensure
        fill_from_disk if reached_fill_threshold?
    end

    def to_a
        queue = dup
        ary = []
        while item = queue.pop
            ary << item
        end
        ary
    end

    def dup
        disk_buffer_copy = get_tempfile
        IO.copy_stream @buffer, disk_buffer_copy

        queue = self.class.new( disk_buffer: disk_buffer_copy )
        queue.copy( @q, size )
        queue
    end

    def empty?
      @size == 0
    end

    def size
        @size
    end

    def clear
        @q.clear
        @size = 0
        nil
    ensure
        @buffer.close
        @buffer.unlink
    end

    protected

    def copy( memory_entries, sz )
        @q    = memory_entries
        @size = sz
    end

    private

    def get_tempfile
        Tempfile.open( 'DiskCache' )
    end

    def reached_fill_threshold?
        @q.size <= @memory_buffer * 0.1
    end

    def full?
        @q.size >= @memory_buffer
    end

    def push_to_disk( object )
        @buffer.puts serialize( object )
        @buffer.flush
    end

    def fill_from_disk
        disk_buffer_size = @size - @q.size
        return if disk_buffer_size == 0

        items_to_get = @memory_buffer - @q.size
        items_to_get = disk_buffer_size if items_to_get > disk_buffer_size

        truncate = 0
        @buffer.tail( items_to_get ).each do |serialized|
            truncate += serialized.size + "\n".size
            @q       << unserialize( serialized )
        end

        @buffer.truncate @buffer.size - truncate
    end

    def serialize( object )
        Marshal.dump( object ).gsub( "\n", newline_placeholder )
    end

    def unserialize( dump )
        Marshal.load( dump.gsub( newline_placeholder, "\n" ) )
    end

    def newline_placeholder
        @newline_placeholder ||= Time.now.to_i.to_s
    end

end
