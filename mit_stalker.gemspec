# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{mit_stalker}
  s.version = "1.0.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 1.2") if s.respond_to? :required_rubygems_version=
  s.authors = ["Victor Costan"]
  s.date = %q{2009-09-29}
  s.description = %q{Fetches publicly available information about MIT students.}
  s.email = %q{victor@zergling.net}
  s.extra_rdoc_files = ["CHANGELOG", "LICENSE", "README.textile", "lib/mit_stalker.rb"]
  s.files = ["CHANGELOG", "LICENSE", "Manifest", "README.textile", "Rakefile", "lib/mit_stalker.rb", "test/fixtures/multi_response.txt", "test/fixtures/no_response.txt", "test/fixtures/single_response.txt", "test/mit_stalker_test.rb", "mit_stalker.gemspec"]
  s.homepage = %q{http://github.com/costan/mit_stalker}
  s.rdoc_options = ["--line-numbers", "--inline-source", "--title", "Mit_stalker", "--main", "README.textile"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{zerglings}
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{Fetches publicly available information about MIT students.}
  s.test_files = ["test/mit_stalker_test.rb"]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<echoe>, [">= 3.1.1"])
      s.add_development_dependency(%q<flexmock>, [">= 0.8.6"])
    else
      s.add_dependency(%q<echoe>, [">= 3.1.1"])
      s.add_dependency(%q<flexmock>, [">= 0.8.6"])
    end
  else
    s.add_dependency(%q<echoe>, [">= 3.1.1"])
    s.add_dependency(%q<flexmock>, [">= 0.8.6"])
  end
end
