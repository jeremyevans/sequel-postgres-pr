class PostgresPR::Result
  def initialize(fields, rows, cmd_tag)
    @fields = fields
    @rows = rows
    @cmd_tag = cmd_tag
  end

  def ntuples
    @rows.size
  end

  def nfields
    @fields.size
  end

  def fname(index)
    @fields[index].name
  end

  def ftype(index)
    @fields[index].type_oid
  end

  def getvalue(tup_num, field_num)
    @rows[tup_num][field_num]
  end

  # free the result set
  def clear
    @fields = @rows = @cmd_tag = nil
  end

  # Returns the number of rows affected by the SQL command
  def cmd_tuples
    case @cmd_tag
    when /^INSERT\s+(\d+)\s+(\d+)$/, /^(DELETE|UPDATE|MOVE|FETCH)\s+(\d+)$/
      $2.to_i
    end
  end
end
