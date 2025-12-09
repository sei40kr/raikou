# typed: strict

# Shim for ActiveRecord::Relation methods not included in generated RBI
class ActiveRecord::Relation
  sig { returns(T::Array[T.untyped]) }
  def order_values; end
end
