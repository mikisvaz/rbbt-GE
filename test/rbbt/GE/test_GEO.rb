require File.join(File.expand_path(File.dirname(__FILE__)), '../..', 'test_helper.rb')
require 'rbbt/GE/GEO'

class TestClass < Test::Unit::TestCase
  def test_GDS
    assert_equal 'GPL999', GEO.GDS('GDS750')[:platform]
  end

 def test_GPL
    assert_equal 'Saccharomyces cerevisiae', GEO.GPL('GPL999')[:organism]
  end
end

