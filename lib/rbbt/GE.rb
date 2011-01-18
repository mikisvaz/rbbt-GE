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
end

