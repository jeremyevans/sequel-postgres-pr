spec = Gem::Specification.new do |s|
  s.name = 'sequel-postgres-pr'
  s.version = "0.9.0"
  s.summary = 'Pure Ruby driver for PostgreSQL, designed for use with Sequel'
  s.files = Dir['lib/**/*']
  s.require_path = 'lib'
  s.authors = ["Jeremy Evans", "Michael Neumann"]
  s.email = "code@jeremyevans.net"
  s.homepage = "https://github.com/jeremyevans/sequel-postgres-pr"
  s.license = 'Ruby'
  s.required_ruby_version = ">= 1.9.2"
end
