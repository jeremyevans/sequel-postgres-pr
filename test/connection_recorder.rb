# encoding: binary

require_relative '../lib/postgres-pr/postgres-compat'

class RecordedConnection < PostgresPR::Connection
  attr_reader :messages

  def _connection(host, port)
    messages = @messages
    conn = super
    conn.extend(Module.new do
      define_method(:read) do |bytes|
        str = super(bytes)
p [:read, str]
        messages << [:read, str] 
        str
      end

      define_method(:<<) do |str|
p  [:<<, str]
        messages << [:<<, str]
        super(str)
      end
    end)
    conn
  end

  def initialize(*args)
    @messages = []
    super
  rescue
    p socket_data
  end

  def socket_data
    messages.
      select{|m| m[0] == :read}.
      each_slice(3).
      select{|ms| ms[0][-1] != 'S'}.
      map{|ms| ms.map(&:last).join}.
      join
  end
end
