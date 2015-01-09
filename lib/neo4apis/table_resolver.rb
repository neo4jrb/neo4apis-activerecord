
module Neo4Apis
  module TableResolver
    class UnfoundTableError < StandardError
    end

    class UnfoundPrimaryKeyError < StandardError
    end

    def identify_table_name(tables, class_name)
      potential_table_comparisons = [class_name.tableize, class_name.tableize.singularize].map(&method(:standardize))
      tables.detect do |table_name|
        potential_table_comparisons.include?(standardize(table_name))
      end.tap do |found_name| # rubocop:disable Style/MultilineBlockChain
        fail UnfoundTableError, "Could not find a table for #{class_name}." if found_name.nil?
      end
    end

    def identify_primary_key(columns, class_name)
      (columns & %w(id uuid)).first
      columns.detect do |column|
        case standardize(column)
        when 'id', 'uuid', /#{standardize(class_name.singularize)}id/, /#{standardize(class_name.pluralize)}id/
          true
        when  
          true
        end
      end.tap do |found_key| # rubocop:disable Style/MultilineBlockChain
        fail UnfoundPrimaryKeyError, "Could not find a primary key for #{class_name}." if found_key.nil?
      end
    end

    private

    def standardize(string)
      string.downcase.gsub(/[ _]+/, '')
    end
  end
end
