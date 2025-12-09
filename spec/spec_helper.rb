# typed: false
# frozen_string_literal: true

require "raikou"
require "active_record"

# Setup in-memory SQLite database for testing
ActiveRecord::Base.establish_connection(
  adapter: "sqlite3",
  database: ":memory:"
)

# Define test schema
ActiveRecord::Schema.define do
  create_table :users, force: true do |t|
    t.string :name
    t.integer :age
    t.timestamps
  end

  create_table :posts, force: true do |t|
    t.string :title
    t.integer :user_id
    t.integer :likes
    t.timestamps
  end
end

# Define test models
class User < ActiveRecord::Base
  has_many :posts
end

class Post < ActiveRecord::Base
  belongs_to :user
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = "spec/examples.txt"
  config.disable_monkey_patching!
  config.warnings = true
  config.default_formatter = "doc" if config.files_to_run.one?
  config.order = :random
  Kernel.srand config.seed

  config.before(:each) do
    User.delete_all
    Post.delete_all
    # Reset AUTO_INCREMENT counters in SQLite
    ActiveRecord::Base.connection.execute("DELETE FROM sqlite_sequence WHERE name='users'")
    ActiveRecord::Base.connection.execute("DELETE FROM sqlite_sequence WHERE name='posts'")
  end
end
