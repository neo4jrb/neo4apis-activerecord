lib = File.expand_path('../lib/', __FILE__)
$LOAD_PATH.unshift lib unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |s|
  s.name     = 'neo4apis-activerecord'
  s.version  = '0.5.0'
  s.required_ruby_version = '>= 1.9.1'

  s.authors  = 'Brian Underwood'
  s.email    = 'public@brian-underwood.codes'
  s.homepage = 'https://github.com/neo4jrb/neo4apis-activerecord/'
  s.summary = 'An ruby gem to import SQL data to neo4j using activerecord'
  s.license = 'MIT'
  s.description = <<-EOF
A ruby gem using neo4apis to make importing SQL data to neo4j easy
  EOF

  s.require_path = 'lib'
  s.files = Dir.glob('{bin,lib,config}/**/*') + %w(README.md Gemfile neo4apis-activerecord.gemspec)

  s.add_dependency('neo4apis', '~> 0.5.0')
  s.add_dependency('activerecord', '~> 4.0')
end
