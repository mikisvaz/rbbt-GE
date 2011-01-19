require 'rbbt-util'
require 'rbbt/GE'
require 'rbbt/sources/organism'
require 'yaml'

module GEO
  GDS_URL="ftp://ftp.ncbi.nih.gov/pub/geo/DATA/SOFT/GDS_full/#DATASET#_full.soft.gz"
  GPL_URL="ftp://ftp.ncbi.nih.gov/pub/geo/DATA/SOFT/by_platform/#PLATFORM#/#PLATFORM#_family.soft.gz"

  DATA_STORE=File.join(GE.datadir, 'GEO')


  LIB_DIR = File.join(File.expand_path(File.dirname(__FILE__)),'../../../share/lib/R')
  MA_R    = File.join(LIB_DIR, 'MA.R')

  def self.GDS_parse_header(header)
    subsets = {}

    header.split("^SUBSET")[1..-1].collect do |chunk|
      description = chunk.match(/!subset_description\s*=\s*(.*)/i)[1]
      samples     = chunk.match(/!subset_sample_id\s*=\s*(.*)/i)[1].split(/,/).collect{|e| e.strip}
      type        = chunk.match(/!subset_type\s*=\s*(.*)/i)[1]


      subsets[type] ||= {}
      subsets[type][description] ||= {}
      subsets[type][description] = samples
    end


    { :value_type => header.match(/!dataset_value_type\s*=\s*(.*)/i)[1],
      :channel_count => header.match(/!dataset_channel_count\s*=\s*(.*)/i)[1],
      :platform => header.match(/!dataset_platform\s*=\s*(.*)/i)[1],
      :reference_series => header.match(/!dataset_reference_series\s*=\s*(.*)/i)[1],
      :description => header.match(/!dataset_description\s*=\s*(.*)/i)[1],
      :subsets => subsets}
  end

  def self.GDS(dataset, platform = nil)

    if platform.nil? or not File.exists? File.join(DATA_STORE, platform, dataset, 'info.yaml')
      gds = Open.open(GDS_URL.sub('#DATASET#', dataset))
      header = ""

      while line = gds.readline
        break if line =~ /\!dataset_table_begin/i
        raise "No dataset table found" if gds.eof
        header << line
      end

      info = GDS_parse_header header

      platform = info[:platform]

      directory = File.join(DATA_STORE, platform, dataset)
      data_file = File.join(directory, 'data') 
      info_file = File.join(directory, 'info.yaml') 

      info[:data_file]      = data_file
      info[:data_directory] = directory

      FileUtils.mkdir_p directory unless File.exists? directory
      Open.write(info_file, info.to_yaml)
    else
      directory = File.join(DATA_STORE, platform, dataset)
      data_file = File.join(directory, 'data') 
      info_file = File.join(directory, 'info.yaml') 

      info = YAML.load(Open.read(info_file)) 
    end

    if not File.exists? data_file

      values = TSV.new gds, :fix => proc{|l| l =~ /^!dataset_table_end/i ? nil : l.gsub(/null/,'NA').gsub(/\t(?:-|.)?(\t|$)/,"\tNA\1")}, :header_hash => ""

      good_fields = values.fields.select{|f| f =~ /^GSM/}
      values = values.slice good_fields

      platform_codes = TSV.key_order(GEO.GPL(info[:platform])[:code_file])
      Open.write(data_file, values.to_s(platform_codes))
    end

    info
  end

  def self.GPL_parse_header(header)
    {:organism => header.match(/!Platform_organism\s*=\s*(.*)/i)[1],
      :count => header.match(/!Platform_data_row_count\s*=\s*(.*)/i)[1]}
  end

  def self.guess_id(organism, codes)
    field_counts = {}

    new_fields = codes.fields.collect do |field|
      values = codes.slice(field).values.flatten.uniq

      best = Organism.guess_id(organism, values)
      if best[1].length > values.length.to_f * 0.5 
        field_counts[best.first] = best.last.length
        best.first
      else
        "UNKNOWN:" << field
      end
    end

    values = codes.keys.uniq
    best = Organism.guess_id(organism, values)
    if best[1].length > values.length.to_f * 0.5 
      field_counts[best.first] = best.last.length
      new_key_field = best.first
    else
      new_key_field = nil
    end

    [new_key_field, new_fields, field_counts.sort_by{|field,counts| counts}.collect{|field,counts| field}.last]
  end

  def self.GPL(platform)
    directory = File.join(DATA_STORE, platform)
    code_file = File.join(directory, 'codes') 
    info_file = File.join(directory, 'info.yaml') 

    if File.exists?(info_file) and File.exists?(code_file)
      YAML.load(Open.read(info_file))
    else
      FileUtils.mkdir_p directory unless File.exists? directory

      gpl = Open.open(GPL_URL.gsub('#PLATFORM#', platform))

      header = ""
      while line = gpl.readline
        p line
        break if line =~ /\!platform_table_begin/i
        raise "No platform table found" if gpl.eof
        header << line
      end

      info = GPL_parse_header header
      info[:code_file] = code_file
      info[:data_directory] = directory

      Log.low "Producing code file for #{ platform }"

      codes = TSV.new gpl, :fix => proc{|l| l =~ /^!platform_table_end/i ? nil : l}, :header_hash => ""
      Log.debug "Original fields: #{codes.key_field} - #{codes.fields * ", "}"

      new_key_field, new_fields, best_field = GEO.guess_id(Organism.organism(info[:organism]), codes) 
      codes.key_field = new_key_field.dup if new_key_field
      codes.fields = new_fields.collect{|f| f.dup}
      Log.debug "New fields: #{codes.key_field} - #{codes.fields * ", "}"

      Open.write(code_file, codes.to_s)
      Open.write(info_file, info.to_yaml)

      info
    end
  end

  def self.normalize(platform, genes, persistence = false)
    TSV.index(GEO.GPL(platform)[:code_file], :persistence => persistence).values_at *genes
  end

  #{{{ Processing
  MAIN_CUES = []
  def self.guess_main_group(subset)
    groups = subset.keys
    main   = groups.select{|v| MAIN_CUES.select{|c| v =~ c}.any?}.first
    main   || groups.sort.first
  end

  def self.process_subset(dataset, subset, main_group = nil, outfile = nil)
    info       = GDS(dataset)
    codes      = TSV.new(GPL(info[:platform])[:code_file], :extra => []).keys
    main_group = guess_main_group(info[:subsets][subset]) if main_group.nil?

    main = info[:subsets][subset][main_group]
    other =  info[:subsets].values.collect{|v| v.values}.flatten - main

    outfile ||= File.join(File.dirname(info[:data_file]), 'analyses', "subset.#{ subset }.#{main_group}")

    if not File.exists? outfile
      key_field = TSV.headers(GEO.GPL(info[:platform])[:code_file]).first
      GE.analyze(info[:data_file], main, other, !info[:value_type].match('log').nil?, outfile, key_field) 
    end

    TSV.new(outfile, :unique => true, :cast => proc{|e| e.nil? or e == "NA" ? nil : e.to_f})
  end
end
