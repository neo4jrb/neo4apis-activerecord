require 'spec_helper'
require 'neo4apis/model_resolver'

describe Neo4Apis::ModelResolver do
  subject do
    Object.new.extend(Neo4Apis::ModelResolver)
  end

  describe '#get_model_class' do
    before do
      stub_const('Foo', Class.new(::ActiveRecord::Base))

      stub_const('Baz', Class.new(Foo))
    end

    it 'returns the class when given an ActiveRecord class' do
      expect(subject.get_model_class(Foo)).to eq(Foo)
      expect(subject.get_model_class(Baz)).to eq(Baz)
    end

    it 'loads the already defined model when appropriate' do
      expect(subject.get_model_class('foos')).to eq(Foo)
      expect(subject.get_model_class('foo')).to eq(Foo)

      expect(subject.get_model_class('bazs')).to eq(Baz)
      expect(subject.get_model_class('baz')).to eq(Baz)
    end

    it 'loads a ActiveRecord class when non is defined' do
      expect(subject.get_model_class('bars').name).to eq('Bar')
      expect(subject.get_model_class('bars').superclass).to eq(::ActiveRecord::Base)
    end
  end
end
