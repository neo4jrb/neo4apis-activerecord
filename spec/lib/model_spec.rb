require 'spec_helper'

describe 'Model import' do
  before(:all) do
    system('rm test.db')

    ActiveRecord::Base.establish_connection({
      adapter: :sqlite3,
      database: 'test.db'
    })

    User = Class.new(ActiveRecord::Base) do
      self.table_name = 'users'

      has_many :foo_records

      def self.name
        'User'
      end
    end

    FooRecord = Class.new(ActiveRecord::Base) do
      self.table_name = 'foo_records'

      belongs_to :user

      def self.name
        'FooRecord'
      end
    end

    ActiveRecord::Base.connection
  end

  let(:neo4j_url) { 'http://localhost:7474' }
  let(:neo4j_connection) { Neo4j::Session.open(:server_db, neo4j_url) }

  let(:neo4japis_activerecord_options) { {} }
  let(:neo4japis_activerecord) do
    Neo4Apis::ActiveRecord.model_importer(User)
    Neo4Apis::ActiveRecord.model_importer(FooRecord)

    Neo4Apis::ActiveRecord.new(neo4j_connection, neo4japis_activerecord_options)
  end



  let(:migration_classes) do
    [
      Class.new(ActiveRecord::Migration) do
        def change
          create_table :users do |table|
            table.string :username
          end
        end
      end,
      Class.new(ActiveRecord::Migration) do
        def change
          create_table :foo_records, id: false do |table|
            table.primary_key :my_uid

            table.references :user
          end
        end
      end
    ]
  end

  before do
    migration_classes.each {|c| c.new.migrate(:up) }
    clear_neo4j(neo4j_connection, neo4j_url)
  end

  after do
    migration_classes.reverse.each {|c| c.new.migrate(:down) }
  end

  # Helpers
  def new_query
    neo4j_connection.query
  end

  def model_count(model)
    new_query.match(u: :User).pluck('count(u)').first
  end

  let(:jimmy) { User.create(username: 'jimmy') }
  let(:bar) { FooRecord.create(my_uid: 'bar', user_id: jimmy.id) }

  it 'Can import an ActiveRecord row' do
    neo4japis_activerecord.batch do
      neo4japis_activerecord.import :User, jimmy
    end

    expect(model_count(:User)).to eq(1)

    user_node = neo4j_connection.query.match(u: :User).pluck(:u).first
    expect(user_node.props[:username]).to eq('jimmy')
  end

  context 'non-standard primary key' do
    it 'handles non-standard primary keys' do
      neo4japis_activerecord.batch do
        neo4japis_activerecord.import :FooRecord, bar
      end

      expect(neo4j_connection.uniqueness_constraints(:FooRecord)).to eq({property_keys: [[:my_uid]]})
    end
  end

  describe 'importing assocations' do
    it 'does not import assocations when not specified' do
      neo4japis_activerecord.batch do
        neo4japis_activerecord.import :FooRecord, bar
      end

      expect(new_query.match(foo: :FooRecord).match('foo--(user)').pluck('user')).to eq([])
    end

    context 'import_belongs_to' do
      let(:neo4japis_activerecord_options) { {import_belongs_to: true} }

      it 'does import assocations when specified' do
        neo4japis_activerecord.batch do
          neo4japis_activerecord.import :FooRecord, bar
        end

        expect(new_query.match(foo: :FooRecord).match('foo-[:user]->(user)').pluck('user.id')).to eq([jimmy.id])
      end
    end

    context 'import_has_many' do
      let(:neo4japis_activerecord_options) { {import_has_many: true} }

      it 'does import assocations when specified' do
        bar # Reference to create
        neo4japis_activerecord.batch do
          neo4japis_activerecord.import :User, jimmy
        end

        expect(new_query.match(user: :User).match('user-[:foo_records]->(foo_record)').pluck('foo_record.my_uid')).to eq([bar.my_uid])
      end
    end


  end

end

