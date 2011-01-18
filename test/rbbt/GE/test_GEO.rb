require File.join(File.expand_path(File.dirname(__FILE__)), '../..', 'test_helper.rb')
require 'rbbt/GE/GEO'

class TestClass < Test::Unit::TestCase
  def _test_GDS
    assert_equal 'GPL999', GEO.GDS('GDS750')[:platform]
  end

  def _test_GPL
    assert_equal 'Saccharomyces cerevisiae', GEO.GPL('GPL999')[:organism]
    assert TSV.new(GEO.GPL('GPL999')[:code_file]).fields.include? "Ensembl Gene ID"
  end

  def _test_normalize
    dataset = 'GDS750'
    gene    = "YPR191W"
    id      = "6079"

    platform   = GEO.GDS(dataset)[:platform]
    translated = GEO.normalize(platform, ["YPR191W"]).first.first

    assert_equal id, translated
  end

  def test_analyze
    dataset = 'GDS750'
    info = GEO.GDS(dataset)

    p  info[:subsets]["agent"]["tunicamycin"]
    puts GEO.analyze(dataset, info[:subsets]["agent"]["tunicamycin"] ).read;
  end
end

