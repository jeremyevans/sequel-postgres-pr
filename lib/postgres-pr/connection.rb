#
# Author:: Michael Neumann
# Copyright:: (c) 2005 by Michael Neumann
# License:: Same as Ruby's or BSD
#

require 'socket'

module PostgresPR
  class Connection
    CONNECTION_OK = -1

    class << self
      alias connect new
    end

    # Returns one of the following statuses:
    #
    #   PQTRANS_IDLE    = 0 (connection idle)
    #   PQTRANS_INTRANS = 2 (idle, within transaction block)
    #   PQTRANS_INERROR = 3 (idle, within failed transaction)
    #   PQTRANS_UNKNOWN = 4 (cannot determine status)
    #
    # Not yet implemented is:
    #
    #   PQTRANS_ACTIVE  = 1 (command in progress)
    #
    def transaction_status
      case @transaction_status
      when 73 # I
        0
      when 84 # T
        2
      when 69 # E
        3
      else
        4
      end
    end

    def initialize(host, port, _, _, database, user, password)
      @conn = _connection(host, port)
      @transaction_status = nil
      @params = {}
    
      @conn << StartupMessage.new('user' => user, 'database' => database).dump

      while true
        msg = Message.read(@conn)

        case msg
        when AuthentificationClearTextPassword
          check_password!(password)
          @conn << PasswordMessage.new(password).dump
        when AuthentificationMD5Password
          check_password!(password)
          require 'digest/md5'
          @conn << PasswordMessage.new("md5#{Digest::MD5.hexdigest(Digest::MD5.hexdigest(password + user) << msg.salt)}").dump
        when ErrorResponse
          raise PGError, msg.field_values.join("\t")
        when ReadyForQuery
          @transaction_status = msg.backend_transaction_status_indicator
          break
        when AuthentificationOk, NoticeResponse, ParameterStatus, BackendKeyData
          # ignore
        when UnknownAuthType
          raise PGError, "unhandled authentication type: #{msg.auth_type}"
        else
          raise PGError, "unhandled message type"
        end
      end
    end

    def finish
      check_connection_open!
      @conn.shutdown
      @conn = nil
    end

    def async_exec(sql)
      check_connection_open!
      @conn << Query.dump(sql)

      rows = []
      errors = []

      while true
        msg = Message.read(@conn)
        case msg
        when DataRow
          rows << msg.columns
        when CommandComplete
          cmd_tag = msg.cmd_tag
        when ReadyForQuery
          @transaction_status = msg.backend_transaction_status_indicator
          break
        when RowDescription
          fields = msg.fields
        when ErrorResponse
          errors << msg
        when NoticeResponse, EmptyQueryResponse
          # ignore
        else
          raise PGError, "unhandled message type"
        end
      end

      raise(PGError, errors.map{|e| e.field_values.join("\t") }.join("\n")) unless errors.empty?

      Result.new(fields||[], rows, cmd_tag)
    end

    # Escape bytea values.  Uses historical format instead of hex
    # format for maximum compatibility.
    def escape_bytea(str)
      str.gsub(/[\000-\037\047\134\177-\377]/n){|b| "\\#{sprintf('%o', b.each_byte{|x| break x}).rjust(3, '0')}"}
    end
    
    # Escape strings by doubling apostrophes.  This only works if standard
    # conforming strings are used.
    def escape_string(str)
      str.gsub("'", "''")
    end

    def block(timeout=nil)
    end

    def status
      CONNECTION_OK
    end

    private

    def check_password!(password)
      raise PGError, "no password specified" unless password
    end

    # Doesn't check the connection actually works, only checks that
    # it hasn't been closed.
    def check_connection_open!
      raise(PGError, "connection already closed") if @conn.nil?
    end

    def _connection(host, port)
      if host.nil?
        if RUBY_PLATFORM =~ /mingw|win/i
          TCPSocket.new('localhost', port)
        else
          UNIXSocket.new("/tmp/.s.PGSQL.#{port}")
        end
      elsif host.start_with?('/')
        UNIXSocket.new(host)
      else
        TCPSocket.new(host, port)
      end
    end
  end
end

require_relative 'message'
require_relative 'result'
