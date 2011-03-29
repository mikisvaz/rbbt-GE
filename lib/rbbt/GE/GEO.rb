require 'rbbt-util'
require 'rbbt/GE'
require 'rbbt/sources/organism'
require 'rbbt/util/resource'
require 'yaml'

module GEO
  extend Resource
  data_module self

  def self.platform_info(platform)
    YAML.load(self[platform]['info.yaml'].produce.read)
  end

  def self.dataset_info(dataset)
    YAML.load(self[dataset]['info.yaml'].produce.read)
  end

  module SOFT

    GDS_URL="ftp://ftp.ncbi.nih.gov/pub/geo/DATA/SOFT/GDS_full/#DATASET#_full.soft.gz"
    GPL_URL="ftp://ftp.ncbi.nih.gov/pub/geo/DATA/SOFT/by_platform/#PLATFORM#/#PLATFORM#_family.soft.gz"
    GSE_URL="ftp://ftp.ncbi.nih.gov/pub/geo/DATA/SOFT/by_series/#SERIES#/#SERIES#_family.soft.gz"

    GSE_INFO = {
      :title         => "!Series_title",
      :channel_count => "!Sample_channel_count",
      :value_type    => "!Series_value_type",
      :platform      => "!Series_platform_id",
      :description   => "!Series_summary*",      # Join with \n 
    }
    
    GDS_INFO = {
      :DELIMITER        => "\\^SUBSET",
      :value_type       => "!dataset_value_type",
      :channel_count    => "!dataset_channel_count",
      :platform         => "!dataset_platform",
      :reference_series => "!dataset_reference_series",
      :description      => "!dataset_description",
    }

    GDS_SUBSET_INFO = {
      :DELIMITER        => "!subset_.*|!dataset_value_type",
      :description => "!subset_description",
      :samples     => "!subset_sample_id*",
      :type        => "!subset_type",
    }

    GPL_INFO = { 
      :DELIMITER     => "!platform_table_begin",
      :organism      => "!Platform_organism",
      :count         => "!Platform_data_row_count"
    }

    # When multiple matches select most common, unless join is choosen
    def self.find_field(header, field, join = false)
      md = header.match(/#{ Regexp.quote field }\s*=\s*(.*)/i)
      return nil if md.nil? or md.captures.empty?

      case join
      when false, nil
        counts = Hash.new(0)
        md.captures.sort_by{|v| counts[v] += 1}.first
      when true
        md.captures * "\n"
      else
        md.captures * join
      end
    end

    def self.get_info(header, info)
      result = {}

      info.each do |key, field|
        next if key == :DELIMITER
        if field =~ /(.*)\*(.*)(\*)?$/
          value = find_field(header, $1, $2.empty? ? true : $2)
          value = value.to_i.to_s == value ? value.to_i : value
          if $3
            result[key] = value.split(',')
          else
            result[key] = value
          end
        else
          value = find_field(header, field, false)
          value = value.to_i.to_s == value ? value.to_i : value
          result[key] = value
        end
      end

      if result.empty?
        nil
      else
        result
      end
    end

    def self.parse_header(stream, info)
      header = ""
      while line = stream.readline
        header << line
        break if line =~ /^#{info[:DELIMITER]}/i
        raise "Delimiter not found" if stream.eof
      end

      get_info(header, info)
    end

    def self.guess_id(organism, codes, max = 5000)
      field_counts = {}

      num_keys = codes.keys.length
      max = num_keys if num_keys < max
      identifiers = Organism.identifiers(organism).tsv
      new_fields = codes.fields.collect do |field|
        values = codes.slice(field).values.flatten[0..max].uniq.compact

        best = Organism.guess_id(organism, values, identifiers)
        if best[1].length > values.length.to_f * 0.5 
          field_counts[best.first] = best.last.length
          best.first
        else
          "UNKNOWN: " << field
        end
      end

      best = Organism.guess_id(organism, values, identifiers)
      if best[1].length > max * 0.5 
        field_counts[best.first] = best.last.length
        new_key_field = best.first
      else
        new_key_field = nil
      end

      [new_key_field, new_fields, field_counts.sort_by{|field,counts| counts}.collect{|field,counts| field}.last]
    end

    def self.guess_id(organism, codes)
      num_codes = codes.size
      best = nil
      best_count = 0
      new_fields = []
      field_counts = {}
      TmpFile.with_file(codes.to_s) do |codefile|

        codes.all_fields.each_with_index do |field,i|
          TmpFile.with_file do |values|
            Open.write(values, CMD.cmd("cat #{ codefile }|cut -f #{ i + 1 }| tr '|' '\\n'|grep [[:alpha:]]|sort -u").read)

            new_field, count =  Organism.guess_id(organism, values) 
            field_counts[new_field] = count
            Log.debug "Original field: #{ field }. New: #{new_field}. Count: #{ count }/#{num_codes}"
            new_fields << (count > (num_codes > 20000 ? 20000 : num_codes).to_f * 0.5 ? new_field : "UNKNOWN(#{ field })")
            if count > best_count
              best = new_field
              best_count = count
            end
          end
        end

      end

      field_counts.delete(new_fields.first)
      [best, new_fields, field_counts.sort_by{|field, counts| counts}.collect{|field, counts| field}]
    end

    #{{{ GPL

    def self.GPL(platform, directory)
      FileUtils.mkdir_p directory unless File.exists? directory

      code_file = File.join(directory, 'codes') 
      info_file = File.join(directory, 'info.yaml') 

      stream = Open.open(GPL_URL.gsub('#PLATFORM#', platform), :nocache => false)

      info = parse_header(stream, GPL_INFO)
      info[:code_file]      = code_file
      info[:data_directory] = directory

      Log.medium "Producing code file for #{ platform }"
      codes = TSV.new stream, :fix => proc{|l| l =~ /^!platform_table_end/i ? nil : l}, :header_hash => ""
      Log.low "Original fields: #{codes.key_field} - #{codes.fields * ", "}"
      stream.force_close

      best_field, all_new_fields, order = guess_id(Organism.organism(info[:organism]), codes)

      new_key_field, *new_fields = all_new_fields

      new_key_field = codes.key_field if new_key_field =~ /^UNKNOWN/

      codes.key_field = new_key_field.dup 
      codes.fields = new_fields.collect{|f| f.dup}

      Log.low "New fields: #{codes.key_field} - #{codes.fields * ", "}"

      Open.write(code_file, codes.reorder(:key, order).to_s(:sort, true))
      Open.write(info_file, info.to_yaml)

      info
    end

    def self.dataset_subsets(stream)
      text = ""
      while not (line = stream.gets) =~ /!dataset_table_begin/
        text << line
      end

      subsets = text.split(/\^SUBSET/).collect do |chunk|
        get_info(chunk, GDS_SUBSET_INFO)
      end

      info = {}
      subsets.each do |subset|
        type = subset[:type]
        description = subset[:description]
        samples = subset[:samples]
        info[type] ||= {}
        info[type][description] = samples
      end

      info
    end

    def self.GDS(dataset, directory)
      FileUtils.mkdir_p directory unless File.exists? directory

      value_file = File.join(directory, 'values') 
      info_file = File.join(directory, 'info.yaml') 

      stream = Open.open(GDS_URL.gsub('#DATASET#', dataset), :nocache => true)

      info = parse_header(stream, GDS_INFO)
      info[:value_file]      = value_file
      info[:data_directory] = directory

      info[:subsets] = dataset_subsets(stream)

      Log.medium "Producing values file for #{ dataset }"
      values = TSV.new stream, :fix => proc{|l| l =~ /^!dataset_table_end/i ? nil : l.gsub(/null/,'NA').gsub(/\t(?:-|.)?(\t|$)/,"\tNA\1")}, :header_hash => ""
      key_field, *ignore = TSV.parse_header(GEO[info[:platform]]['codes'].open)
      values.key_field = key_field

      samples = values.fields.select{|f| f =~ /GSM/}

      Open.write(value_file, values.slice(samples).to_s(:sort, true))
      Open.write(info_file, info.to_yaml)

      info
    end
  end
end

