# typed: strict
# frozen_string_literal: true

module Raikou
  class Direction < T::Enum
    enums do
      Forward = new
      Backward = new
    end
  end
end
