require File.join(File.expand_path(File.dirname(__FILE__)), '../..', 'test_helper.rb')
require 'rbbt/GE/GEO'

class TestClass < Test::Unit::TestCase

  def test_control_sample
    assert GEO.control_samples('GDS750').include? "GSM16978"
  end

  def test_GDS
    assert_equal 'GPL999', GEO.dataset_info('GDS750')[:platform]
  end

  def test_GPL
    assert_equal 'Saccharomyces cerevisiae', GEO["GPL999/info.yaml"].yaml[:organism]
    assert_equal 'Homo sapiens', GEO["GPL570/info.yaml"].yaml[:organism]
    assert GEO.GPL999.codes.fields.include? "Associated Gene Name"
  end

  def test_analyze_contrast
    dataset = 'GDS750'
    info = GEO[dataset]['info.yaml'].yaml
    outfile = File.join(File.dirname(info[:value_file]), 'results')
    key_field = TSV.parse_header(GEO[info[:platform]].codes.open).key_field

    TmpFile.with_file do |f|
      GE.analyze(GEO[dataset]['values'].find, info[:subsets]["agent"]["tunicamycin"].split(','), info[:subsets]["agent"]["DTT"].split(','), false, f, key_field);
      assert File.exists? f
    end
  end


  def test_GSE
    gse = "GSE21029"
    info = GEO::SOFT.GSE(gse, "/tmp/gse")
    assert_equal "GPL570", info[:platform]
  end


  #{{{ NEW TEST

  def test_compare
    dataset = "GDS1479"
    field = "specimen"
    condition = "carcinoma in situ lesion"
    control = "normal mucosa"

    TmpFile.with_file do |path|
      GEO.compare(dataset, field, condition, control, path)
      assert File.exists? path
    end

    assert GEO[dataset].comparison[GEO.comparison_name field, condition, control].produce.exists?
  end


  def test_analyze_single
    dataset = 'GDS750'
    info = GEO.dataset_info(dataset)


    file = GEO[info[:value_file]].find
    samples = info[:subsets]["agent"]["DTT"].split ","

    TmpFile.with_file do |f|
      text = GE.analyze(file, samples).read
      assert text =~ /1234/;
      Open.write('/tmp/R_tsv', text)
      assert R.tsv(StringIO.new(text), :header_hash =>'', :grep => "WARNING", :invert_grep => true).length > 1000
      assert R.tsv(StringIO.new(text), :header_hash =>'', :grep => "WARNING", :invert_grep => true).fields.include? 'ratio'
    end
  end

  #{{{ FAILING

  def __test_normalize
    dataset = 'GDS750'
    gene    = "YPR191W"
    id      = "6079"

    platform   = GEO.GDS(dataset)[:platform]
    translated = GEO.normalize(platform, ["YPR191W"]).first.first

    assert_equal id, translated
  end



  def __test_process_subset
    dataset = 'GDS750'
    subset  = 'agent'
    id      = "6079"
    info = GEO[dataset]['info.yaml'].yaml
    outfile = File.join(File.dirname(info[:value_file]), 'results')
    key_field = TSV.parse_header(GEO[info[:platform]].codes.open).key_field

    TmpFile.with_file do |f|
      GEO.process_subset(dataset, subset, nil, f)
      puts Open.read(f)
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

