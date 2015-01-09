require 'spec_helper'
require 'neo4apis/table_resolver'

describe Neo4Apis::TableResolver do
  subject do
    Object.new.extend(Neo4Apis::TableResolver)
  end
  describe '#identify_table_name' do
    %w(posts post Posts Post).each do |table_name|
      it "identifies #{table_name} table for Post class" do
        expect(subject.identify_table_name([table_name], 'Post')).to eq(table_name)
      end
    end

    ['foo_bars', 'foo_bar', 'FooBars', 'FooBar', 'Foo Bars', 'Foo Bar', 'Foo bar', 'foo Bar', 'fooBar', 'fooBars'].each do |table_name|
      it "identifies #{table_name} table for FooBar class" do
        expect(subject.identify_table_name([table_name], 'FooBar')).to eq(table_name)
      end
    end


    it 'returns nil if nothing is identifiable' do
      expect { subject.identify_table_name(['foo'], 'Post') }.to raise_error(Neo4Apis::TableResolver::UnfoundTableError)
    end
  end

  describe '#identify_primary_key' do
    %w(id PostId post_id Post_id Postid postId postID uuid).each do |primary_key|
      it "identifies #{primary_key} primary key for Post class" do
        expect(subject.identify_primary_key([primary_key], 'Post')).to eq(primary_key)
      end
    end

    it 'returns nil if nothing is identifiable' do
      expect { subject.identify_primary_key(['foo_id'], 'Post') }.to raise_error(Neo4Apis::TableResolver::UnfoundPrimaryKeyError)
    end
  end
end
