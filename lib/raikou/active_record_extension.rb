# typed: strict
# frozen_string_literal: true

module Raikou
  # Extension module for ActiveRecord::Relation to add pagination methods
  module ActiveRecordExtension
    extend T::Sig
    extend T::Helpers
    include Kernel

    requires_ancestor { ActiveRecord::Relation }

    sig do
      params(
        per_page: Integer,
        direction: Direction,
        cursor: T.nilable(String)
      ).returns(Page[T.untyped])
    end
    def paginate(per_page:, direction:, cursor: nil)
      order_hash = extract_order_hash
      paginator = Paginator[T.untyped].new(self, order: order_hash, per_page: per_page)
      paginator.paginate(cursor: cursor, direction: direction)
    end

    private

    sig { returns(T::Hash[String, OrderDirection]) }
    def extract_order_hash
      order_hash = {}

      order_values.each do |order_value|
        case order_value
        when Arel::Nodes::Ascending
          # Handle Arel ascending nodes
          column_name = order_value.expr.name.to_s
          order_hash[column_name] = OrderDirection::Asc
        when Arel::Nodes::Descending
          # Handle Arel descending nodes
          column_name = order_value.expr.name.to_s
          order_hash[column_name] = OrderDirection::Desc
        when Symbol
          # Handle symbol-based order (defaults to ASC)
          order_hash[order_value.to_s] = OrderDirection::Asc
        when Hash
          # Handle hash-based order like { created_at: :desc }
          order_value.each do |col, dir|
            order_hash[col.to_s] = OrderDirection.from_value(dir)
          end
        else
          # Unsupported order format (String, Arel::Nodes::SqlLiteral, etc.)
          raise InvalidOrderError, "Unsupported order format: #{order_value.class}. Please use hash or symbol-based ordering."
        end
      end

      order_hash
    end
  end
end
