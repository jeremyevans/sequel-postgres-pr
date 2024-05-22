# Fixed size buffer.
class PostgresPR::Buffer

  class Error < RuntimeError; end
  class EOF < Error; end 

  def self.of_size(size)
    raise ArgumentError if size < 0
    new('#' * size)
  end 

  # This should be called with a mutable string, which will be used as the
  # underlying buffer.
  def initialize(content)
    @size = content.size
    @content = content
    @position = 0
  end

  def size
    @size
  end

  def position
    @position
  end

  def position=(new_pos)
    raise ArgumentError if new_pos < 0 or new_pos > @size
    @position = new_pos
  end

  def at_end?
    @position == @size
  end

  def content
    @content
  end

  def read(n)
    raise EOF, 'cannot read beyond the end of buffer' if @position + n > @size
    str = @content[@position, n]
    @position += n
    str
  end

  def write(str)
    sz = str.size
    raise EOF, 'cannot write beyond the end of buffer' if @position + sz > @size
    @content[@position, sz] = str
    @position += sz
    self
  end

  def copy_from_stream(stream, n)
    raise ArgumentError if n < 0
    while n > 0
      str = stream.read(n) 
      write(str)
      n -= str.size
    end
    raise if n < 0 
  end

  NUL = "\000"

  def write_cstring(cstr)
    raise ArgumentError, "Invalid Ruby/cstring" if cstr.include?(NUL)
    write(cstr)
    write(NUL)
  end

  # returns a Ruby string without the trailing NUL character
  def read_cstring
    nul_pos = @content.index(NUL, @position)
    raise Error, "no cstring found!" unless nul_pos

    sz = nul_pos - @position
    str = @content[@position, sz]
    @position += sz + 1
    return str
  end

  IS_BIG_ENDIAN = [0x12345678].pack("L") == "\x12\x34\x56\x78"
  private_constant :IS_BIG_ENDIAN

  def read_byte
    ru(1, 'C')
  end

  def read_int16
    ru_swap(2, 's') 
  end

  def read_int32
    ru_swap(4, 'l') 
  end

  def write_byte(val)
    pw(val, 'C')
  end

  def write_int32(val)
    pw(val, 'N')
  end

  private

  def pw(val, template)
    write([val].pack(template))
  end

  # shortcut method for readn+unpack
  def ru(size, template)
    read(size).unpack(template).first
  end

  if [0x12345678].pack("L") == "\x12\x34\x56\x78"
    # :nocov:
    # Big Endian
    def ru_swap(size, template)
      read(size).unpack(template).first
    end
    # :nocov:
  else
    # Little Endian
    def ru_swap(size, template)
      str = read(size)
      str.reverse!
      str.unpack(template).first
    end
  end
end
