# typed: strict
# frozen_string_literal: true

module Raikou
  class OrderDirection < T::Enum
    enums do
      Asc = new
      Desc = new
    end

    sig { returns(Symbol) }
    def to_sym
      case self
      when Asc
        :asc
      when Desc
        :desc
      else
        T.absurd(self)
      end
    end

    sig { params(value: T.any(Symbol, String, OrderDirection)).returns(OrderDirection) }
    def self.from_value(value)
      case value
      when OrderDirection
        value
      when :asc, "asc"
        Asc
      when :desc, "desc"
        Desc
      else
        raise InvalidOrderError, "Invalid order direction: #{value}"
      end
    end
  end
end
