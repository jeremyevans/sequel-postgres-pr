Gem::Specification.new do |s|
  s.name = 'sequel-postgres-pr'
  s.version = "0.9.0"
  s.platform = Gem::Platform::RUBY
  s.extra_rdoc_files = ["README"]
  s.rdoc_options += ["--quiet", "--line-numbers", "--inline-source", '--title', 'sequel-postgres-pr: Pure Ruby driver for PostgreSQL, designed for use with Sequel', '--main', 'README.rdoc']
  s.licenses = ["MIT", "Ruby"]
  s.summary = 'Pure Ruby driver for PostgreSQL, designed for use with Sequel'
  s.authors = ["Jeremy Evans", "Michael Neumann"]
  s.email = "code@jeremyevans.net"
  s.homepage = "https://github.com/jeremyevans/sequel-postgres-pr"
  s.files = %w'README' + Dir['lib/**/*.rb']
  s.required_ruby_version = ">= 1.9.2"

  s.metadata          = { 
    'bug_tracker_uri'   => 'https://github.com/jeremyevans/sequel-postgres-pr/issues',
    'mailing_list_uri'  => 'https://github.com/jeremyevans/sequel-postgres-pr/discussions',
    "source_code_uri"   => 'https://github.com/jeremyevans/sequel-postgres-pr'
  }
end
