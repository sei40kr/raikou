# typed: false
# frozen_string_literal: true

require "spec_helper"

RSpec.describe Raikou::Cursor do
  describe "#initialize" do
    context "when given a hash of values" do
      it "stores the values" do
        values = { "id" => 123, "created_at" => "2024-01-01" }
        cursor = described_class.new(values)
        expect(cursor.values).to eq(values)
      end
    end
  end

  describe "#encode" do
    context "when given a single value" do
      it "returns a URL-safe Base64 string without padding" do
        cursor = described_class.new({ "id" => 123 })
        encoded = cursor.encode

        expect(encoded).to be_a(String)
        expect(encoded).not_to include("=") # no padding
        expect(encoded).to match(/\A[A-Za-z0-9_-]+\z/) # URL-safe characters only
      end
    end

    context "when given multiple values of different types" do
      it "returns a non-empty encoded string" do
        cursor = described_class.new({ "id" => 456, "name" => "test", "score" => 98.5 })
        encoded = cursor.encode

        expect(encoded).to be_a(String)
        expect(encoded).not_to be_empty
      end
    end
  end

  describe ".decode" do
    context "when given a valid encoded cursor" do
      it "returns a Cursor with the original values" do
        original_values = { "id" => 123, "created_at" => "2024-01-01" }
        original_cursor = described_class.new(original_values)
        encoded = original_cursor.encode

        decoded_cursor = described_class.decode(encoded)

        expect(decoded_cursor).to be_a(Raikou::Cursor)
        expect(decoded_cursor.values).to eq(original_values)
      end
    end

    context "when given an encoded cursor with multiple value types" do
      it "preserves all value types correctly" do
        original_values = { "id" => 789, "name" => "John", "active" => true, "score" => 85.5 }
        encoded = described_class.new(original_values).encode

        decoded_cursor = described_class.decode(encoded)

        expect(decoded_cursor.values["id"]).to eq(789)
        expect(decoded_cursor.values["name"]).to eq("John")
        expect(decoded_cursor.values["active"]).to eq(true)
        expect(decoded_cursor.values["score"]).to eq(85.5)
      end
    end

    context "when given an invalid Base64 string" do
      it "raises InvalidCursorError" do
        expect { described_class.decode("not-valid-base64!!!") }
          .to raise_error(Raikou::InvalidCursorError, /Invalid cursor format/)
      end
    end

    context "when given a valid Base64 string with invalid JSON" do
      it "raises InvalidCursorError" do
        invalid_json = Base64.urlsafe_encode64("not a json", padding: false)
        expect { described_class.decode(invalid_json) }
          .to raise_error(Raikou::InvalidCursorError, /Invalid cursor format/)
      end
    end

    context "when given an empty string" do
      it "raises InvalidCursorError" do
        expect { described_class.decode("") }
          .to raise_error(Raikou::InvalidCursorError, /Invalid cursor format/)
      end
    end
  end

  describe "encoding and decoding round-trip" do
    context "when encoding and then decoding various value combinations" do
      it "preserves all values accurately" do
        test_cases = [
          { "id" => 1 },
          { "id" => 999, "created_at" => "2024-12-09" },
          { "user_id" => 42, "post_id" => 100, "timestamp" => "2024-12-09T10:30:00Z" },
          { "score" => 99.99, "rank" => 1, "verified" => true },
        ]

        test_cases.each do |values|
          original = described_class.new(values)
          encoded = original.encode
          decoded = described_class.decode(encoded)

          expect(decoded.values).to eq(values)
        end
      end
    end
  end
end
