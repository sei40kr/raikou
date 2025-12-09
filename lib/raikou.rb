# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"
require "active_record"

require_relative "raikou/version"
require_relative "raikou/direction"
require_relative "raikou/order_direction"
require_relative "raikou/cursor"
require_relative "raikou/page"
require_relative "raikou/paginator"
require_relative "raikou/active_record_extension"

module Raikou
  extend T::Sig

  class Error < StandardError; end
  class InvalidOrderError < Error; end
  class InvalidCursorError < Error; end
end

# Extend ActiveRecord::Relation with pagination methods
ActiveRecord::Relation.include(Raikou::ActiveRecordExtension)
