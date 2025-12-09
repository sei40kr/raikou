# Raikou

Raikou is a cursor-based (seek method) pagination library for ActiveRecord with strong Sorbet type safety. Unlike traditional offset-based pagination, Raikou uses the seek method which is more efficient for large datasets and prevents issues like missing or duplicate records when data changes between page requests.

> [!WARNING]
> This project is work-in-progress and is not yet recommended for production use.

## Features

- **Seek-based pagination**: Efficient cursor-based pagination that works well with large datasets
- **Bi-directional navigation**: Navigate both forward and backward through result sets
- **Multi-column ordering**: Supports compound ordering for complex use cases
- **ActiveRecord integration**: Works seamlessly with your existing ActiveRecord models

## Requirements

- Ruby >= 3.0
- ActiveRecord >= 6.0

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'raikou'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install raikou
```

## Usage

> [!TIP]
> The combination of ordering columns must uniquely identify each record to ensure consistent pagination. As a best practice, include the primary key (usually `id`) as the last column in your ordering to guarantee uniqueness:
>
> ```ruby
> # Good: Ensures uniqueness by including id
> Post.order(created_at: :desc, id: :desc).paginate(per_page: 20, direction: Raikou::Direction::Forward)
>
> # Risky: created_at alone may not be unique
> Post.order(created_at: :desc).paginate(per_page: 20, direction: Raikou::Direction::Forward)
> ```

> [!TIP]
> To fully benefit from the seek method's performance advantages, you must create a database index on the combination of columns used in your ordering. Without proper indexes, the seek method may perform worse than offset-based pagination:
>
> ```ruby
> # For this pagination:
> Post.order(created_at: :desc, id: :desc).paginate(per_page: 20, direction: Raikou::Direction::Forward)
>
> # You need this index:
> add_index :posts, [:created_at, :id], order: { created_at: :desc, id: :desc }
> ```

> [!WARNING]
> **Cursor Visibility**: Cursors are Base64-encoded JSON objects, which means the values of ordering columns can be easily decoded by anyone with access to the cursor string. Do not use sensitive data (passwords, tokens, private keys, etc.) as ordering columns, as these values will be visible to clients.
>
> For example, a cursor like `eyJpZCI6MTB9` can be easily decoded to reveal `{"id":10}`.

### Basic Usage

```ruby
# First page (forward pagination)
page = User.order(id: :asc).paginate(per_page: 20, direction: Raikou::Direction::Forward)

page.records       # => Array of User records
page.has_next_page # => true/false
page.last_cursor   # => Encoded cursor string for next page

# Get next page using cursor
next_page = User.order(id: :asc).paginate(
  per_page: 20,
  cursor: page.last_cursor,
  direction: Raikou::Direction::Forward
)
```

### Backward Pagination

```ruby
# Navigate backward
previous_page = User.order(id: :asc).paginate(
  per_page: 20,
  cursor: current_page.first_cursor,
  direction: Raikou::Direction::Backward
)
```

### Descending Order

```ruby
page = User.order(created_at: :desc).paginate(per_page: 20, direction: Raikou::Direction::Forward)
```

### Multi-Column Ordering

For complex ordering requirements, you can use multiple columns. The combination of columns must uniquely identify records:

```ruby
# Order by category (ascending) then by created_at (descending)
page = Post.order(category: :asc, created_at: :desc, id: :asc).paginate(per_page: 20, direction: Raikou::Direction::Forward)
```

### Working with Page Objects

Page objects implement `Enumerable`, so you can use familiar Ruby methods:

```ruby
page = User.order(id: :asc).paginate(per_page: 20, direction: Raikou::Direction::Forward)

# Iterate over records
page.each do |user|
  puts user.name
end

# Map records
names = page.map(&:name)

# Filter records
active_users = page.select(&:active?)

# Check page status
page.empty?           # => true/false
page.size             # => Number of records in current page
page.has_next_page    # => true/false
page.has_previous_page # => true/false
```

## Error Handling

Raikou raises the following errors:

- `Raikou::InvalidOrderError`: Raised when no order is specified or when unsupported order formats are used
- `Raikou::InvalidCursorError`: Raised when an invalid cursor string is provided

```ruby
begin
  page = User.paginate(per_page: 20, direction: Raikou::Direction::Forward)  # No order specified
rescue Raikou::InvalidOrderError => e
  puts "Please specify an order: #{e.message}"
end
```

## How It Works

### How Raikou Uses Seek Method

Raikou uses the seek method (requires proper indexes on ordering columns for optimal performance):

```sql
-- Instead of: SELECT * FROM users ORDER BY id LIMIT 20 OFFSET 40
-- Raikou generates: SELECT * FROM users WHERE id > 40 ORDER BY id LIMIT 20
```

### Cursor Encoding

Cursors are Base64-encoded JSON objects containing the values of ordering columns for the last record in a page. This allows Raikou to continue pagination from exactly where the previous page ended.

## Comparison: Seek Method vs Offset Method

### Navigation Capabilities

| Feature | Offset Method | Seek Method | Notes |
|---------|---------------|-------------|-------|
| **Random access** | ✓ Can jump to any page | ✗ Sequential navigation only | Offset allows `?page=100`, seek requires cursors from previous pages |
| **Bi-directional** | ✓ Supported | ✓ Supported | Both methods allow forward and backward navigation |

### Data Inconsistencies

When data changes between page requests, both pagination methods can experience various types of inconsistencies. Here's a comparison:

| Inconsistency Type | Offset Method | Seek Method | Cause |
|-------------------|---------------|-------------|-------|
| **Record Duplication** | ✗ Occurs | ✓ Prevented | New records inserted before current position |
| **Missing Records** | ✗ Occurs | ✓ Prevented | Records deleted before current position |
| **Missing Records (from updates)** | ✗ Occurs | ✓ Prevented | Ordering column values updated to move records forward |
| **Record Reappearance** | ✗ Occurs | ✗ Occurs | Ordering column values updated to move records backward |

**Summary**: Seek method prevents **duplication** and **missing records** caused by insertions, deletions, and forward updates. However, records whose ordering columns are updated to move them backward may reappear in both pagination methods.

### Performance

| Aspect | Offset Method | Seek Method | Notes |
|--------|---------------|-------------|-------|
| **Deep pagination** | ✗ Degrades | ✓ Consistent (with proper indexes) | Offset must scan all previous rows even with indexes |

## Development

After checking out the repo, run `bundle install` to install dependencies.

Run tests:

```bash
bundle exec rspec
```

Run Sorbet type checking:

```bash
bundle exec srb tc
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Credits

Inspired by [Kaminari](https://github.com/kaminari/kaminari) and cursor-based pagination patterns used by GraphQL and modern APIs.
