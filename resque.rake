require "resque/tasks"

task "resque:setup" do
  root_path = "#{File.dirname(__FILE__)}"
  require "#{root_path}/lib/job.rb"
end
