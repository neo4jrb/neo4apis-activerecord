guard :rubocop, cli: '--auto-correct --display-cop-names' do
  watch(/.+\.rb$/)
  watch(/(?:.+\/)?\.rubocop.*\.yml$/) { |m| File.dirname(m[0]) }
end

guard :rspec, cmd: 'rspec' do
  watch(/^spec\/.+_spec\.rb$/)
  watch(/^lib\/(.+)\.rb$/)     { |m| "spec/lib/#{m[1]}_spec.rb" }
  watch('spec/spec_helper.rb')  { 'spec' }
end
