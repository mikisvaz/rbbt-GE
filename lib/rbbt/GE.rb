require 'rbbt/util/pkg_config'
require 'rbbt/R/main'

module GE
  extend PKGConfig

  LIB_DIR = File.join(File.expand_path(File.dirname(__FILE__)),'../../share/lib/R')
  MA    = File.join(LIB_DIR, 'MA.R')

  self.load_cfg(%w(datadir), "datadir: #{File.join(ENV['HOME'], 'GE', 'data')}\n")

  def self.run_R(command)
    cmd = "source('#{MA}');" << command
    R.run(cmd)
  end

  def self.r_format(list)
    case
    when list.nil?
      "NULL"
    when Array === list
      "c(#{list.collect{|e| r_format e} * ", "})"
    when (String === list and list === list.to_i.to_s) 
      list.to_i
    when (String === list and list === list.to_f.to_s) 
      list.to_f
    when TrueClass === list
      "TRUE"
    when FalseClass === list
      "FALSE"
    else
      "'#{list.to_s}'"
    end
  end

  def self.analyze(datafile,  main, contrast = nil, log2 = false, outfile = nil, key_field = nil)
    FileUtils.mkdir_p File.dirname(outfile) unless File.exists? File.dirname(outfile)
    GE.run_R("rbbt.GE.process(#{ r_format datafile }, main = #{r_format(main)}, contrast = #{r_format(contrast)}, log2=#{ r_format log2 }, outfile = #{r_format outfile}, key.field = #{r_format key_field})")
  end

end

