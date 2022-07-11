spec = Gem::Specification.new do |s|
  s.name = 'sequel-postgres-pr'
  s.version = "0.9.0"
  s.summary = 'A pure Ruby interface to the PostgreSQL (>= 7.4) database'
  s.requirements << 'PostgreSQL >= 7.4'
  s.files = Dir['lib/**/*']
  s.require_path = 'lib'
  s.authors = ["Jeremy Evans", "Michael Neumann"]
  s.email = "code@jeremyevans.net"
  s.homepage = "https://github.com/jeremyevans/postgres-pr"
  s.license = 'Ruby'
  s.required_ruby_version = ">= 1.9.2"
end
