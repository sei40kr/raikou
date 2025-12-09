# typed: strict
# frozen_string_literal: true

require "base64"
require "json"

module Raikou
  # Represents a pagination cursor that encodes the position in a result set
  class Cursor
    extend T::Sig

    sig { returns(T::Hash[String, T.untyped]) }
    attr_reader :values

    sig { params(values: T::Hash[String, T.untyped]).void }
    def initialize(values)
      @values = values
    end

    sig { returns(String) }
    def encode
      json = JSON.generate(@values)
      Base64.urlsafe_encode64(json, padding: false)
    end

    sig { params(encoded: String).returns(Cursor) }
    def self.decode(encoded)
      json = Base64.urlsafe_decode64(encoded)
      values = T.cast(JSON.parse(json), T::Hash[String, T.untyped])
      new(values)
    rescue ArgumentError, JSON::ParserError => e
      raise InvalidCursorError, "Invalid cursor format: #{e.message}"
    end
  end
end
