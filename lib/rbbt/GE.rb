require 'rbbt/util/R'

module GE
  LIB_DIR = File.join(File.expand_path(File.dirname(__FILE__)),'../../share/lib/R')
  MA      = File.join(LIB_DIR, 'MA.R')

  def self.run_R(command)
    cmd = "\nsource('#{MA}');\n" << command
    R.run(cmd, :stderr => true)
  end

  def self.r_format(list, options = {})
    strings = options[:strings]
    case
    when list.nil?
      "NULL"
    when Array === list
      "c(#{list.collect{|e| r_format e, options} * ", "})"
    when (Fixnum === list or Float === list)
      list.to_s
    when (not strings and String === list and list === list.to_i.to_s) 
      list.to_i
    when (not strings and String === list and list === list.to_f.to_s) 
      list.to_f
    when TrueClass === list
      "TRUE"
    when FalseClass === list
      "FALSE"
    else
      "'#{list.to_s}'"
    end
  end

  def self.analyze(datafile,  main, contrast = nil, log2 = false, outfile = nil, key_field = nil, two_channel = nil)
    FileUtils.mkdir_p File.dirname(outfile) unless outfile.nil? or File.exists? File.dirname(outfile)
    GE.run_R("rbbt.GE.process(#{ r_format datafile }, main = #{r_format(main, :strings => true)}, contrast = #{r_format(contrast, :strings => true)}, log2=#{ r_format log2 }, outfile = #{r_format outfile}, key.field = #{r_format key_field}, two.channel = #{r_format two_channel})")
  end

  def self.barcode(datafile, outfile, factor = 2)
    FileUtils.mkdir_p File.dirname(outfile) unless outfile.nil? or File.exists? File.dirname(outfile)
    GE.run_R("rbbt.GE.barcode(#{ r_format datafile }, #{ r_format outfile }, #{ r_format factor })")
  end

end

