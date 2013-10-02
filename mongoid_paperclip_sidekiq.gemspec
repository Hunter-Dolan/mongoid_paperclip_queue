Gem::Specification.new do |s|
  s.name = %q{mongoid_paperclip_sidekiq}
  s.version = "0.1.4"
 
  s.authors = ["Hunter Dolan"]
  s.summary = %q{Process your Paperclip attachments in the background using Mongoid and Sidekiq.}
  s.description = %q{Process your Paperclip attachments in the background using Mongoid and Sidekiq. Loosely based on delayed_paperclip and mongoid-paperclip.}
  s.email = %q{hunterhdolan@gmail.com}
  s.homepage = %q{http://github.com/kellym/mongoid_paperclip_sidekiq}

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")

  s.add_dependency 'paperclip', ["~> 3.5.1"]
  s.add_dependency 'redis-namespace'
  s.add_dependency 'mongoid', [">= 2.3.0"]
  s.add_dependency 'sidekiq'
  
end

