require File.join(File.expand_path(File.dirname(__FILE__)), '../..', 'test_helper.rb')
require 'rbbt/GE/GEO'

class TestClass < Test::Unit::TestCase
  def test_GDS
    assert_equal 'GPL999', GEO.GDS('GDS750')[:platform]
  end

  def test_GPL
    assert_equal 'Saccharomyces cerevisiae', GEO.GPL('GPL999')[:organism]
    assert TSV.new(GEO.GPL('GPL999')[:code_file]).fields.include? "Ensembl Gene ID"
  end

  def test_normalize
    dataset = 'GDS750'
    gene    = "YPR191W"
    id      = "6079"

    platform   = GEO.GDS(dataset)[:platform]
    translated = GEO.normalize(platform, ["YPR191W"]).first.first

    assert_equal id, translated
  end

  def test_analyze_single
    dataset = 'GDS750'
    info = GEO.GDS(dataset)

    assert GE.analyze(info[:data_file], info[:subsets]["agent"]["tunicamycin"] ).read =~ /1234/;
  end

  def test_analyze_contrast
    dataset = 'GDS750'
    info = GEO.GDS(dataset)
    outfile = File.join(File.dirname(info[:data_file]), 'results')
    key_field = TSV.headers(GEO.GPL(info[:platform])[:code_file]).first

    TmpFile.with_file do |f|
      GE.analyze(info[:data_file], info[:subsets]["agent"]["tunicamycin"], info[:subsets]["agent"]["DTT"], false, f, key_field);
      assert File.exists? f
      FileUtils.rm f
    end
  end

  def test_process_subset
    dataset = 'GDS750'
    subset  = 'agent'
    id      = "6079"
    info = GEO.GDS(dataset)
    outfile = File.join(File.dirname(info[:data_file]), 'results')
    key_field = TSV.headers(GEO.GPL(info[:platform])[:code_file]).first

    TmpFile.with_file do |f|
      GEO.process_subset(dataset, subset, nil, f)
      assert File.exists? f
      FileUtils.rm f
    end

    t = GEO.process_subset(dataset, subset, 'tunicamycin')
    assert File.exists? File.join(File.dirname(info[:data_file]), 'analyses/subset.agent.tunicamycin')
    d = GEO.process_subset(dataset, subset, 'DTT')
    assert File.exists? File.join(File.dirname(info[:data_file]), 'analyses/subset.agent.DTT')

    assert_in_delta t[id]["p.values"], - d[id]["p.values"], 0.0001
  end
end

