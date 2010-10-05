module Postgres::Conversion
  # Encodes a string as bytea value.
  #
  # For encoding rules see:
  #   http://www.postgresql.org/docs/7.4/static/datatype-binary.html
  #
  # The historical bytea escape format is always used, for maximum compatibility.
  def encode_bytea(str)
    # each_byte used instead of [] for 1.9 compatibility
    str.gsub(/[\000-\037\047\134\177-\377]/){|b| "\\#{sprintf('%o', b.each_byte{|x| break x}).rjust(3, '0')}"}
  end

  # Decodes a bytea encoded string.
  #
  # For decoding rules see:
  #   http://www.postgresql.org/docs/7.4/static/datatype-binary.html
  #
  # Supports both the historical escape format and the new 9.0+ hex format.
  def decode_bytea(str)
    if str =~ /\A\\x/
      # PostgreSQL 9.0+ bytea hex format
      str[2..-1].gsub(/(..)/){|s| s.to_i(16).chr}
    else
      # Historical PostgreSQL bytea escape format
      str.gsub(/\\(\\|'|[0-3][0-7][0-7])/) {|s|
        if s.size == 2 then s[1,1] else s[1,3].oct.chr end
      }
    end
  end
end
