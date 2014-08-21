require 'bundler/gem_tasks'

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new

desc 'Run RSpec code examples with simplecov'
task :cov do
  ENV['THUNDER_COV'] = 'true'
  Rake::Task[:spec].invoke
end

require 'cucumber/rake/task'
Cucumber::Rake::Task.new :features

task default: [:spec]
