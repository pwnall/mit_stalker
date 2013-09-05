require File.expand_path('./helper', File.dirname(__FILE__))


class MitStalkerTest < Minitest::Test
  def fixture(name)
    File.read File.join(File.dirname(__FILE__), 'fixtures', name)
  end

  def test_finger
    assert_equal nil, MitStalker.finger('root', 'nosuchhostname.com'),
                 'Invalid hostname'

    result = MitStalker.finger 'no_such_user', 'linux.mit.edu'
    assert_operator(/no_such_user/, :=~, result,
                    "The finger response looks incorrect")

    begin
      MitStalker.finger_timeout = 1

      start_time = Time.now
      result = MitStalker.finger 'no_such_user', 'web.mit.edu'
      assert_equal nil, result, 'Invalid timeout result'
      assert_in_delta Time.now - start_time, 1, 0.2, 'Bad timeout duration'
    ensure
      MitStalker.finger_timeout = 10
    end
  end

  def test_full_name
    assert_equal 'Srinivas Devadas',
                 MitStalker.full_name_from_user_name('devadas'),
                 'normalized'
    assert_equal 'Srinivas Devadas',
                 MitStalker.full_name_from_user_name('Devadas'),
                 'Capital letter in user name'
    assert_equal nil, MitStalker.full_name_from_user_name('no_user')
  end

  def test_web_query
    response = MitStalker.web_query('Srinivas Devadas')
    assert_match(/<html>.*<\/html>/m, response, 'Did not return raw HTML')
    assert_match(/Student data loaded as of .*, Staff data loaded as of/,
                 response, 'Did not query the directory')
    assert_match(/Devadas, Srinivas/, response,
                 'Did not issue the correct query')
  end

  def test_parse_webdir_no_response
    assert_equal [],
                 MitStalker.parse_webdir_response(fixture('no_response.html'))
  end

  def test_parse_webdir_single_response
    response = MitStalker.parse_webdir_response fixture('single_response.html')
    assert_equal 1, response.length, 'Response should have 1 user'

    assert_equal 'Costan, Victor Marius', response.first[:name]
    assert_equal 'costan@MIT.EDU', response.first[:email]
    assert_equal '381 Cardinal Medeiros Ave', response.first[:address]
    assert_equal 'Electrical Eng & Computer Sci', response.first[:department]
    assert_equal 'School Of Engineering', response.first[:school]
    assert_equal 'G', response.first[:year]
    assert_equal 'http://www.costan.us', response.first[:url]
  end

  def test_parse_webdir_multiple_responses
    response = MitStalker.parse_webdir_response fixture('multi_response.html')
    assert_equal 219, response.length, 'Response should have 219 users'

    response.each do |user|
      assert_operator(/Li/, :=~, user[:name], "Name doesn't match query")
      assert_operator(/li/i, :=~, user[:alias], "Alias doesn't match query")
      assert_operator(/^alias=/i, :=~, user[:alias],
                      "Alias doesn't look right")
    end
  end

  def test_name_vector
    ['Victor-Marius Costan', 'Victor Marius Costan', 'Costan, Victor-Marius',
     'Costan, Victor Marius'].each do |name|
      assert_equal ['Costan', 'Marius', 'Victor'], MitStalker.name_vector(name)
    end
  end

  def test_refine_webdir_response_by_name
    MitStalker.expects(:web_query).with('alias=Y-li8').
        returns(fixture('single_response.html')).once

    multi_response = MitStalker.parse_webdir_response(
        fixture('multi_response.html'))
    user = MitStalker.refine_webdir_response_by_name multi_response,
                                                     'Yau Yee Li'
    assert_equal 'costan@MIT.EDU', user[:email], 'Wrong user information'
  end

  def test_refine_webdir_response_by_email
    MitStalker.expects(:web_query).with('alias=V-costan').
               returns(fixture('single_response.html')).once
    MitStalker.expects(:web_query).with('alias=X-zhao1').
               returns(fixture('single_response2.html')).once

    mixed_response =
        MitStalker.parse_webdir_response fixture('mixed_response.html')
    user = MitStalker.refine_webdir_response_by_email mixed_response,
                                                      'xamyzhao'
    assert user, 'No user returned'
    assert_equal 'Zhao, Xiaoyu', user[:name]
  end

  def test_flip_full_name
    assert_equal 'Victor Marius Costan',
                 MitStalker.flip_full_name('Costan, Victor Marius'), 'flipped'
    assert_equal 'Victor Marius Costan',
                 MitStalker.flip_full_name('Victor Marius Costan'), 'canonical'
  end

  def test_from_user_name
    assert_equal nil, MitStalker.from_user_name('no_such_user')

    info = MitStalker.from_user_name 'devadas'
    assert info, 'No info returned'
    assert_equal 'Devadas, Srinivas', info[:name]

    info = MitStalker.from_user_name 'Devadas'
    assert info, 'No info returned'
    assert_equal 'Devadas, Srinivas', info[:name], 'capitalized user name'

    info = MitStalker.from_user_name 'nickolai'
    assert info, 'No info returned'
    assert_equal 'Zeldovich, Nickolai', info[:name]
    assert_equal 'Nickolai Zeldovich', info[:full_name]
  end
end
