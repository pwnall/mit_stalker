# Fetch publicly available information about MIT students.

require 'socket'
require 'timeout'


# Fetch publicly available information about MIT students.
module MitStalker
  class <<self
    # The number of seconds to wait for a finger result.
    attr_accessor :finger_timeout
  end
  self.finger_timeout = 10

  # Issues a finger request to a server.
  #
  # Returns a string containing the finger response, or nil if something went
  # wrong.
  def self.finger(request, host)
    begin
      Timeout.timeout(self.finger_timeout) do
        client = TCPSocket.open host, 'finger'
        client.send request + "\n", 0    # 0 means standard packet
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
  # Returns a string containing the full name, or nil if the Athena username is
  # not recognized.
  def self.full_name_from_user_name(user_name)
    athena_data = finger user_name.downcase, 'linux.mit.edu'
    return nil if athena_data.nil?
    match = /(N|n)ame\: (.*)$/.match athena_data
    match and match[2].strip
  end

  # Parses a MIT directory response into users.
  #
  # Returns a (possibly empty) array of hashes, with one hash per user. A hash
  # has the directory information for the user, using symbols as keys, e.g.
  # {:name => 'Victor Costan', :year => '1'}
  def self.parse_mitdir_response(response)
    return [] if response.nil?

    lines = response.split("\r\n").reverse
    users = []
    user = {}
    lines.each do |line|
      if line.empty?
        users << user unless user.empty?
        user = {}
        next
      end

      match = /([^:]*):(.+)/.match line
      break unless match

      user[match[1].strip.downcase.gsub(' ', '_').to_sym] = match[2].strip
    end
    users
  end

  # Computes a name vector from a full name.
  #
  # The same name, in different formats, should yield the same vector. Different
  # names should yield different vectors.
  def self.name_vector(name)
    name.gsub(/\W/, ' ').gsub(/ +/, ' ').split.sort
  end

  # Narrows down a MIT directory response to a single user.
  #
  # Returns a single user information hash, or nil if no user has the given
  # full name.
  def self.refine_mitdir_response_by_name(users, full_name)
    vector = name_vector(full_name)
    user_base_info = users.find { |user| name_vector(user[:name]) == vector }
    return nil unless user_base_info

    # Don't make an extra request for the same info.
    return users.first if users.length == 1

    # Requesting by alias should return a single name.
    users = parse_mitdir_response finger(user_base_info[:alias],
                                         'mitdir.mit.edu')
    users and users.first
  end

  # Narrows down a MIT directory response to a single user.
  #
  # Returns a single user information hash, or nil if no user has the given
  # e-mail.
  def self.refine_mitdir_response_by_email(users, user_name)
    user_name = user_name.downcase
    users.each do |user|
      if user[:email]
        next unless user[:email].split('@').first.downcase == user_name
        users = parse_mitdir_response finger(user[:alias], 'mitdir.mit.edu')
        return users && users.first
      else
        users = parse_mitdir_response finger(user[:alias], 'mitdir.mit.edu')
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
      users = parse_mitdir_response finger(full_name, 'mitdir.mit.edu')
    else
      users = []
    end
    if users.empty?
      users = parse_mitdir_response finger(user_name, 'mitdir.mit.edu')
    end

    user = refine_mitdir_response_by_name(users, full_name) if full_name
    user = refine_mitdir_response_by_email(users, user_name) unless user
    return nil unless user

    user.merge :full_name => (full_name || flip_full_name(user[:name]))
  end
end
