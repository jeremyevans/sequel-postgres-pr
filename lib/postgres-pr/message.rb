#
# Author:: Michael Neumann
# Copyright:: (c) 2005 by Michael Neumann
# License:: Same as Ruby's or BSD
# 

module PostgresPR

  class PGError < StandardError; end
  class ParseError < PGError; end
  class DumpError < PGError; end

  # Base class representing a PostgreSQL protocol message
  class Message
    # One character message-typecode to class map
    MsgTypeMap = Hash.new { UnknownMessageType }

    def self.register_message_type(type)
      define_method(:message_type){type}
      MsgTypeMap[type] = self
    end

    def self.read(stream)
      type = read_exactly_n_bytes(stream, 1)
      length = read_exactly_n_bytes(stream, 4).unpack('N').first  # FIXME: length should be signed, not unsigned

      raise ParseError unless length >= 4

      # initialize buffer
      buffer = Buffer.of_size(1+length)
      buffer.write(type)
      buffer.write_int32(length)
      buffer.copy_from_stream(stream, length-4)
      
      MsgTypeMap[type].create(buffer)
    end

    def self.read_exactly_n_bytes(io, n)
      buf = io.read(n)
      raise EOFError unless buf && buf.size == n
      buf
    end
    private_class_method :read_exactly_n_bytes

    def self.create(buffer)
      obj = allocate
      obj.parse(buffer)
      obj
    end

    def self.dump(*args)
      new(*args).dump
    end

    def dump(body_size=0)
      buffer = Buffer.of_size(5 +  body_size)
      buffer.write(self.message_type)
      buffer.write_int32(4 + body_size)
      yield buffer
      raise DumpError  unless buffer.at_end?
      return buffer.content
    end

    def parse(buffer)
      buffer.position = 5
      yield buffer
      raise ParseError, buffer.inspect unless buffer.at_end?
    end
  end

  class UnknownMessageType < Message
    def parse(buffer)
      raise PGError, "unable to parse message type: #{buffer.content.inspect}" 
    end
  end

  class Authentification < Message
    register_message_type 'R'
    attr_reader :auth_type

    AuthTypeMap = {}

    def self.create(buffer)
      buffer.position = 5
      authtype = buffer.read_int32
      klass = AuthTypeMap.fetch(authtype, UnknownAuthType)
      obj = klass.allocate
      obj.parse(buffer)
      obj
    end

    def self.register_auth_type(type)
      AuthTypeMap[type] = self
    end

    def parse(buffer)
      super do
        @auth_type = buffer.read_int32 
        yield if block_given?
      end
    rescue ParseError => e
      raise PGError, "unsupported authentication type: #{@auth_type} buffer: #{buffer.content[buffer.position..-1].inspect}", e.backtrace
    end
  end

  class UnknownAuthType < Authentification
  end

  class AuthentificationOk < Authentification 
    register_auth_type 0
  end

  class AuthentificationClearTextPassword < Authentification 
    register_auth_type 3
  end

  class AuthentificationMD5Password < Authentification 
    register_auth_type 5
    attr_accessor :salt

    def parse(buffer)
      super do
        @salt = buffer.read(4)
      end
    end
  end

  class PasswordMessage < Message
    register_message_type 'p'

    def initialize(password)
      @password = password
    end

    def dump
      super(@password.size + 1) do |buffer|
        buffer.write_cstring(@password)
      end
    end
  end

  class ParameterStatus < Message
    register_message_type 'S'

    def parse(buffer)
      super do
        buffer.read_cstring
        buffer.read_cstring
      end
    end
  end

  class BackendKeyData < Message
    register_message_type 'K'

    def parse(buffer)
      super do
        buffer.read(8)
      end
    end
  end

  class ReadyForQuery < Message
    register_message_type 'Z'
    attr_reader :backend_transaction_status_indicator

    def parse(buffer)
      super do
        @backend_transaction_status_indicator = buffer.read_byte
      end
    end
  end

  class DataRow < Message
    register_message_type 'D'
    attr_reader :columns

    def parse(buffer)
      super do
        n_cols = buffer.read_int16
        @columns = (1..n_cols).collect {
          len = buffer.read_int32 
          if len == -1
            nil
          else
            buffer.read(len)
          end
        }
      end
    end
  end

  class CommandComplete < Message
    register_message_type 'C'
    attr_reader :cmd_tag

    def parse(buffer)
      super do
        @cmd_tag = buffer.read_cstring
      end
    end
  end

  class EmptyQueryResponse < Message
    register_message_type 'I'
  end

  module NoticeErrorMixin
    attr_reader :field_values

    def parse(buffer)
      super do
        break if buffer.read_byte == 0
        @field_values = []
        while buffer.position < buffer.size-1
          @field_values << buffer.read_cstring
        end
        terminator = buffer.read_byte
        raise ParseError unless terminator == 0
      end
    end
  end

  class NoticeResponse < Message
    register_message_type 'N'
    include NoticeErrorMixin
  end

  class ErrorResponse < Message
    register_message_type 'E'
    include NoticeErrorMixin
  end

  class Query < Message
    register_message_type 'Q'
    attr_accessor :query

    # :nocov:
    if RUBY_VERSION < '2'
      def initialize(query)
        @query = String.new(query).force_encoding('BINARY')
      end
    # :nocov:
    else
      def initialize(query)
        @query = query.b
      end
    end

    def dump
      super(@query.size + 1) do |buffer|
        buffer.write_cstring(@query)
      end
    end
  end

  class RowDescription < Message
    register_message_type 'T'
    attr_reader :fields

    class FieldInfo < Struct.new(:name, :oid, :attr_nr, :type_oid, :typlen, :atttypmod, :formatcode); end

    def parse(buffer)
      super do
        nfields = buffer.read_int16
        @fields = nfields.times.map do
          FieldInfo.new(
            buffer.read_cstring,
            buffer.read_int32,
            buffer.read_int16,
            buffer.read_int32,
            buffer.read_int16,
            buffer.read_int32,
            buffer.read_int16
          )
        end
      end
    end
  end

  class StartupMessage < Message
    PROTO_VERSION = 3 << 16 # 196608

    def initialize(params)
      @params = params
    end

    def dump
      params = @params.reject{|k,v| v.nil?}
      sz = params.inject(4 + 4) {|sum, kv| sum + kv[0].size + 1 + kv[1].size + 1} + 1

      buffer = Buffer.of_size(sz)
      buffer.write_int32(sz)
      buffer.write_int32(PROTO_VERSION)
      params.each_pair do |key, value| 
        buffer.write_cstring(key)
        buffer.write_cstring(value)
      end
      buffer.write_byte(0)
      buffer.content
    end
  end

  class Terminate < Message
    register_message_type 'X'
  end
end

require_relative 'buffer'
