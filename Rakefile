require "rake/clean"

CLEAN.include %w'*.gem rdoc coverage'

desc "Build the gem"
task :gem do
  sh %{gem build sequel-postgres-pr.gemspec}
end

# This assumes you have sequel checked out in ../sequel, and that
# spec_postgres is setup to run Sequel's PostgreSQL specs.
desc "Run tests with coverage"
task :test_cov do
  ENV['RUBYLIB'] = "#{__dir__}/lib:#{ENV['RUBYLIB']}"
  ENV['RUBYOPT'] = "-r #{__dir__}/test/coverage_helper.rb #{ENV['RUBYOPT']}"
  ENV['SIMPLECOV_COMMAND_NAME'] = "postgres-pr"
  sh %'#{FileUtils::RUBY} -I ../sequel/lib test/postgres_pr_test.rb'

  ENV['RUBYLIB'] = "#{__dir__}/test/lib:#{ENV['RUBYLIB']}"
  ENV['SIMPLECOV_COMMAND_NAME'] = "sequel"
  sh %'cd ../sequel && #{FileUtils::RUBY} spec/adapter_spec.rb postgres'
end

desc "Run CI tests"
task :spec_ci do
  sh %'#{FileUtils::RUBY} test/postgres_pr_test.rb'
  ENV['SEQUEL_POSTGRES_URL'] = "postgres://localhost/?user=postgres&password=postgres"
  sh %'cd sequel && #{FileUtils::RUBY} #{'-Ku' if RUBY_VERSION < '2'} -I lib -I ../lib spec/adapter_spec.rb postgres'
end
