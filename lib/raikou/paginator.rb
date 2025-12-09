# typed: strict
# frozen_string_literal: true

module Raikou
  # Core pagination logic using seek method (cursor-based pagination)
  class Paginator
    extend T::Sig
    extend T::Generic

    Record = type_member { { upper: ActiveRecord::Base } }

    sig { returns(T.untyped) }
    attr_reader :relation

    sig { returns(T::Hash[String, OrderDirection]) }
    attr_reader :order_columns

    sig { returns(Integer) }
    attr_reader :per_page

    sig do
      params(
        relation: T.untyped,
        order: T::Hash[String, OrderDirection],
        per_page: Integer
      ).void
    end
    def initialize(relation, order:, per_page: 20)
      @relation = relation
      @order_columns = order
      @per_page = per_page

      validate_order!
    end

    sig { params(cursor: T.nilable(String), direction: Direction).returns(Page[Record]) }
    def paginate(cursor: nil, direction: Direction::Forward)
      scoped_relation = @relation

      # For backward pagination, reverse the order
      scoped_relation = scoped_relation.reverse_order if direction == Direction::Backward

      if cursor
        decoded_cursor = Cursor.decode(cursor)
        scoped_relation = apply_cursor_conditions(scoped_relation, decoded_cursor, direction)
      end

      # Fetch one extra record to determine if there's a next page
      records = scoped_relation.limit(@per_page + 1).to_a

      has_more = records.size > @per_page
      records = records.take(@per_page) if has_more

      last_cursor = nil
      first_cursor = nil

      # NOTE: We cannot rely on cursor presence alone to determine page existence.
      #  The record referenced by the cursor may have been deleted, so we must
      #  execute actual queries to verify if previous/next pages exist.
      if direction == Direction::Forward
        has_next_page = has_more
        has_previous_page = check_page_exists(records.first, Direction::Backward)
        first_record = records.first
        first_cursor = encode_cursor(first_record) if first_record
        last_record = records.last
        last_cursor = encode_cursor(last_record) if last_record
      else
        has_previous_page = has_more
        records.reverse!
        has_next_page = check_page_exists(records.last, Direction::Forward)
        first_record = records.first
        first_cursor = encode_cursor(first_record) if first_record
        last_record = records.last
        last_cursor = encode_cursor(last_record) if last_record
      end

      Page[Record].new(
        records: records,
        has_next_page: has_next_page,
        has_previous_page: has_previous_page,
        last_cursor: last_cursor,
        first_cursor: first_cursor
      )
    end

    private

    sig { void }
    def validate_order!
      raise InvalidOrderError, 'Order must be specified for cursor-based pagination' if @order_columns.empty?

      # Validate that all columns exist
      model = @relation.klass
      column_names.each do |column|
        unless model.column_names.include?(column)
          raise InvalidOrderError, "Column '#{column}' does not exist in #{model.table_name}"
        end
      end
    end

    sig { returns(T::Array[String]) }
    def column_names
      @order_columns.keys
    end

    sig { params(relation: T.untyped, cursor: Cursor, direction: Direction).returns(T.untyped) }
    def apply_cursor_conditions(relation, cursor, direction)
      # Build WHERE clause for cursor-based pagination using Arel
      condition = build_cursor_conditions_arel(relation, cursor, direction)
      relation.where(condition)
    end

    sig { params(relation: T.untyped, cursor: Cursor, direction: Direction).returns(T.untyped) }
    def build_cursor_conditions_arel(relation, cursor, direction)
      table = relation.klass.arel_table
      columns = column_names
      conditions = []

      columns.each_with_index do |_column, index|
        condition_parts = []

        # Add equality conditions for all previous columns
        (0...index).each do |i|
          col = T.must(columns[i])
          val = cursor.values[col]
          condition_parts << table[col].eq(val)
        end

        # Add comparison for current column
        col = T.must(columns[index])
        val = cursor.values[col]
        order_dir = T.must(@order_columns[col])

        comparison = build_comparison(table[col], val, order_dir, direction)
        condition_parts << comparison

        # Combine with AND
        combined = condition_parts.reduce { |acc, part| acc.and(part) }
        conditions << combined
      end

      # Combine all conditions with OR
      conditions.reduce { |acc, cond| acc.or(cond) }
    end

    sig do
      params(column: T.untyped, value: T.untyped, order_direction: OrderDirection,
             pagination_direction: Direction).returns(T.untyped)
    end
    def build_comparison(column, value, order_direction, pagination_direction)
      if pagination_direction == Direction::Forward
        order_direction == OrderDirection::Asc ? column.gt(value) : column.lt(value)
      else
        order_direction == OrderDirection::Asc ? column.lt(value) : column.gt(value)
      end
    end

    sig { params(record: Record).returns(String) }
    def encode_cursor(record)
      Cursor.new(extract_cursor_values(record)).encode
    end

    sig { params(record: T.nilable(Record), direction: Direction).returns(T::Boolean) }
    def check_page_exists(record, direction)
      return false if record.nil?

      relation = direction == Direction::Backward ? @relation.reverse_order : @relation
      cursor_values = extract_cursor_values(record)
      cursor = Cursor.new(cursor_values)
      relation = apply_cursor_conditions(relation, cursor, direction)
      relation.limit(1).exists?
    end

    sig { params(record: Record).returns(T::Hash[String, T.untyped]) }
    def extract_cursor_values(record)
      column_names.each_with_object({}) do |column, hash|
        hash[column] = record.public_send(column)
      end
    end
  end
end
