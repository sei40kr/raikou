# typed: strict
# frozen_string_literal: true

module Raikou
  # Represents a page of results with cursor-based pagination metadata
  class Page
    extend T::Sig
    extend T::Generic
    include Enumerable

    Elem = type_member { { upper: ActiveRecord::Base } }

    sig { returns(T::Array[Elem]) }
    attr_reader :records

    sig { returns(T::Boolean) }
    attr_reader :has_next_page

    sig { returns(T::Boolean) }
    attr_reader :has_previous_page

    sig { returns(T.nilable(String)) }
    attr_reader :last_cursor

    sig { returns(T.nilable(String)) }
    attr_reader :first_cursor

    sig do
      params(
        records: T::Array[Elem],
        has_next_page: T::Boolean,
        has_previous_page: T::Boolean,
        last_cursor: T.nilable(String),
        first_cursor: T.nilable(String)
      ).void
    end
    def initialize(records:, has_next_page:, has_previous_page:, last_cursor:, first_cursor:)
      @records = records
      @last_cursor = last_cursor
      @first_cursor = first_cursor
      @has_next_page = has_next_page
      @has_previous_page = has_previous_page
    end

    sig { returns(Integer) }
    def size
      @records.size
    end

    sig { returns(T::Boolean) }
    def empty?
      @records.empty?
    end

    sig do
      override
        .params(
          blk: T.nilable(T.proc.params(arg0: Elem).returns(T.untyped))
        )
        .returns(T.any(T::Enumerator[Elem], T.self_type))
    end
    def each(&blk)
      return @records.each unless blk

      @records.each(&blk)
      self
    end
  end
end
