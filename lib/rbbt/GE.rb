require 'rbbt/util/pkg_config'

module GE
  extend PKGConfig

  self.load_cfg(%w(datadir), "datadir: #{File.join(ENV['HOME'], 'GE', 'data')}\n")
end

