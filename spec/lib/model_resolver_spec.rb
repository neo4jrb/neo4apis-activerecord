require 'spec_helper'
require 'neo4apis/model_resolver'

describe Neo4Apis::ModelResolver do
  subject do
    Object.new.extend(Neo4Apis::ModelResolver)
  end

  describe '#identify_foreign_key_bases' do
    {
      'foo_id' => 'foo',
      'FooId' => 'Foo',
      'Foo_id' => 'Foo',
      'foo_Id' => 'foo',
      'FooID' => 'Foo',
      'foo_ID' => 'foo'
    }.each do |column, foreign_key_base|
      it "identifies #{column} foreign key as #{foreign_key_base}" do
        expect(subject.identify_foreign_key_bases([column])).to eq([foreign_key_base])
      end
    end

    %w(fooi food foo_bar id).each do |column|
      it "identifies #{column} as not a foreign key" do
        expect(subject.identify_foreign_key_bases([column])).to eq([])
      end
    end
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
