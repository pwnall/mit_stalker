# Author:: Victor Costan
# Copyright:: Copyright (C) 2009 Zergling.Net
# License:: MIT

require 'mit_stalker'
require 'test/unit'
require 'flexmock/test_unit'


class MitStalkerTest < Test::Unit::TestCase
  def fixture(name)
    File.read File.join(File.dirname(__FILE__), 'fixtures', name)
  end
  
  def test_finger
    assert_equal nil, MitStalker.finger('root', 'nosuchhostname.com'),
                 'Invalid hostname'
    
    result = MitStalker.finger('no_such_user', 'web.mit.edu')
    assert_operator(/matche?s? to your (query)|(request)/, :=~, result,
                    "The finger response looks incorrect")
  end
  
  def test_full_name
    assert_equal 'Srinivas Devadas',
                 MitStalker.full_name_from_user_name('devadas')
    assert_equal nil, MitStalker.full_name_from_user_name('no_user')
  end
  
  def test_parse_mitdir_no_response
    assert_equal [],
                 MitStalker.parse_mitdir_response(fixture('no_response.txt'))
  end
  
  def test_parse_mitdir_single_response
    response = MitStalker.parse_mitdir_response fixture('single_response.txt')
    assert_equal 1, response.length, 'Response should have 1 user'
    
    assert_equal 'Costan, Victor Marius', response.first[:name]
    assert_equal 'costan@MIT.EDU', response.first[:email]
    assert_equal 'G', response.first[:year]
    assert_equal 'Sidney-Pacific NW86-948C', response.first[:address]
    assert_equal 'http://www.costan.us', response.first[:url]
    assert_equal 'V-costan', response.first[:alias]
  end
  
  def test_parse_mitdir_multiple_responses
    response = MitStalker.parse_mitdir_response fixture('multi_response.txt')
    assert_equal 155, response.length, 'Response should have 110 users'
    
    response.each do |user|
      assert_operator(/Li/, :=~, user[:name], "Name doesn't match query")
      assert_operator(/li/i, :=~, user[:alias], "Alias doesn't match query")
    end
  end
  
  def test_name_vector
    ['Victor-Marius Costan', 'Victor Marius Costan', 'Costan, Victor-Marius',
     'Costan, Victor Marius'].each do |name|
      assert_equal ['Costan', 'Marius', 'Victor'], MitStalker.name_vector(name)
    end
  end
  
  def test_refine_mitdir_response
    flexmock(MitStalker).should_receive(:finger).with('Y-li16', 'web.mit.edu').
                         and_return(fixture('single_response.txt'))
                         
    multi_response =
        MitStalker.parse_mitdir_response fixture('multi_response.txt')
    user = MitStalker.refine_mitdir_response multi_response, 'Yan Ping Li'
    assert_equal 'costan@MIT.EDU', user[:email], 'Wrong user information'
  end
  
  def test_from_user_name
    assert_equal nil, MitStalker.from_user_name('no_such_user')
    
    info = MitStalker.from_user_name 'devadas'
    assert_equal 'Devadas, Srinivas', info[:name]
  end
end
