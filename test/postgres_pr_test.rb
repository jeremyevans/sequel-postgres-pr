# encoding: binary

gem 'minitest'
ENV['MT_NO_PLUGINS'] = '1' # Work around stupid autoloading of plugins
require 'minitest/global_expectations/autorun'

require_relative '../lib/postgres-pr/connection'

class MockConnection < PostgresPR::Connection
  class MockSocket < StringIO
    def <<(_); end
  end
  def _connection(host, port)
    MockSocket.new(host)
  end
end

VALID_PASSWORD_AUTH = "R\x00\x00\x00\b\x00\x00\x00\x03R\x00\x00\x00\b\x00\x00\x00\x00K\x00\x00\x00\f\x00\x00\x05\xE9@\x18o\x80Z\x00\x00\x00\x05I"
INVALID_PASSWORD_AUTH = "R\x00\x00\x00\b\x00\x00\x00\x03E\x00\x00\x00dSFATAL\x00C28000\x00Mpassword authentication failed for user \"sequel_test\"\x00Fauth.c\x00L273\x00Rauth_failed\x00\x00"

VALID_MD5_AUTH = "R\x00\x00\x00\f\x00\x00\x00\x05*Y\x15\xA3R\x00\x00\x00\b\x00\x00\x00\x00K\x00\x00\x00\f\x00\x00\xA4\xA8M\xEC\xF7\x14Z\x00\x00\x00\x05I"
INVALID_MD5_AUTH = "R\x00\x00\x00\f\x00\x00\x00\x05\xD2\xDAi\x80E\x00\x00\x00dSFATAL\x00C28000\x00Mpassword authentication failed for user \"sequel_test\"\x00Fauth.c\x00L273\x00Rauth_failed\x00\x00"
UNKNOWN_AUTH = "R\x00\x00\x00\b\x00\x00\x00\x01"

STARTUP_ERROR = "E\x00\x00\x00NSERROR\x00C42601\x00Msyntax error at or near \"S\"\x00P1\x00Fscan.l\x00L911\x00Rbase_yyerror\x00\x00"
UNEXPECTED_STARTUP_MESSAGE = "D\x00\x00\x00\v\x00\x01\x00\x00\x00\x011"
UNEXPECTED_AFTER_STARTUP_MESSAGE= "R\x00\x00\x00\b\x00\x00\x00\x03R\x00\x00\x00\b\x00\x00\x00\x00K\x00\x00\x00\f\x00\x00\x05\xE9@\x18o\x80Z\x00\x00\x00\x05IR\x00\x00\x00\b\x00\x00\x00\x03"

TRANSACTION_STATUS_CHECKS = "R\x00\x00\x00\b\x00\x00\x00\x00K\x00\x00\x00\f\x00\x01\x1F\xA2,\xA43\x9AZ\x00\x00\x00\x05IT\x00\x00\x00!\x00\x01?column?\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x17\x00\x04\xFF\xFF\xFF\xFF\x00\x00D\x00\x00\x00\v\x00\x01\x00\x00\x00\x011C\x00\x00\x00\vSELECT\x00Z\x00\x00\x00\x05IC\x00\x00\x00\nBEGIN\x00Z\x00\x00\x00\x05TE\x00\x00\x00NSERROR\x00C42601\x00Msyntax error at or near \"S\"\x00P1\x00Fscan.l\x00L911\x00Rbase_yyerror\x00\x00Z\x00\x00\x00\x05EC\x00\x00\x00\rROLLBACK\x00Z\x00\x00\x00\x05I"
UNKNOWN_TRANSACTION_STATUS = "R\x00\x00\x00\b\x00\x00\x00\x03R\x00\x00\x00\b\x00\x00\x00\x00K\x00\x00\x00\f\x00\x00\x05\xE9@\x18o\x80Z\x00\x00\x00\x05J"

IGNORED_NOTICE = "R\x00\x00\x00\b\x00\x00\x00\x00K\x00\x00\x00\f\x00\x01Vz\xD3\x90\xAC\xEDZ\x00\x00\x00\x05IN\x00\x00\x00\x80SNOTICE\x00VNOTICE\x00C00000\x00Mtest notice\x00WPL/pgSQL function inline_code_block line 1 at RAISE\x00Fpl_exec.c\x00L3907\x00Rexec_stmt_raise\x00\x00C\x00\x00\x00\aDO\x00Z\x00\x00\x00\x05I"

