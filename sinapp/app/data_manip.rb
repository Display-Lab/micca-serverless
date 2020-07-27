require 'tempfile'
require 'csv'

class DataManip
  EXPECTED_CSV_HEADER = "time,group,measure,numerator,denominator\n"
  def self.verify_header(tempfile)
    headline = tempfile.readline
    tempfile.rewind

    return headline == EXPECTED_CSV_HEADER
  end

  def self.append_ascribee(tempfile, ascribee)
    table = CSV.read(tempfile, headers: true)
    table["ascribee"]=ascribee
    return table.to_csv
  end
end
