# Fetch publicly available information about MIT students.

require 'cgi'
require 'net/http'
require 'socket'
require 'timeout'

require 'nokogiri'


# Fetch publicly available information about MIT students.
module MitStalker
  class <<self
    # @return {Number} the number of seconds to wait for a finger result
    attr_accessor :finger_timeout
  end
  self.finger_timeout = 10

  # Issues a finger query to a server.
  #
  # @param {String} query the finger query (e.g., the username)
  # @param {String} host the DNS name of the finger server (e.g. "web.mit.edu")
  # @return {String} the finger response, or nil if something went wrong
  def self.finger(query, host)
    begin
      Timeout.timeout(self.finger_timeout) do
        client = TCPSocket.open host, 'finger'
        client.send query + "\n", 0    # 0 means standard packet
        result = client.readlines.join
        client.close

        return result
      end
    rescue Timeout::Error
      return nil
    rescue
      return nil
    end
  end

  # Retrieves an MIT student's full name, based on the Athena username.
  #
  # @param {String} user_name the Athena username to be looked up
  # @return {String} the student's full name, or nil if the Athena username is
  #     not found
  def self.full_name_from_user_name(user_name)
    athena_data = finger user_name.downcase, 'linux.mit.edu'
    return nil if athena_data.nil?
    match = /(N|n)ame\: (.*)$/.match athena_data
    match and match[2].strip
  end

  # Queries MIT's web directory.
  #
  # @param {String} the query the directory query (a username, full name, or
  #     alias)
  # @return {String} the raw HTML response, or nil if the server's response is
  #     not a 200
  def self.web_query(query)
    uri = URI.parse("http://web.mit.edu/bin/cgicso?options=general&query=" +
                    CGI.escape(query))
    http = Net::HTTP.new uri.host, uri.port
    request = Net::HTTP::Get.new uri.request_uri,
        'Accept' => 'text/html,application/xhtml+xml,application/xml',
        'Accept-Language' => 'en-US,en',
        'Cache-Control' => 'max-age=0',
        'Host' => 'web.mit.edu',
        'User-Agent' => 'Mozilla/5.0 (Macintosh; U; Intel Mac OS X; en) AppleWebKit/522+ (KHTML, like Gecko) Version/3.0 Safari/522.11'
    response = http.request request
    return nil unless response.kind_of?(Net::HTTPSuccess)
    response.body
  end

  # Parses a raw HTML response from MIT's Web directory into users.
  #
  # @param {String} response the raw HTML response from a MIT Web directory
  #     query
  # @return {Array<Hash<Symbol, String>>} one hash per user
  def self.parse_webdir_response(response)
    doc = Nokogiri::HTML response

    results = []
    doc.css('.dir pre').each do |pre|
      if doc.css('a').any? { |a| /^mailto:/i =~ a['href'] }
        # Single result.
        result = {}
        pre.inner_text.each_line do |line|
          key, value = *line.split(':', 2)
          next if key.nil?
          key.strip!
          value.strip!
          next if key.empty? or value.empty?
          result[key.to_sym] = value
        end
        results << result
      else
        # Multiple results.
        pre.css('a').each do |a|
          match = /\/bin\/cgicso\?query\=([^&]+)$/.match a['href']
          next unless match
          result = { alias: CGI.unescape(match[1]), name: a.inner_text }
          results << result
        end
      end
    end

    results
  end

  # Computes a name vector from a full name.
  #
  # The same name, in different formats, should yield the same vector.
  # Different names should yield different vectors.
  #
  # @param {String} name the full name to work on
  # @return {Array<String>} the name vector
  def self.name_vector(name)
    name.gsub(/\W/, ' ').gsub(/ +/, ' ').split.sort
  end

  # Narrows down a MIT directory response to a single user.
  #
  # Returns a single user information hash, or nil if no user has the given
  # full name.
  def self.refine_webdir_response_by_name(users, full_name)
    vector = name_vector full_name
    user_base_info = users.find { |user| name_vector(user[:name]) == vector }
    return nil unless user_base_info

    # Don't make an extra request for the same info.
    return users.first if users.length == 1

    # Requesting by alias should return a single name.
    users = parse_webdir_response web_query(user_base_info[:alias])
    users and users.first
  end

  # Narrows down a MIT directory response to a single user.
  #
  # Returns a single user information hash, or nil if no user has the given
  # e-mail.
  def self.refine_webdir_response_by_email(users, user_name)
    user_name = user_name.downcase
    users.each do |user|
      if user[:email]
        next unless user[:email].split('@').first.downcase == user_name
        users = parse_webdir_response web_query(user[:alias])
        return users && users.first
      else
        users = parse_webdir_response web_query(user[:alias])
        next unless users
        user = users.first
        if user[:email] and user[:email].split('@').first == user_name
          return user
        end
      end
    end
    nil
  end

  # Flips an official full-name (e.g. Costan, Victor-Marius) to its normal form.
  def self.flip_full_name(name)
    name.split(',', 2).map(&:strip).reverse.join(' ')
  end

  # Retrieves information about an MIT student from an Athena username.
  #
  # Returns a hash containing user information, or nil if the user was not
  # found.
  def self.from_user_name(user_name, finger_timeout=10)
    user_name = user_name.downcase
    full_name = full_name_from_user_name user_name

    if full_name
      users = parse_webdir_response web_query(full_name)
    else
      users = []
    end
    if users.empty?
      users = parse_webdir_response web_query(user_name)
    end

    user = refine_webdir_response_by_name(users, full_name) if full_name
    user = refine_webdir_response_by_email(users, user_name) unless user
    return nil unless user

    user.merge :full_name => (full_name || flip_full_name(user[:name]))
  end
end