describe PostgresPR::Connection do
  def db(stream, password)
    MockConnection.new(stream, 5432, nil, nil, 'sequel_test', 'sequel_test', password)
  end

  it "should raise error for password authentication without password" do
    proc{db(VALID_PASSWORD_AUTH, nil)}.must_raise PostgresPR::PGError
  end

  it "should raise error for password authentication without invalid password" do
    proc{db(INVALID_PASSWORD_AUTH, '')}.must_raise PostgresPR::PGError
  end

  it "should work for password authentication with valid password" do
    db(VALID_PASSWORD_AUTH, '').must_be_kind_of MockConnection
  end

  it "should raise error for md5 authentication without password" do
    proc{db(VALID_MD5_AUTH, nil)}.must_raise PostgresPR::PGError
  end

  it "should raise error for md5 authentication without invalid password" do
    proc{db(INVALID_MD5_AUTH, '')}.must_raise PostgresPR::PGError
  end

  it "should work for md5 authentication with valid password" do
    db(VALID_MD5_AUTH, '').must_be_kind_of MockConnection
  end

  it "should raise error for unknown authentication type" do
    proc{db(UNKNOWN_AUTH, '')}.must_raise PostgresPR::PGError
  end

  it "should handle errors during startup" do
    proc{db(STARTUP_ERROR, nil)}.must_raise PostgresPR::PGError
  end

  it "should raise for unexpected messages during startup" do
    proc{db(UNEXPECTED_STARTUP_MESSAGE, nil)}.must_raise PostgresPR::PGError
  end

  it "should raise for unexpected messages after startup" do
    proc{db(VALID_PASSWORD_AUTH + "S\x00\x00\x00\x15is_superuser\x00off\x00", nil)}.must_raise PostgresPR::PGError
  end

  it "should use a TCP or Unix socket depending on given host/port" do
    begin
      unix = Struct.new(:path)
      tcp = Struct.new(:host, :port)
      PostgresPR::Connection.const_set(:UNIXSocket, unix)
      PostgresPR::Connection.const_set(:TCPSocket, tcp)
      c = Class.new(PostgresPR::Connection).allocate

      s = c.send(:_connection, nil, 5432)
      s.must_be_kind_of unix
      s.path.must_equal "/tmp/.s.PGSQL.5432"

      PostgresPR::Connection.const_set(:RUBY_PLATFORM, 'windows')
      s = c.send(:_connection, nil, 5432)
      s.must_be_kind_of tcp
      s.host.must_equal "localhost"
      s.port.must_equal 5432

      s = c.send(:_connection, '/foo', 5432)
      s.must_be_kind_of unix
      s.path.must_equal "/foo"

      s = c.send(:_connection, 'localhost', 5432)
      s.must_be_kind_of tcp
      s.host.must_equal "localhost"
      s.port.must_equal 5432
    ensure
      [:UNIXSocket, :TCPSocket, :RUBY_PLATFORM].each do |const|
        PostgresPR::Connection.send(:remove_const, const) rescue nil
      end
    end
  end

  it "should correct handling transaction status" do
    c = db(TRANSACTION_STATUS_CHECKS, '')
    c.transaction_status.must_equal 0
    c.async_exec 'SELECT 1'
    c.transaction_status.must_equal 0
    c.async_exec 'BEGIN'
    c.transaction_status.must_equal 2
    proc{c.async_exec 'S'}.must_raise PostgresPR::PGError
    c.transaction_status.must_equal 3
    c.async_exec 'ROLLBACK'
    c.transaction_status.must_equal 0
  end

  it "should handle unknown transaction status" do
    c = db(UNKNOWN_TRANSACTION_STATUS, '')
    c.transaction_status.must_equal 4
  end

  it "should raise error for unexpected messages after startup" do
    c = db(UNEXPECTED_AFTER_STARTUP_MESSAGE, '')
    proc{c.async_exec('SELECT 1')}.must_raise PostgresPR::PGError
  end

  it "should ignore notice messages" do
    c = db(IGNORED_NOTICE, '')
    c.async_exec("DO $$BEGIN RAISE NOTICE 'test notice'; END$$")
  end
end

describe PostgresPR::Buffer do
  before do
    @buf = PostgresPR::Buffer.new('123'.dup)
  end

  it ".of_size should raise for invalid size" do
    proc{PostgresPR::Buffer.of_size(-1)}.must_raise(ArgumentError)
  end

  it "#position= should raise for invalid position" do
    proc{@buf.position = -1}.must_raise(ArgumentError)
    proc{@buf.position = 5}.must_raise(ArgumentError)
  end

  it "#read should raise for read beyond size" do
    proc{@buf.read(5)}.must_raise(PostgresPR::Buffer::EOF)
  end

  it "#write should raise for write beyond size" do
    proc{@buf.write('12345')}.must_raise(PostgresPR::Buffer::EOF)
  end

  it "#copy_from_stream should raise for invalid size" do
    proc{@buf.copy_from_stream(StringIO.new, -1)}.must_raise(ArgumentError)
  end

  it "#copy_from_stream should raise too much read" do
    stream = StringIO.new
    def stream.read(_); "12" end
    proc{@buf.copy_from_stream(stream, 1)}.must_raise(RuntimeError)
  end

  it "#write_cstring should raise for strings including NUL" do
    proc{@buf.write_cstring("\0")}.must_raise(ArgumentError)
  end

  it "#read_cstring should raise for buffer not containing NUL" do
    proc{@buf.read_cstring}.must_raise(PostgresPR::Buffer::Error)
  end
end

describe PostgresPR::Message do
  it ".read should raise for invalid length" do
    proc{PostgresPR::Message.read(StringIO.new("R\x00\x00\x00\x00"))}.must_raise PostgresPR::ParseError
  end

  it ".read should raise for too short input" do
    proc{PostgresPR::Message.read(StringIO.new("R\x00\x00\x00"))}.must_raise EOFError
  end

  it "#dump should raise if the buffer is not fully consumed" do
    proc{PostgresPR::Authentification.new.dump(1){}}.must_raise PostgresPR::DumpError
  end

  it "#parse should raise if the buffer is not fully consumed" do
    proc{PostgresPR::Message.new.parse(PostgresPR::Buffer.new("R\x00\x00\x00\x051")){}}.must_raise PostgresPR::ParseError
  end

  it "UnknownMessageType.parse should raise" do
    proc{PostgresPR::UnknownMessageType.allocate.parse(PostgresPR::Buffer.new('123'))}.must_raise PostgresPR::PGError
  end

  it "ErrorResponse#parse should handle empty buffers" do
    PostgresPR::ErrorResponse.read(PostgresPR::Buffer.new("\E\x00\x00\x00\x05\0")).field_values.must_be_nil
  end

  it "ErrorResponse#parse should raise for invalid terminator" do
    proc{PostgresPR::ErrorResponse.read(PostgresPR::Buffer.new("\E\x00\x00\x00\x071\0\1"))}.must_raise PostgresPR::ParseError
  end
end
