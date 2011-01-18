require 'rbbt-util'
require 'rbbt/GE'

module GEO
  GDS_URL="ftp://ftp.ncbi.nih.gov/pub/geo/DATA/SOFT/GDS_full/#DATASET#_full.soft.gz"
  GPL_URL="ftp://ftp.ncbi.nih.gov/pub/geo/DATA/SOFT/by_platform/GPL999/#PLATFORM#_family.soft.gz"

  DATA_STORE=File.join(GE.datadir, 'GEO')


  LIB_DIR = File.join(File.expand_path(File.dirname(__FILE__)),'../../../share/lib/R')
  MA_R    = File.join(LIB_DIR, 'MA.R')

  def self.GDS_parse_header(header)
    subsets = {}

    header.split("^SUBSET")[1..-1].collect do |chunk|
      description = chunk.match(/!subset_description\s*=\s*(.*)/i)[1]
      samples     = chunk.match(/!subset_sample_id\s*=\s*(.*)/i)[1].split(/, /)
      type        = chunk.match(/!subset_type\s*=\s*(.*)/i)[1]
      

      subsets[type] ||= {}
      subsets[type][description] ||= {}
      subsets[type][description] = samples
    end


    {:value_type => header.match(/!dataset_value_type\s*=\s*(.*)/i)[1],
    :channel_count => header.match(/!dataset_channel_count\s*=\s*(.*)/i)[1],
    :platform => header.match(/!dataset_platform\s*=\s*(.*)/i)[1],
    :reference_series => header.match(/dataset_reference_series\s*=\s*(.*)/i)[1],
    :subsets => subsets}
  end

  def self.GDS(dataset)
    gds = Open.open(GDS_URL.sub('#DATASET#', dataset))
    header = ""

    while line = gds.readline
      break if line =~ /\!dataset_table_begin/i
      raise "No dataset table found" if gds.eof
      header << line
    end

    info = GDS_parse_header header

    file = File.join(DATA_STORE, info[:platform], dataset, 'values')
    FileUtils.mkdir_p File.dirname file unless File.exists? File.dirname(file)
    File.open(file, 'w') do |f|
      f.write "#"
      while l = gds.readline
        break if l =~ /!dataset_table_end/i
        f.puts l
      end
    end

    info[:datafile] = file

    info
  end

  def self.GPL_parse_header(header)
    {:organism => header.match(/!Platform_organism\s*=\s*(.*)/i)[1],
    :count => header.match(/!Platform_data_row_count\s*=\s*(.*)/i)[1]}
  end

  def self.GPL(platform)
    gpl = Open.open(GPL_URL.sub('#PLATFORM#', platform))
    header = ""
    while line = gpl.readline
      break if line =~ /\!platform_table_begin/i
      raise "No platform table found" if gpl.eof
      header << line
    end

    file = File.join(DATA_STORE, platform, 'codes')
    FileUtils.mkdir_p File.dirname file unless File.exists? File.dirname(file)
    File.open(file, 'w') do |f|
      f.write "#"
      while l = gpl.readline
        break if l =~ /!platform_table_end/i
        f.puts l
      end
    end

    info = GPL_parse_header header
    info[:codefile] = file

    info
  end

  #{{{ Processing
  
  def self.analyse(datafile, codes, channel, type, main, contrast)
  end

  def self.process(dataset, subset, main_group = nil)
    info       = GDS(dataset)
    codes      = TSV.new(GPL(dataset)[:codefile], :extra => []).keys
    main_group = guess_main_group(info[:subsets][subset]) if main_group.nil?

    main = info[:subsets][subset][main_group]
    main = info[:subsets][subset][main_group]

    analyze(info[:datafile], codes, info[:channel_count], info[:value_type], info[:subsets][subset], main) 
  end

end
